import { EXPECT, Sample, @registerSuite, @metadata, @tags, Async } from "xtest.xs"
import { TypeRepository } from "./typeRepo.xs"
import { hasType, resolveType } from "./typeSystem.xs"
import  proxy  from "system://core.proxy"
import { unproxy, unwrapProxy, createProxy } from "./checkerProxies.xs"
import JSON from "system://web.JSON"
import { processJsonContent } from "ifw/jsonTypeCheck.xs"
import { jsonStr } from "./exampleJsons.xs"
import { Map } from "system://core.types"

const SimpleShapeType = {
    kind: @interface,  
    name: @Shape, 
    members: [
        { name: @x, type: @int, mutable: true },  // basic types could be represented as an id, or string
        { name: @y, type: @int, mutable: true  },
        { name: @draw, type: { kind: @method, arguments: [ {name: @color, type: @int } ] }  },
        { name: @getChild, type: { kind: @method, arguments: [ {name: @idx, type: @int, default:true } ],
                                   returnValue: { type: { path: ("Shape",) } } }  
        },
        
        { name: @constructor, type: { kind: @method, 
                                            arguments: [ {  name: @children, 
                                                            type: {path: ("Shape",) },
                                                            isSpread: true
                                                         } 
                                                       ] 
                                    }  
        },
        // { name: @children, type: { path: ["array"], params: [{path: ("Shape",)}] } }, 
    ]        
};

const ShapeStructType = {
    kind: @struct,  
    name: @ShapeStruct, 
    members: [
        { name: @x, type: @int, mutable: true },  // basic types could be represented as an id, or string
        { name: @y, type: @int, mutable: true  }
    ]
};

const CircleType = {
    kind: @interface,
    name: @Circle,
    extends: { path: ("Shape",)}, 
    members: [
        {name: @radius, type: @double},
        { name: @constructor, type: { kind: @method, 
                                            arguments: [ { name: @radius, type: @double }, 
                                                         {  name: @children, 
                                                            type: {path: ("Shape",) },
                                                            isSpread: true
                                                         }, 
                                                       ]
                                           }  
        },
    ]
};

const CircleStructType = {
    kind: @struct,  
    name: @CircleStruct,
    extends: {path: ("ShapeStruct",)}, 
    members: [
        { name: @radius, type: @double },  
    ]
};


class Shape {
    x;
    y;
    posNotOnInterface = 100; // check extra property access throws
    
    children = [];
    constructor(...children) {
        this.children = children;
    }
    
    draw(color) {
        console.log(`Draw shape on ${this.x} ${this.y}`)
    }
    
    getChild(idx = 0) {
        this.children[idx]
    }
}

class Circle extends Shape {
    radius = 1;
    constructor(radius, ...children) {
        super(...children);
        this.radius = radius;
        this.x = this.y = 0;
    }
    
    draw(color) {
        super.draw(color);
        console.log(`  Draw circle with radius ${this.radius}`);
    }
}

@registerSuite
class TypecheckSamples extends Sample {
    repo;
    shapeType;
    circleType;
    shapeStructType;
    circleStructType;
    
    constructor() {
        super();
        const repo = new TypeRepository();
        repo.registerType(("Shape",), SimpleShapeType);
        repo.registerType(("Circle",), CircleType);
        repo.registerType(("ShapeStruct",), ShapeStructType);
        repo.registerType(("CircleStruct",), CircleStructType);
        this.repo = repo;
        this.shapeType = resolveType(repo, ("Shape",));
        this.circleType = resolveType(repo,  ("Circle",));
        this.shapeStructType = resolveType(repo,  ("ShapeStruct",));
        this.circleStructType = resolveType(repo,  ("CircleStruct",));
    }
    
    sample_first() {
        EXPECT.THAT(10, hasType(@int));
    }
    
    sample_shapeOk() {
        const shape = new Shape();
        shape.x = 10; // NOTE: not setting x,y would cause failure, as undef is not accepted
        shape.y = 5; 
        EXPECT.THAT(shape, hasType(this.shapeType));
        EXPECT.THAT(shape, hasType(this.shapeStructType));
    }
    
    sample_shapeNOk() {
        const shape = new Shape();
        shape.x = 10; 
        shape.y = "5"; 
        EXPECT.THAT(shape, hasType(this.shapeType));
        EXPECT.THAT(shape, hasType(this.shapeStructType));
    }
    
    sample_CircleNok() {
        const shape = new Shape();
        shape.x = shape.y = 0;
        // Member missing: @radius
        EXPECT.THAT(shape, hasType(this.circleStructType));
    }
    
    sample_proxyShape() {
        const shape = new Shape(new Circle(10));
        shape.x = 0;
        EXPECT.EQ(shape.posNotOnInterface, 100);
        const sp = createProxy(shape, this.shapeType);
        sp.y = 20;
        
        EXPECT.EQ(sp.x, 0);
        EXPECT.EQ(sp.y, 20);
        // expect a failure instead
        // EXPECT.EQ(sp.posNotOnInterface, 100);
        
        sp.draw(#cc0);
        // sp.draw(); // should show not enough args error
        // sp.draw("alma"); // should show invalid arg error
        
        sp.getChild(0);
        // sp.getChild(0, 5).draw();
    }
    
    sample_proxyCircle() {
        const circle = new Circle(10);
        const cp = createProxy(circle, this.circleType);
        cp.y = 20;
        
        EXPECT.EQ(cp.radius, 10);
        EXPECT.EQ(cp.x, 0);
        EXPECT.EQ(cp.y, 20);
    }
}

dict mapSpec {
    kind = @interface;
    name = "map";
    typeParams = [ {name: "K"}, {name: "V"} ]; // param names are useful only when debugging, not needed for processing
                                           // maybe for name resolution, if the descriptor can't provide it 
    members = [
        {name: "get", type: { kind:@callable,
                              arguments:[{name: "key", type: {param:0}}],
                              returnValue:{type: {param: 1}},
                              } 
        }
    ]
}

dict testSpec {  // interface Test<P1, P2> { static alma:string, ...  }
    kind = @interface;
    name = "Test";
    params = [ {name: "P1"}, {name: "P2"} ];
    members = [
      {name: "alma", type: { param: 0 } /*P1*/}, // alma:P1
      {name: "myMap", type: { kind: @generic, path: ("nng", "map"), params:[ @string, {param: 1}/*P2*/ ] } }, // myMap:nng.map<string, P2>  
      // samples for different type descriptors
    //   // [Symbol.__iterator]
    //   {name: "items", type: { path: ["array"], params: [{path: ["Kutya"]}], optional:true }  }, // items: Kutya[]
    //   // union
    //   {name: "some", type: { kind: @union, items: ["string", {path:["Kutya"]}] }},
    //   {name: "someTup", type: { kind: @tuple, items: ["string", {path:["Kutya"]}] }},
    //   // restargs
    //   // dump(P1, ...nng.Alma<P2> ) : ...nng.Korte
    //   {name: "dump", type: { arguments:[ {param: 0}, { path: ["nng", "Alma"], params: [{param:1}], isSpread:true } ], retval:{type: { path:["nng", "Kutya"] }, isSpread:true}}}
    ];
}

@registerSuite
class TypeSysSamples extends Sample {

    sample_testSpec() {
        const repo = new TypeRepository();
        repo.registerType(("nng", "map"), mapSpec);
        const resolved = resolveType(repo, ("nng", "map"), (@int, @double)); // corresponds to Test<int, double>
        console.log("repo (needed for type refs): ", repo);
        console.log("Resolved type: ", resolved);
    }    
}


@registerSuite
class JsonConvertSamples extends Sample {

    sample_testJsonData() {
        const repo = new TypeRepository();
        const jsonData = JSON.parse(jsonStr.http);
        processJsonContent(repo, new Map, jsonData);
        console.log(repo);

        const cl = new Client();
        const client = createProxy(cl, resolveType( repo, ("nng", "networking", "http", "Client")));
        //let req = client.createRequest("alma");
        let req = client.createRequest();
        EXPECT.EQ(req.userInfo, "userinfo");
    }

    sample_testGeneric() {
        const repo = new TypeRepository();
        const jsonData = JSON.parse(jsonStr.iterator);
        processJsonContent(repo, new Map, jsonData);
        console.log(repo);

        const f = new Foo();
        const foo = createProxy(f, resolveType( repo, ("nng", "test", "Foo")));
        let it = foo.getIterator();
        EXPECT.EQ(it.next(), 42);
    }

    sample_testExtends() {
    }

}

class Iterator {
    next() {
        return 42;
    }
}

class Foo {
    getIterator() {
        return new Iterator();
    }
}

/// Describes an HTTP request
class Request
{
    userInfo = "userinfo";
    constructor() {

    }
	/*
    scheme : Scheme    @mutable @unobservable
	userInfo : string?  @mutable @unobservable
	host : string      @mutable @unobservable
	port : uint32?      @mutable @unobservable
	path : string      @mutable @unobservable
	queryParameters : nng.Dict<string, string> @unobservable
	fragment : string?  @mutable @unobservable
	method : Method    @mutable @unobservable
	headers : Headers  @unobservable
	body : (string | bytes)? @mutable @unobservable
	attributes : nng.Dict<string, string> @unobservable
	clone() : Request
	fetch() : Response @async
	cancel()
    */
}

/// Creates HTTP requests
class Client {
    
	// createRequest() : Request
    createRequest() {
        return new Request();
    }
	// createRequest(url : string) : Request @throws
    // createRequest(url : string, body : string) : Request @throws
    // cancelFetches()	
}

