import {TestSuite, Async, EXPECT, @registerSuite, @metadata, MockFunction, Sequence, FIX_ME, elementsAre, propertiesAre, _, hasProperties} from "xtest.xs"
import { parseModuleContents, parseModule } from "./moduleParser.xs"
import { toMatcher, @curry, eq, hasSubstr, isErrorWithMsg, matchesRegexp } from "xtest/Matchers.xs"
import { getFailObject} from "system://core"

class MockParseListener {
    onImport = MockFunction{};
    onDefinition= MockFunction{};
    onExport = MockFunction{};
}

@metadata({
    description: "",
    owner: @UIEngine,
    feature: @Unknown,
    level: @component,
    type: @functional,
})
@registerSuite
class TestModuleParser extends TestSuite {
    listener;
    constructor() {
        super();
        this.listener = new MockParseListener();
    }

    test_parseXtest() {
        var res = parseModule("xtest.xs");
        var alma = 42
    }

    test_parseStarImport() {
        var res = parseModuleContents('import * as all from "xtest.xs"');
        var alma = 42
    }

    test_parseModuleOnload() {
        var res = parseModuleContents('@onLoad() f() {1;}');
        var alma = 42
    }

    test_parseModulePreload() {
        var res = parseModuleContents('@preload odict kakukk {}');
        var alma = 42
    }

    test_parseSomeDefs() {
        var res = parseModuleContents('import {TestSuite as Suite}  from "xtest.xs"
                                       
                                       class Alma {
                                           size = 10;
                                           provider = (new Macska());
                                           constructor() {
                                               this.size = 15;
                                           }
                                       }

                                       class Korte {
                                           size = 15;
                                           provider = (new Korte());
                                           constructor() {
                                               this.size = 16;
                                           }
                                       }

                                        class VillanyKorte extends Korte {
                                            name = "unnamed";
                                            provider = (new VillanyKorte());
                                            param1 = 1;                                           
                                            constructor() {
                                                super();
                                                this.name = "tungsram"
                                            }
                                        }                       

                                       <fragment frKutya>
                                            <div> <sprite/> </div>
                                       </fragment>

                                       dict myDict {
                                           alma = 10;
                                            }

                                        <nincs_own nemjo exports=@dino>
                                            <prop dino = "Bosss" />                                            
                                        </nincs_own>

                                       const myStuff = new Uiml.list();
                                       export doSomething() {
                                           console.log("something");
                                       }
                                       namespace sub {
                                           const bella = frKutya;
                                       }
                                       export { myStuff as valami};
                                       export { Lo as Pferd, Macska } from "animals.xs";
                                       export * from "kutya.xs"

                                       export default class Mokus {}
        ');
    }

    test_importFromModuleRenamed() {
        EXPECT.CALL(this.listener.onImport).with(0, @Suite, (hasProperties({ path: "xtest.xs"}), @TestSuite), expanded((_, 1, _)) );
        parseModuleContents('import {TestSuite as Suite}  from "xtest.xs"', this.listener);
    }

    test_emptyImport() {
        EXPECT.CALL(this.listener.onImport).with(0, undef, (hasProperties({ path: "xtest.xs", imported: _, source:(_, 1, _) }), undef), (_, 1, _) );
        parseModuleContents('import {}  from "xtest.xs"', this.listener);
    }

    test_importFromModule() {
        EXPECT.CALL(this.listener.onImport).with(0, @TestSuite, (hasProperties({ path: "xtest.xs"}), @TestSuite), expanded((_, 2, _)) /*file, line, col*/  );
        EXPECT.CALL(this.listener.onImport).with(0, @register, (hasProperties({ path: "xtest.xs"}), @register), expanded((_, 2, _)) );
        parseModuleContents('import {TestSuite, 
                             register }  from "xtest.xs"', this.listener);
    }

    test_starImport() {
        EXPECT.CALL(this.listener.onImport).with(0, @xt, (hasProperties({ path: "xtest.xs"}),), _ );
        parseModuleContents('import * as xt  from "xtest.xs"', this.listener);
    }

    ignore_test_importAlias() { // format changes to const expr
        EXPECT.CALL(this.listener.onImport).with(0, @something, elementsAre(@ns, @sub, @thing), _ );
        parseModuleContents('import something = ns.sub.thing', this.listener);
    }
    test_importWith() {
        const attrs = (type, isOptional) => hasProperties(#{type, isOptional});
        EXPECT.CALL(this.listener.onImport).with(0, @alma, (hasProperties({ path: "sample.json", with: attrs(@json, false)}), @default), expanded((_, 2, 63)) );
        EXPECT.CALL(this.listener.onImport).with(0, @korte, (hasProperties({ path: "xtest.xs", with: attrs(undef, true)}), @default), expanded((_, 3, 42)) );
        parseModuleContents('
            import alma from "sample.json" with {type: "json"}
            import korte from "xtest.xs"?
        ', this.listener)
    }

    test_exportClass() {
        EXPECT.CALL(this.listener.onExport).with(0, @Alma, undef, undef, undef);
        EXPECT.CALL(this.listener.onDefinition).with(0, @Alma, _, @def);
        parseModuleContents('export class Alma {}', this.listener);
    }

    test_exportAlias() {
        EXPECT.CALL(this.listener.onExport).with(0, @Appfel, undef, @Alma, undef);
        parseModuleContents('export { Alma as Appfel }', this.listener);
    }

    test_exportImportModule() {
        EXPECT.CALL(this.listener.onExport).with(0, @myJonathan, undef, @Alma, undef);
        EXPECT.CALL(this.listener.onImport).with(0, @myJonathan, (hasProperties({ path: "xtest.xs"}), @Alma), expanded( elementsAre(_, 2, _)) );
        parseModuleContents('export { Alma as myJonathan }
                             import {Alma as myJonathan } from "xtest.xs"', this.listener);
    }

    test_importExportModule() {
        EXPECT.CALL(this.listener.onImport).with(0, @fun, (hasProperties({ path: "xtest.xs"}), @copySettings), expanded( elementsAre(_, 1, _)) );
        EXPECT.CALL(this.listener.onExport).with(0, @Function, undef, @fun, undef);
        parseModuleContents('import {copySettings as fun } from "xtest.xs"
                             export { fun as Function } ', this.listener);
    }

    test_importExportModule2() {
        EXPECT.CALL(this.listener.onExport).with(0, @fun, "xtest.xs", @copySettings, expanded(elementsAre(0, 1, 46)), _);
        parseModuleContents('export {copySettings as fun } from "xtest.xs"', this.listener);
    }
    test_exportWith() {
        const attrs = (type, isOptional) => hasProperties(#{type, isOptional});
        EXPECT.CALL(this.listener.onExport).with(0, @alma, "sample.json", @default, expanded((_, 2, 76)), attrs(@json, false) );
        EXPECT.CALL(this.listener.onExport).with(0, @korte, "xtest.xs", @default, expanded((_, 3, 55)), attrs(undef, true) );
        parseModuleContents('
            export {default as alma} from "sample.json" with {type: "json"}
            export {default as korte} from "xtest.xs"?
        ', this.listener)
    }

    
    test_imports_sequence(){
        var seq = new Sequence(); 

        EXPECT.CALL(this.listener.onImport).with(0, @kutya, (hasProperties({ path: "xtest.xs"}), @frKutya), expanded( elementsAre(_, 2, _)) ).inSequence(seq);
        EXPECT.CALL(this.listener.onImport).with(0, @TestSuite, (hasProperties({ path: "xtest.xs"}), @TestSuite), expanded((_, 3, _)) ).inSequence(seq);
        EXPECT.CALL(this.listener.onImport).with(0, @Alma, (hasProperties({ path: "xtest.xs"}), @Alma), expanded( elementsAre(_, 4, _)) ).inSequence(seq);
        parseModuleContents('
                    import { frKutya as kutya } from "xtest.xs"
                    import {TestSuite} from "xtest.xs"
                    import { Alma } from "xtest.xs"', this.listener);                    
    }

    test_exports_sequence(){
        var seq = new Sequence();   

        EXPECT.CALL(this.listener.onExport).with(0, @Alma, undef, undef, undef).inSequence(seq);       
        EXPECT.CALL(this.listener.onExport).with(0, @Korte, undef, undef, undef).inSequence(seq);
        parseModuleContents('
            export class Alma {}                    
            export class Korte {}', this.listener);  
    }

    test_definitions_sequence(){
        var seq = new Sequence();   
        
        EXPECT.CALL(this.listener.onDefinition).with(0, @Korte, _, @def).inSequence(seq);
        EXPECT.CALL(this.listener.onDefinition).with(0, @Alma, _, @def).inSequence(seq);
        parseModuleContents('
            export class Korte {}
            export class Alma {}', this.listener);
    }

    test_dictImport() {           
        EXPECT.CALL(this.listener.onImport).with(0, @md, (hasProperties({ path: "xtest.xs"}), @myDict), expanded( elementsAre(_, 1, _)) );
        parseModuleContents('import { myDict as md } from "xtest.xs"', this.listener);
    }

    test_dictExport() {
        EXPECT.CALL(this.listener.onExport).with(0, @md, undef, @myDict, undef);
        parseModuleContents('export { myDict as md }', this.listener);
    }

    test_ownImport() {           
        EXPECT.CALL(this.listener.onImport).with(0, @dino, (hasProperties({ path: "xtest.xs"}), @dino), expanded( elementsAre(_, 1, _)) );
        parseModuleContents('import { dino } from "xtest.xs"', this.listener);
    }

    test_ownExport() {
        EXPECT.CALL(this.listener.onExport).with(0, @myDinoBoss, undef, @dino, undef);
        parseModuleContents('export { dino as myDinoBoss }', this.listener);
    }

    test_privateFunctImport() {           
        EXPECT.CALL(this.listener.onImport).with(0, @mycalledPrivFunct, (hasProperties({ path: "xtest.xs"}), @callPrivFunction), expanded( elementsAre(_, 1, _)) );
        parseModuleContents('import { callPrivFunction as mycalledPrivFunct } from "xtest.xs"', this.listener);
    }

    test_static_method_of_class_export() {
        EXPECT.CALL(this.listener.onExport).with(0, @ClassWithStaticMethod, undef, undef, undef);
        EXPECT.CALL(this.listener.onDefinition).with(0, @ClassWithStaticMethod, _, @def);        
        parseModuleContents('export class ClassWithStaticMethod{}', this.listener);
    }

    test_imports_class_with_static_method(){       
        EXPECT.CALL(this.listener.onImport).with(0, @ClassWithStaticMethod, (hasProperties({ path: "xtest.xs"}), @ClassWithStaticMethod), expanded( elementsAre(_, 1, _)) ); 
        parseModuleContents('import { ClassWithStaticMethod } from "xtest.xs"', this.listener);                    
    }

    test_inherited_class_import(){
        EXPECT.CALL(this.listener.onImport).with(0, @Vk, (hasProperties({ path: "xtest.xs"}), @VillanyKorte), expanded( elementsAre(_, 1, _)) ); 
        parseModuleContents('import { VillanyKorte as Vk } from "xtest.xs"', this.listener);                    
    }

    test_inherited_class_export(){
        EXPECT.CALL(this.listener.onExport).with(0, @VillanyKorte, undef, undef, undef);
        EXPECT.CALL(this.listener.onDefinition).with(0, @VillanyKorte, _, @def);        
        parseModuleContents('export class VillanyKorte{}', this.listener);
    } 
    /*Namespace tests*/    
    test_namespaceSimple() {
        EXPECT.CALL(this.listener.onDefinition).with(0, @sub, _, @namespace, 1);
        parseModuleContents(' namespace sub { } ', this.listener);
    }
    
    test_namespaceNested() {
        var seq = new Sequence();   
        EXPECT.CALL(this.listener.onDefinition).with(0, @first, _, @namespace, 1).inSequence(seq);
        EXPECT.CALL(this.listener.onDefinition).with(1, @second, _, @namespace, 2).inSequence(seq);
        parseModuleContents('        
            namespace first {
                namespace second {
                }
            }   
        ', this.listener);
    }
    
    test_namespaceMultipleNested() {
        var seq = new Sequence();   
        EXPECT.CALL(this.listener.onDefinition).with(0, @first, _, @namespace, 1).inSequence(seq);
        EXPECT.CALL(this.listener.onDefinition).with(1, @second, _, @namespace, 2).inSequence(seq);
        EXPECT.CALL(this.listener.onDefinition).with(1, @third, _, @namespace, 3).inSequence(seq);
        parseModuleContents('        
            namespace first {
                namespace second { }
                namespace third { }
            }   
        ', this.listener);
    }
    
    test_namespaceExtraDef() {
        var seq = new Sequence();   
        EXPECT.CALL(this.listener.onDefinition).with(0, @first, _, @namespace, 1).inSequence(seq);
        EXPECT.CALL(this.listener.onDefinition).with(1, @second, _, @namespace, 2).inSequence(seq);
        EXPECT.CALL(this.listener.onDefinition).with(1, @Mokus, _, _).inSequence(seq);
        EXPECT.CALL(this.listener.onDefinition).with(1, @third, _, @namespace, 3).inSequence(seq);
        parseModuleContents('        
            namespace first {
                namespace second { }
                class Mokus { func() { return 1; } }  
                namespace third { }
            }   
        ', this.listener);
    }

    test_namespaceComplicated() {
        var seq = new Sequence();   
        EXPECT.CALL(this.listener.onDefinition).with(0, @s1, _, @namespace, 1).inSequence(seq);
        EXPECT.CALL(this.listener.onDefinition).with(1, @s2, _, @namespace, 2).inSequence(seq);
        EXPECT.CALL(this.listener.onDefinition).with(2, @s3, _, @namespace, 3).inSequence(seq);
        EXPECT.CALL(this.listener.onDefinition).with(3, @s4, _, @namespace, 4).inSequence(seq);
        EXPECT.CALL(this.listener.onDefinition).with(4, @func2, _, _).inSequence(seq);
        EXPECT.CALL(this.listener.onDefinition).with(2, @Mokus, _, _).inSequence(seq);
        parseModuleContents('
            namespace s1 {
                namespace s2 {
                    namespace s3 {
                        namespace s4 {
                            func2() {
                                return 1;
                            }
                        }
                    }
                    class Mokus {
                        a; 
                        func() {
                            return 1;
                        }
                    }
                }
            }
        ', this.listener);
    }

    test_namespaceReopen() {
        var seq = new Sequence();   
        EXPECT.CALL(this.listener.onDefinition).with(0, @s1, _, @namespace, 1).inSequence(seq);
        EXPECT.CALL(this.listener.onDefinition).with(1, @s2, _, @namespace, 2).inSequence(seq);
        EXPECT.CALL(this.listener.onDefinition).with(2, @func, _, _).inSequence(seq);
        EXPECT.CALL(this.listener.onDefinition).with(0, @func, _, _).inSequence(seq);
        EXPECT.CALL(this.listener.onDefinition).with(1, @func, _, _).inSequence(seq);
        parseModuleContents('
            namespace s1 {
                namespace s2 {
                    func() { return 1; }
                }
            }
            
            func() { return 1; }
            
            namespace s1 {
                func() { return 1; }
            }
        ', this.listener);
    }

    // ---------------------------------------------------------------------------------------------------- //

    test_fragmentDefinitionContents() {
        EXPECT.CALL(this.listener.onDefinition).with(0, @frAlma, expanded({tag: @fragment, name: @frAlma,  members: [{name: @class }], class: [@cls1, @cls2], src:[0, 1]}), @object );     
        parseModuleContents('<fragment frAlma class="cls1 cls2">                                                       
                             </fragment>
                            ', this.listener);
    }

    test_fragment_withOwn_DefinitionContents() {     
        EXPECT.CALL(this.listener.onDefinition).with(0, @frAlma, expanded({
            tag: @fragment,
            name: @frAlma,
            members: [
                     {name: @class }, 
                     {name: @onRelease, data: {
                        id: @onRelease,
                        src: (0,1,46),
                        lastLoc: (0,1,53),
                        arity: 0,
                        stmtInfo: _
                     }},

                     ],
            scope: [
                    {name: @prop1, mutable:1, exported:1 }, 
                    {name: @prop2, mutable:1 }, 
                    {name: @prop3 }, 
                    {name: @prop4, exported: 1 },
                    {name: @O, data: {
                        name: @O, // why is this `prop1` and not `O`
                        type: @odict,
                        members: [{ name: @x}],
                        src: (0,8)
                    }},
                    {name: @onF, data: {
                        id: @onF,
                        src: (0,9, 45),
                        lastLoc: (0,9,55),
                        arity: 0,
                        stmtInfo: _
                     }},
                    {name: @constructor, data: {
                        id: @constructor,
                        src: (0,11,53),
                        lastLoc: (0,13,41),
                        arity: 0,
                        stmtInfo: _
                     }},
            ],
            class: [@cls1, @cls2],
            src:[0, 1]
        }), @object );      
            parseModuleContents('<fragment frAlma class="cls1 cls2" onRelease() { 1; }>  
                                    own {
                                        export let prop1 = 10;
                                        let prop2 = 20;
                                        const prop3 = 20;
                                        export const prop4 = 20;

                                        odict O { x=1 };
                                        onF() { O.x=1 };

                                        constructor() {
                                            1;
                                        }
                                    }                                          
                             </fragment>
                            ', this.listener);
    }


    test_functionInTextAsAttr(){       // function in text content becomes an attribute
        EXPECT.CALL(this.listener.onDefinition).with(0, @myFrag, expanded({
            tag: @fragment,
            name: @myFrag, 
            src:[0, 1],
            children: [{
                tag: @g,
                src: [0, 2],
                members:[{
                    name: @counter,
                    data:{ 
                        src: [0, 4, 41 ],
                        id: @counter,
                        arity: 0,
                        lastLoc: [0, 6, 33 ],                    
                        stmtInfo: [(5, 37, 0 )]
                    },
                }],              
                children: [{
                    tag: @prop,
                    src: [0, 3], 
                    members: [ {name: @myProp }]
                }] 
            }] 
        }), @object );     
        parseModuleContents('<fragment myFrag> 
                            <g>
                                <prop myProp=0 />
                                counter() {         
                                    myProp = 1;
                                }    
                            </g>
                            </fragment>
                            ', this.listener);    
    }

    test_dataInTextAsAttr_and_twoway(){   
        EXPECT.CALL(this.listener.onDefinition).with(0, @myFrag, expanded({
            tag: @fragment,
            name: @myFrag,
            src:[0, 1],
            children: [{
                tag: @g,
                src: [0, 2], 
                members: [
                    {name: @exports },
                    { name: @myPage1,
                      data: {
                        //noname: @myPage1,
                        type: @xdata,
                        src: [0, 3],
                        members: [{name: @f1}]
                    }}
                ],
                children:[{
                    tag: @xdata,
                    src:[0, 4],
                    members: [{
                        name: @myPage2,
                        kind: @twoway,
                        data: {
                            src: [0, 4, 56],
                            lastLoc: [0, 4, 69],
                            stmtInfo: _,
                            expr: 1
                        }},
                        {
                        name: @alma,
                        kind: @twoway,
                        data: {
                            src: [0, 5, 53],
                            lastLoc: [0, 5, 63],
                            stmtInfo: _,
                            expr: 1
                        }
                    }]

                }]
            }], 
        }), @object );     
        parseModuleContents('<fragment myFrag>                                
                                <g exports=@Binder>
                                    xdata myPage1 { f1 = "alma.jpg" }
                                    <xdata myPage2 <=> myPage1.value 
                                           alma <=> almnaInOwn />
                                </g>
                            </fragment>
                            ', this.listener);
    }

    
    test_fragment_odict_DefinitionContents() {    
        EXPECT.CALL(this.listener.onDefinition).with(0, @frAlma, expanded({
                tag: @fragment,
                name: @frAlma,
                members: [{name: @class }],
                class: @cls1,
                src:[0, 1], 
                children: [{
                    tag: @lodict, 
                    src:[0, 2],
                    members: [{name: @name } ]                                           
                }]
            }), @object );     
        parseModuleContents('<fragment frAlma class="cls1">
                                  <lodict name="korte" />                                                      
                             </fragment>
                            ', this.listener);
    }

    
    test_odict_more_definitionContents(){    
        EXPECT.CALL(this.listener.onDefinition).with(0, @myOdict, expanded({
            name: @myOdict,
            type: @odict,
            src:[0, 1], 
            members: [{
                name: @alma
                },
                
                {
                name: @korte
                },
                
                {
                name: @szilva
                }
            ]  
        }), @def );     
        parseModuleContents('odict myOdict { 
                            alma = 10;
                            korte = 20;
                            szilva = 30;	                 
                        }
                        ', this.listener)
    }


    test_data_definitionContents() {      
        EXPECT.CALL(this.listener.onDefinition).with(0, @myData, expanded({
                tag: @xdata,
                name: @myData,
                src:[0, 1],
                children:[{
                    tag: @prop,
                    name: @v_obs_val,
                    src:[0, 2],
                    members: [{name: @value } ]
               }]
            }), @object );      
        parseModuleContents('<xdata myData>
	                            <prop v_obs_val value = 10 />	
                            </xdata>                           
                            ', this.listener);
    }

    test_data_observer_definitionContents() {       
        EXPECT.CALL(this.listener.onDefinition).with(0, @obs_val, expanded({
                tag: @obxerver,
                name: @obs_val,
                src:[0, 1],
                members:[{
                    name: @value,
                    kind: @binding,
                    data: { 
                        src: [0, 1, 26 ],
                        lastLoc: [0, 1, 35 ],
                        expr: 1,
                        stmtInfo: [(1, 26, 0 )]
                    }
               }]
            }), @object );      
        parseModuleContents('<obxerver obs_val value=(v_obs_val) />                         
                            ', this.listener);
    }


    test_observer_more_definitionContents(){      
        EXPECT.CALL(this.listener.onDefinition).with(0, @my_obs, expanded({
            tag: @obxerver,
            name: @my_obs,
            src:[0, 1],
            members:[{
                name: @value,
                kind: @binding,
                data: { 
                    src: [0, 1, 25 ],
                    lastLoc: [0, 1, 32 ],
                    expr: 1,
                    stmtInfo: [(1, 25, 0 )]
                }
            },
            {
                name: @start
            }]
        }), @object );      
        parseModuleContents('<obxerver my_obs value=(obs_val) start="NO_TRIGGER"/>                       
                            ', this.listener);
    }

    test_component_DefinitionContents() {    
        EXPECT.CALL(this.listener.onDefinition).with(0, @testComponent, expanded({
            tag: @component,
            name: @testComponent,
            src:[0, 1],
            children:[{
                tag: @sprite,              
                src: [0, 2],
                class: @cls1,
                members: [
                    {name: @class},
                    {name: @img}
                ]
            }]
        }), @object );    
        parseModuleContents('<component testComponent>
                                <sprite class="cls1" img="daycar.bmp" />
                            </component>
                            ', this.listener);
    }

    test_component_more_definitionContents(){    
        EXPECT.CALL(this.listener.onDefinition).with(0, @myComp, expanded({
            tag: @component,
            name: @myComp,            
            src:[0, 1],
            members: [{
                name: @layout
            }, hasProperties({
                name: @onClick
            })],
            children: [{
                tag: @includeChildren,
                src: [0, 2],
                members: [{
                    name: @filter
                }]
            },
            {
               tag: @includeChildren,
               src: [0, 3] 
            }]
        }), @object );   
        parseModuleContents('<component myComp layout=@flex onClick() {}> 
                                    <includeChildren filter=".class1"/>
                                    <includeChildren />                                    
                            </component>
                            ', this.listener);      
    }

    test_list_DefinitionContents(){      
        EXPECT.CALL(this.listener.onDefinition).with(0, @creatures, expanded({
            name: @creatures,
            type: @list,            
            src:[0, 1],
        }), @def );   
        parseModuleContents('list creatures [
                                odict{ name=L"Földimalac"; type=1 }
                            ]
                            ', this.listener);
        
    }
    

    test_listview_DefinitionContents(){   
       EXPECT.CALL(this.listener.onDefinition).with(0, @myFrag, expanded({
            tag: @fragment,
            name: @myFrag,
            src:[0, 1],
            children:[{
                tag: @listView,              
                src: [0, 2],                
                members: [
                    {name: @top},
                    {name: @left},
                    {name: @w},
                    {name: @h},
                ]
            }]
        }), @object );   
        parseModuleContents('<fragment myFrag >
                                <listView top=70 left=25 w=250 h=300 >
                                </listView>
                            </fragment>
                            ', this.listener);    
    }

    test_input_definitionContents(){     
        EXPECT.CALL(this.listener.onDefinition).with(0, @myInputText, expanded({
                name: @myInputText, 
                tag: @input,
                src: [0 ,1 ],
                members: [{
                    name: @empty,
                    kind: @binding, 
                    data: { 
                        src: [0, 1, 27 ],
                        lastLoc: [0, 1, 32 ],
                        expr: 1,
                        stmtInfo: [(1, 27, 0) ]
                    }
                }],      
            }), @object );     
        parseModuleContents('<input myInputText empty=(empty) />                                
                            ', this.listener);      
    }

    test_lister_definitionContents(){       
        EXPECT.CALL(this.listener.onDefinition).with(0, @lister_test, expanded({
                tag: @lister,
                name: @lister_test,
                src:[0, 1],
                members: [{
                    name: @model,
                    kind: @binding,                
                data: { 
                    src: [0, 1, 29 ],
                        lastLoc: [0, 1, 38 ],
                        expr: 1,
                        stmtInfo: [(1, 29, 0) ]
                    }
                },
                {
                    name: @template,
                    kind: @binding,
                    data: { 
                    src: [0, 1, 50 ],
                        lastLoc: [0, 1, 56 ],
                        expr: 1,
                        stmtInfo: [(1, 50, 0) ]
                    }  
                }],

                }), @object );     
        parseModuleContents('<lister  lister_test model=(lm_Mylist) template=(t_list) />                         
                            ', this.listener);
        
    }

    test_listModel_definitionContents(){          
            EXPECT.CALL(this.listener.onDefinition).with(0, @lmAnimals, expanded({
            tag: @xlistModel,
            name: @lmAnimals,            
            src:[0, 1],  
            children:[{
                tag: @import,              
                src: [0, 2],                
                members: [
                    {name: @model,
                    kind: @binding,
                    data: { 
                        src: [0, 2, 48 ],
                        lastLoc: [0, 2, 57 ],
                        expr: 1,
                        stmtInfo: [(2, 48, 0) ]
                        } 
                    }                    
                ]
            }]         
        }), @object );   
        parseModuleContents('<xlistModel lmAnimals>
                                <import model=(myAnimals) />    
                            </xlistModel>
                            ', this.listener);
    }

    test_template_definitionContents(){     
        EXPECT.CALL(this.listener.onDefinition).with(0, @t_myTempl, expanded({
                tag: @template,
                name: @t_myTempl,
                src: [0, 1],
                children:[{
                    tag: @text,              
                    src: [0, 2],
                    class: @cls1,                
                    members: [
                        {name: @class},                                      
                    ]
                }]
            }), @object );     
        parseModuleContents('<template t_myTempl>
                                <text class="cls1" >
                            </template>
                            ', this.listener);      
    }

    test_controller_definitionContents(){     
        EXPECT.CALL(this.listener.onDefinition).with(0, @Ctrl1, expanded({
            tag: @ctrlr, 
            name: @Ctrl1,
            src:[0, 1]
        }), @object );     
        parseModuleContents('<ctrlr Ctrl1 /> 
                            ', this.listener);        
    }

    test_state_definitionContents(){   
        EXPECT.CALL(this.listener.onDefinition).with(0, @st_Test, expanded({
            type: @state, 
            name: @st_Test,
            src:[0, 1],
            members: [{
                name: @use
            }]
        }), @def );     
        parseModuleContents('state st_Test {
                                use = ui_myTest;
                            } 
                            ', this.listener);  
        }
    
    test_state_more_definitionContents(){    
        EXPECT.CALL(this.listener.onDefinition).with(0, @st_Title, expanded({
            name: @st_Title,
            type: @state, 
            src: [0, 1],
            members: [
                {name: @useLayers},
                {name: @title},
                {name: @init,
                    data: {
                        src: [0, 5, 35],
                        id: @init,
                        arity: 0,
                        lastLoc: [0, 7, 30],
                        stmtInfo: [(6, 31, 0 )]
                    }  
                }
            ] 
        }), @def );     
        parseModuleContents('state st_Title {
	                            useLayers = "myHeader";
	                            title = "myTitle";

	                            init() {
		                            myHeader.title = this.title
	                            }
                            }
                            ', this.listener); 
    }

    test_div_definitionContentes(){       
        EXPECT.CALL(this.listener.onDefinition).with(0, @myDiv, expanded({
            tag: @div,             
            name: @myDiv,
            src:[0, 1],  
            class: @cls1,
            members: [{
                name: @class
            }]        
        }), @object );     
        parseModuleContents('<div myDiv class=@cls1>                         	
	                        </div>
                            ', this.listener); 
    }    	  

    test_classDefinitionContents() {
        EXPECT.CALL(this.listener.onDefinition).with(_, @Alma, expanded( propertiesAre({name: @Alma, type: @class, src: (_, 1), members: []}) ), @def );
        parseModuleContents('class Alma { }', this.listener);
    }

    test_abstractClassDefinitionContents() {
        EXPECT.CALL(this.listener.onDefinition).with(_, @Alma, expanded( propertiesAre({name: @Alma, type: @abstract, src: (_, 1), members: []}) ), @def );
        parseModuleContents('abstract class Alma { }', this.listener);
    }

    test_extendedClassDefinitionContents() {
        EXPECT.CALL(this.listener.onDefinition).with(_, @Alma, expanded( propertiesAre({name: @Alma, type: @class, src: (_, 1), extends: @Gyumolcs, members: []}) ), @def );
        parseModuleContents('class Alma extends Gyumolcs {}', this.listener);
    }

    test_extendedClassDefinitionContentsCallSuper() {
        EXPECT.CALL(this.listener.onDefinition).with(_, @Alma, expanded( propertiesAre({name: @Alma, type: @class, src: (_, 1), extends: @Gyumolcs, members: [{name: @constructor, storage: 1, data: {src: [_, _, _], id: @constructor, lastLoc: [_, _, _], arity: 0, stmtInfo: [ [_, _, _] ], outerNames: [ _ ]}}]}) ), @def );
        parseModuleContents('class Alma extends Gyumolcs {
            constructor () {
                super();
            }
        }', this.listener);
    }

    test_extendedClassDefinitionContentsCallSuperWithParam() {
        EXPECT.CALL(this.listener.onDefinition).with(_, @Alma, expanded( propertiesAre({name: @Alma, type: @class, src: (_, 1), extends: @Gyumolcs, members: [{name: @constructor, storage: 1, data: {src: [_, _, _], id: @constructor, lastLoc: [_, _, _], arity: 1, stmtInfo: [ [_, _, _] ], paramNames: [@num], outerNames: [ _ ]}}]}) ), @def );
        parseModuleContents('class Alma extends Gyumolcs {
            constructor (num) {
                super(num);
            }
        }', this.listener);
    }

    test_classDefinitionContentsWithEmptyConstructor() {
        EXPECT.CALL(this.listener.onDefinition).with(_, @Alma, expanded( propertiesAre({name: @Alma, type: @class, src: (_, 1), members: [hasProperties({name: @constructor, storage: 1})]}) ), @def );
        parseModuleContents('class Alma {
                                constructor() {
                                }
                            }
        ', this.listener);
    }

    test_classDefinitionContentsWithMemberWithoutInitialization() {
        EXPECT.CALL(this.listener.onDefinition).with(_, @Alma, expanded( propertiesAre({name: @Alma, type: @class, src: (_, 1), members: [{name: @alma}]}) ), @def );
        parseModuleContents('class Alma {
                                alma;
                            }
        ', this.listener);
    }

    test_classDefinitionContentsWithPrivateMemberWithoutInitialization() {
        EXPECT.CALL(this.listener.onDefinition).with(_, @Alma, expanded( propertiesAre({name: @Alma, type: @class, src: (_, 1), members: [{name: "#alma"}]}) ), @def );
        parseModuleContents('class Alma {
                                #alma;
                            }
        ', this.listener);
    }

    test_classDefinitionContentsWithProtectedMemberWithoutInitialization() {
        EXPECT.CALL(this.listener.onDefinition).with(_, @Alma, expanded( propertiesAre({name: @Alma, type: @class, src: (_, 1), members: [{name: @alma}]}) ), @def );
        parseModuleContents('class Alma {
                                protected alma;
                            }
        ', this.listener);
    }

    test_classDefinitionContentsWithInitializedMemberWithConstant() {
        EXPECT.CALL(this.listener.onDefinition).with(_, @Alma, expanded( propertiesAre({name: @Alma, type: @class, src: (_, 1), members: [{name: @alma}]}) ), @def );
        parseModuleContents('class Alma {
                                alma = 10;
                            }
        ', this.listener);
    }

    test_classDefinitionContentsWithInitializedPrivateMemberWithConstant() {
        EXPECT.CALL(this.listener.onDefinition).with(_, @Alma, expanded( propertiesAre({name: @Alma, type: @class, src: (_, 1), members: [{name: "#alma"}]}) ), @def );
        parseModuleContents('class Alma {
                                #alma = 10;
                            }
        ', this.listener);
    }

    test_classDefinitionContentsWithInitializedMemberWithOdict() {
        EXPECT.CALL(this.listener.onDefinition).with(_, @Alma, expanded( propertiesAre({name: @Alma, type: @class, src: (_, 1), members: [{name: @alma, data: {name: @alma, type: @odict, src: [_, _], members: []}}]}) ), @def );
        parseModuleContents('class Alma {
                                alma = odict {  };
                            }
        ', this.listener);
    }

    test_classDefinitionContentsWithInitializedPrivateMemberWithOdict() {
        EXPECT.CALL(this.listener.onDefinition).with(_, @Alma, expanded( propertiesAre({name: @Alma, type: @class, src: (_, 1), members: [{name: "#alma", data: {type: @odict, src: [_, _], members: []}}]}) ), @def );
        parseModuleContents('class Alma {
                                #alma = odict {  };
                            }
        ', this.listener);
    }

    test_classDefinitionContentsWithInitializedMemberWithObject() {
        EXPECT.CALL(this.listener.onDefinition).with(_, @Alma, expanded( propertiesAre({name: @Alma, type: @class, src: (_, 1), members: [ {name: @alma, data: {name: @alma, type: @harap, src: [_, _], members: [{name: @finom}]}} ]}) ), @def );
        parseModuleContents('class Alma {
                                alma = harap {
                                    finom = true;
                                };
                            }
        ', this.listener);
    }

    test_classDefinitionContentsWithInitializedPrivateMemberWithObject() {
        EXPECT.CALL(this.listener.onDefinition).with(_, @Alma, expanded( propertiesAre({name: @Alma, type: @class, src: (_, 1), members: [ {name: "#alma", data: {type: @harap, src: [_, _], members: [{name: @finom}]}} ]}) ), @def );
        parseModuleContents('class Alma {
                                #alma = harap {
                                    finom = true;
                                };
                            }
        ', this.listener);
    }

    test_classDefinitionContentsWithPrivateFunction() {
        EXPECT.CALL(this.listener.onDefinition).with(_, @Alma, expanded( propertiesAre({name: @Alma, type: @class, src: (_, 1), 
                                                                                        members: [ {name: "#innerFun", data: _, storage: 2 } ]
                                                                                       } ) ), @def );
        parseModuleContents('class Alma {
                                #innerFun() {
                                    let finom = true;
                                }
                            }
        ', this.listener);
    }

    test_classDefinitionContentsWithConstructorInitializedMemberWithConstant() {
        EXPECT.CALL(this.listener.onDefinition).with(_, @Alma, expanded( propertiesAre({name: @Alma, type: @class, src: (_, 1), members: [{name: @alma}, {name: @constructor, storage: 1, data: {src: [_, _, _], id: @constructor, arity: 0, lastLoc: [_, _, _], stmtInfo: [_]}}] }) ), @def );
        parseModuleContents('class Alma {
                                alma;
                                constructor() {
                                    this.alma = 10;
                                }
                            }
        ', this.listener);
    }

    test_classDefinitionContentsWithConstructorInitializedMemberFromContructorParam() {
        EXPECT.CALL(this.listener.onDefinition).with(_, @Alma, expanded( propertiesAre({name: @Alma, type: @class, src: (_, 1), members: [{name: @alma}, {name: @constructor, storage: 1, data: {src: [_, _, _], id: @constructor, arity: 1, lastLoc: [_, _, _], stmtInfo: [_], paramNames: [@num]}}] }) ), @def );
        parseModuleContents('class Alma {
                                alma;
                                constructor(num) {
                                    this.alma = num;
                                }
                            }
        ', this.listener);
    }

    test_classDefinitionContentsWithConstructorInitializedMemberWithOdict() {
        EXPECT.CALL(this.listener.onDefinition).with(_, @Alma, expanded( propertiesAre({name: @Alma, type: @class, src: (_, 1), members: [{name: @alma}, {name: @constructor, storage: 1, data: {src: [_, _, _], id: @constructor, arity: 0, lastLoc: [_, _, _], stmtInfo: [_]}}] }) ), @def );
        parseModuleContents('class Alma {
                                alma;
                                constructor() {
                                    this.alma = new Uiml.odict();
                                }
                            }
        ', this.listener);
    }

    test_classDefinitionContentsWithConstructorInitializedMemberWithFunction() {
        EXPECT.CALL(this.listener.onDefinition).with(_, @Alma, expanded( propertiesAre({name: @Alma, type: @class, src: (_, 1), members: [{name: @alma}, {name: @constructor, storage: 1, data: hasProperties({src: [_, _, _], id: @constructor, arity: 0, lastLoc: [_, _, _], stmtInfo: [_]})}] }) ), @def );
        parseModuleContents('class Alma {
                                alma;
                                constructor() {
                                    this.alma = function() {};
                                }
                            }
        ', this.listener);
    }

    test_classDefinitionContentsWithConstructorInitializedMemberWithArrowfunction() {
        EXPECT.CALL(this.listener.onDefinition).with(_, @Alma, expanded( propertiesAre({name: @Alma, type: @class, src: (_, 1), members: [{name: @alma}, {name: @constructor, storage: 1, data: hasProperties( {src: [_, _, _], id: @constructor, arity: 0, lastLoc: [_, _, _], stmtInfo: [_]})}] }) ), @def );
        parseModuleContents('class Alma {
                                alma;
                                constructor() {
                                    this.alma = ()=>{};
                                }
                            }
        ', this.listener);
    }

    test_classDefinitionContentsWithFunction() {
        EXPECT.CALL(this.listener.onDefinition).with(_, @Alma, expanded( propertiesAre({name: @Alma, type: @class, src: (_, 1), members: [ hasProperties({name: @cut, storage: 2})]}) ), @def );
        parseModuleContents('class Alma {
                                cut() { }
                            }
        ', this.listener);
    }

    test_classDefinitionContentsWithAsyncFunction() {
        EXPECT.CALL(this.listener.onDefinition).with(_, @Alma, expanded( propertiesAre({name: @Alma, type: @class, src: (_, 1), members: [ hasProperties( {name: @cut, storage: 2})]}) ), @def );
        parseModuleContents('class Alma {
                                async cut() { }
                            }
        ', this.listener);
    }

    test_classDefinitionContentsWithDecoratedFunction() {
        EXPECT.CALL(this.listener.onDefinition).with(_, @Alma, expanded( propertiesAre({name: @Alma, type: @class, src: (_, 1), members: [ hasProperties( {name: @cut, storage: 2, decorators: [[_, [_, _]]]})]}) ), @def ); // Symbol curry != @curry
        parseModuleContents('class Alma {
                                @curry
                                cut() {

                                }
                            }
        ', this.listener);
    }

    test_classDefinitionContentsWithDoubleDecoratedFunction() {
        EXPECT.CALL(this.listener.onDefinition).with(_, @Alma, expanded( propertiesAre({name: @Alma, type: @class, src: (_, 1), members: [ hasProperties( {name: @cut, storage: 2, decorators: [[_, [_, _]], [_, [_, _]]]})]}) ), @def ); // Symbol curry != @curry
        parseModuleContents('class Alma {
                                @curry @register()
                                cut() {

                                }
                            }
        ', this.listener);
    }

    test_classDefinitionContentsWithFunctionWithParams() {
        EXPECT.CALL(this.listener.onDefinition).with(_, @Alma, expanded( propertiesAre({name: @Alma, type: @class, src: (_, 1), members: [{name: @cut, storage: 2, data: {src: [_, _, _], id: @cut, lastLoc: [_, _, _], arity: 2, stmtInfo: [ [_, _, _], [_, _, _] ], paramNames: [@mag1, @mag2]}}] }) ), @def );
        parseModuleContents('class Alma {
                                cut(mag1, mag2) { 
                                    mag1 = 1; mag2 = 2;
                                }
                            }
        ', this.listener);
    }

    test_classDefinitionContentsWithFunctionWithMultiParams() {
        EXPECT.CALL(this.listener.onDefinition).with(_, @Alma, expanded( propertiesAre({name: @Alma, type: @class, src: (_, 1), members: [{name: @cut, storage: 2, data: {src: [_, _, _], id: @cut, lastLoc: [_, _, _], stmtInfo: [ [_, _, _] ],arity: 0, restArgs: 1, varInfo: [ [@num, _, _] ], paramNames: [@magok]}}] }) ), @def );
        parseModuleContents('class Alma {
                                cut(...magok) { 
                                    var num = len(magok);
                                }
                            }
        ', this.listener);
    }

    test_classDefinitionContentsWithAccessorGroup() {
        EXPECT.CALL(this.listener.onDefinition).with(_, @Alma, expanded( propertiesAre(
            {name: @Alma, type: @class, src: (_, 1), 
              members: [ {name: @alma, kind: @accessor, dataSrc: (_,2), privSetSrc: (_,4) , 
                            initValue: #{name: @alma, type: @dict, src: (_,5), members: _ }} ]}) ), @def );
        parseModuleContents('class Alma {
                                accessor alma {
                                    get;
                                    #set;
                                } = { value: 42};
                            }
        ', this.listener);
    }


    test_classDefinitionInsideFunc() {
        EXPECT.CALL(this.listener.onDefinition).with(_, @fun, expanded( propertiesAre(
                 {src: (_,1,5), id: @fun, lastLoc: (_,9,_), varInfo: [(@Alma, _, _)],
                  stmtInfo: [(2,32,0)], arity: 0,
                  nested: [
                      {name: @Alma, type: @class, src: (_, 2),
                       members: [{name: @cut, storage: 2, data: {src: (_, 3, 38), id: @cut, lastLoc: (_, 5, 34), 
                                  arity: 2,
                                  stmtInfo: _, paramNames: [@mag1, @mag2]}},
                                  {name: @cat, storage: 2, data: {src: (_, 6, 38), id: @cat, lastLoc: (_, 6, 54), 
                                  arity: 1, restArgs:1,
                                  stmtInfo: _, paramNames: [@m, @args]}},
                                  {name: @cup, storage: 2, data: {src: (_, 7, 39), id: @cup, lastLoc: (_, 7, 51), 
                                  arity: 1, defArgs:1, funcKind: 1,
                                  stmtInfo: _, paramNames: [@a, @b]}},
                                  ] }
                  ] })), _);
        parseModuleContents('fun() {
                               class Alma {
                                 cut(mag1, mag2) { 
                                     mag1 = 1; mag2 = 2;
                                 }
                                 cat(m, ...args) {m=1}
                                 *cup(a,b=5) { a+b}
                               }
                            }
        ', this.listener);
    }

    test_classDefinitionComputedPropInXs() {
        EXPECT.CALL(this.listener.onDefinition).with(_, @fun, expanded( propertiesAre(
                 {src: (_,1,5), id: @fun, lastLoc: (_,9,_), varInfo: [(@Alma, _, _)],
                  stmtInfo: [(2,32,0)], arity: 0,
                  nested: [
                      {name: @Alma, type: @class, src: (_, 2),
                       members: [{name: "[computed]", src: (_,3), storage: 2, data: {src: (_, 3, 42), lastLoc: (_, 5, 34), 
                                  arity: 1,
                                  stmtInfo: _, paramNames: [@m]}},
                                  {name: "[computed]", src: (_,6)},
                                  {name: "[computed]", src: (_,7), storage: 1},
                                  ] }
                  ] })), _);
        parseModuleContents('fun() {
                               class Alma {
                                 ["cut"](m) { 
                                    m=1
                                 }
                                 ["cap"] = 42;
                                 static ["cap"] = 42;
                               }
                            }
        ', this.listener);
    }

    test_classDefinitionComputedPropTopLevel() {
        EXPECT.CALL(this.listener.onDefinition).with(_, @Alma, expanded( propertiesAre(
                 
                      {name: @Alma, type: @class, src: (_, 1),
                       members: [{name: "[computed]", src: (_,2), storage: 2, data: {src: (_, 2, 40), lastLoc: (_, 4, 32),
                                  arity: 1,
                                  stmtInfo: _, paramNames: [@m]}},
                                  {name: "[computed]", src: (_,5)},
                                  {name: "[computed]", src: (_,6), storage: 1},
                                  ] }
         )), _);
        parseModuleContents('class Alma {
                               ["cut"](m) { 
                                  m=1
                               }
                               ["cap"] = 42;
                               static ["cap"] = 42;
                            }
        ', this.listener);
    }

    test_classDefinitionContentsWithBinding() {
        EXPECT.CALL(this.listener.onDefinition).with(_, @Alma, expanded( propertiesAre(
            {name: @Alma, type: @class, src: (_, 1), members: [ 
            {name: @alma, kind: @binding, data: {src: [_, 2, 41], lastLoc: [_, 2, 59], expr: 1, stmtInfo: [ [2, 41, 0] ]}} ]}) ), @def );
        parseModuleContents('class Alma {
                                alma = (nng.appUtils.event);
                            }
        ', this.listener);
    }

    test_classDefinitionContentsWithTwowayBinding() {
        EXPECT.CALL(this.listener.onDefinition).with(_, @Alma, expanded( propertiesAre(
            {name: @Alma, type: @class, src: (_, 1), members: [ {name: @alma, kind: @twoway, data: {src: [_, _, _], stmtInfo: _, lastLoc: [_, _, _], expr: 1}} ]}) ), @def );
        parseModuleContents('class Alma {
                                alma <=> nng.appUtils.event;
                            }
        ', this.listener);
    }

    test_classDefinitionContentsWithTwowayBindingComp() {
        EXPECT.CALL(this.listener.onDefinition).with(_, @Alma, expanded( propertiesAre(
            {name: @Alma, type: @class, src: (_, 1), members: [ 
            {name: @alma, kind: @twoway, data: {src: [_, 2, 43], lastLoc: [_, 2, 54 /* 87*/], stmtInfo: _, expr: 1}} ]}) ), @def );
        parseModuleContents('class Alma {
                                alma <=> { nng.event }, (newVal) { nng.eventt = newVal};
                            }
        ', this.listener);
    }

    test_classDefinitionContentsWithStaticMemberWithoutInitialization() {
        EXPECT.CALL(this.listener.onDefinition).with(_, @Alma, expanded( propertiesAre({name: @Alma, type: @class, src: (_, 1), members: [{name: @alma, storage: 1}]}) ), @def );
        parseModuleContents('class Alma {
                                static alma;
                            }
        ', this.listener);
    }

    test_classDefinitionContentsWithInitializedStaticMemberWithConstant() {
        EXPECT.CALL(this.listener.onDefinition).with(_, @Alma, expanded( propertiesAre({name: @Alma, type: @class, src: (_, 1), members: [{name: @alma, storage: 1}]}) ), @def );
        parseModuleContents('class Alma {
                                static alma = 10;
                            }
        ', this.listener);
    }

    test_interfaceDef() {
        EXPECT.CALL(this.listener.onDefinition).with(_, @Alma, expanded( propertiesAre({name: @Alma, type: @interface, src: (_, 1), members: [{name: @alma, storage: 1}]}) ), @def );
        parseModuleContents('interface Alma {
                                static alma?;
                            }
        ', this.listener);
    }

    test_classDefinitionContentsWithInitializedStaticMemberWithOdict() {
        EXPECT.CALL(this.listener.onDefinition).with(_, @Alma, expanded( propertiesAre({name: @Alma, type: @class, src: (_, 1), members: [{name: @alma, storage: 1, data: {name: @alma, type: @odict, src: [_, _], members: []}}]}) ), @def );
        parseModuleContents('class Alma {
                                static alma = odict {  };
                            }
        ', this.listener);
    }

    test_classDefinitionContentsWithInitializedStaticMemberWithObject() {
        EXPECT.CALL(this.listener.onDefinition).with(_, @Alma, expanded( propertiesAre({name: @Alma, type: @class, src: (_, 1), members: [ {name: @alma, storage: 1, data: {name: @alma, type: @harap, src: [_, _], members: [{name: @finom}]}} ]}) ), @def );
        parseModuleContents('class Alma {
                                static alma = harap {
                                    finom = true;
                                };
                            }
        ', this.listener);
    }

    test_classDefinitionContentsWithStaticFunction() {
        EXPECT.CALL(this.listener.onDefinition).with(_, @Alma, expanded( propertiesAre({name: @Alma, type: @class, src: (_, 1), members: [hasProperties( {name: @cut, storage: 1})]}) ), @def );
        parseModuleContents('class Alma {
                                static cut() { }
                            }
        ', this.listener);
    }

    test_mixinDefinitionContents() {
        EXPECT.CALL(this.listener.onDefinition).with(_, @Mixin, expanded( propertiesAre({name: @Mixin, type: @mixin, src: (_, 1), members: []}) ), @def );
        parseModuleContents('mixin Mixin { };', this.listener);
    }

    test_extendedMixinDefinitionContents() {
        EXPECT.CALL(this.listener.onDefinition).with(_, @Mixin, expanded( 
            propertiesAre({name: @Mixin, type: @mixin, src: (_, 1), extends: @Mixin2, members: []}) ), @def );
        parseModuleContents('mixin Mixin extends Mixin2 { };', this.listener);
    }
	
    test_ClassDefinitionContentsWithMixin() {
        EXPECT.CALL(this.listener.onDefinition).with(_, @Alma, expanded( propertiesAre(
            {name: @Alma, type: @class, src: (_, 1), extends: (@Mixin, @Gyumolcs), members: []}) ), @def );
        parseModuleContents('class Alma extends Gyumolcs with Mixin {
                            }
        ', this.listener);
    }

    test_ClassDefinitionContentsWithMultiMixin() {
        EXPECT.CALL(this.listener.onDefinition).with(_, @Alma, expanded( propertiesAre(
            {name: @Alma, type: @class, src: (_, 1), extends: (@AgainMixin, @OtherMixin, @Base), members: []}) ), @def );
        parseModuleContents('class Alma extends Base with OtherMixin, AgainMixin {
                            }
        ', this.listener);
    }

    test_exportedClassDefinitionContents() {
        EXPECT.CALL(this.listener.onDefinition).with(_, @Alma, expanded( propertiesAre({
            name: @Alma, type: @class, src: (_, 1), members: []}) ), @def );
        parseModuleContents('export class Alma { }', this.listener);
    }

    test_defaultExportedClassDefinitionContents() {
        EXPECT.CALL(this.listener.onDefinition).with(_, @Alma, expanded( propertiesAre( {name: @Alma, type: @class, src: (_, 1), members: []}) ), @def );
        parseModuleContents('export default class Alma { }', this.listener);
    }
    

    test_odictDefinitionContents() {
        EXPECT.CALL(this.listener.onDefinition).with(_, @alma, expanded( propertiesAre( {name: @alma, type: @odict, src: (_, _), members: []} ) ), @def);
        parseModuleContents(' odict alma {}; ', this.listener);
    }

    test_odictDefinitionContentsWithConstMember() {
        EXPECT.CALL(this.listener.onDefinition).with(_, @alma, expanded( propertiesAre( {name: @alma, type: @odict, src: (_, _), members: [ {name: @a} ]} ) ), @def);
        parseModuleContents(' odict alma {a = 1};  ', this.listener);
    }

    test_odictDefinitionContentsWithListMember() {
        EXPECT.CALL(this.listener.onDefinition).with(_, @alma, expanded( propertiesAre( {name: @alma, type: @odict, src: (_, _), members: [ {name: @a, data: { name: @a, type: @array, src: [_, _] }} ]} ) ), @def);
        parseModuleContents(' odict alma {a = [1, 2]};  ', this.listener);
    }

    test_odictDefinitionContentsWithDictMember() {
        EXPECT.CALL(this.listener.onDefinition).with(_, @alma, expanded( propertiesAre( {name: @alma, type: @odict, src: (_, _), members: [ {name: @a, data: { name: @a, type: @dict, src: [_, _], members: [ {name: @b} ] }} ]} ) ), @def);
        parseModuleContents(' odict alma {a = {b: 1}};  ', this.listener);
    }

    test_odictDefinitionContentsWithFunctionMember() {
        EXPECT.CALL(this.listener.onDefinition).with(_, @alma, expanded( propertiesAre( {name: @alma, type: @odict, src: (_, _), members: [ {name: @a, data: { src: [_, _, _], lastLoc: [_, _,_ ], arity: 1, stmtInfo: [ [_, _, _] ], paramNames: [@num] }} ]} ) ), @def);
        parseModuleContents(' odict alma {a = function(num) {num+1}}; ', this.listener);
    }

    test_odictDefinitionContentsWithObjectMember() {
        EXPECT.CALL(this.listener.onDefinition).with(_, @alma, expanded( propertiesAre( {name: @alma, type: @odict, src: (_, _), members: [ {name: @a, data: { name: @a, type: @alma, src: [_, _], members: [] } } ] } ) ), @def);
        parseModuleContents(' odict alma {a = alma {}}; ', this.listener);
    }

    test_enumContentsSimple() {
        EXPECT.CALL(this.listener.onDefinition).with(_, @MyEnum, expanded({  name: @MyEnum, type: @enum, src: _, 
                                                                             members: [ { name: @First },
                                                                                        { name: @Second },
                                                                                        { name: @Third },
                                                                                      ]
                                                                          })
                                                  , @def);
        parseModuleContents('enum MyEnum { First, Second, Third }', this.listener);
    }

    test_enumContentsWithConstants() {
        EXPECT.CALL(this.listener.onDefinition).with(_, @MyEnum, expanded({  name: @MyEnum, type: @enum, src: _, 
                                                                             members: [ { name: @First },
                                                                                        { name: @Second },
                                                                                        { name: @Third },
                                                                                      ]
                                                                          })
                                                  , @def);
        parseModuleContents('enum MyEnum { First=1, Second, Third=5 }', this.listener);
    }

    test_enumContentsComputed() {
        EXPECT.CALL(this.listener.onDefinition).with(_, @MyEnum, expanded({  name: @MyEnum, type: @enum, src: _, 
                                                                             members: [ { name: @First },
                                                                                        { name: @Second },
                                                                                        { name: @Third },
                                                                                      ]
                                                                          })
                                                  , @def);
        parseModuleContents('enum MyEnum { First=1, Second=7*8, Third=Second + 2 }', this.listener);
    }

    test_parsePrivInPrivContentFails() {
        let res = ?? System.parseModule("x(arg) { arg.#privProps }");
        EXPECT.THAT(res, isErrorWithMsg(hasSubstr("Private var reference")));
    }

}

@curry
expanded(expectedValOrMatcher, val, stream) {
	var expanded = ??val.expand();
	if (expanded) {
		var matcher = toMatcher(expectedValOrMatcher);
		return matcher(val.expand(), stream);
	} else {
		stream.add("expanded needs an expandable object as value");
		return false;
	}
}