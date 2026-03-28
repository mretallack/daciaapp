/// @xts-ignore  
import { EXPECT, Sample, TestSuite, @registerSuite, @metadata, Async, MockFunction, elementsAre, elementsAreFrom, _ } from "xtest.xs"
import {analyze, describeVar, global as Global} from "system://inspect.xs"
import {Map} from "system://core.types"
import {proxy, Proxy} from "system://core.proxy"
import {apply} from "system://functional"
import Reflect from "system://core.reflect"

s1() {
    let x = 8;
    let y,z = 1;
    a = 1+2;
    x+9;
    y=x;
    alma(1,x,y);
}

s2(p1, p2) { // no local vars
    (1 && ( 2 && 3)) || 4;
    if (p1)
    {
        alma.korte(1);
        banan(2);
    }
    p2 &&= 2;
    p1 = p1 ? 42 : -42;
}
s3(p1/*=5*/) {
    x.y+=1;
    alma.korte(1, x.y=1, x.z, x.z(1));
    1,2, {a:3,b:4}
}
s4() {
    if (alma) // ReturnIf(alma)
        korte+4; // Return(+(kore,4))
}
s5() {
    if (alma) // Cond(alma, Return(+(korte,4)))   -- a return miatt nincs else
        korte+4; 
    else if (alma==3) // Cond(==(alma,3), Return(*(korte,2))) -- a return miatt nincs else
        korte*2; 
    else
        korte // Return(korte)
}

s5_nr() {
    // Group(
    if (alma) // Cond(alma, -- if es else aga is lesz
        korte+4; // +(korte,4) -- nincs group, mert csak ebbol al es a kulso group fogja stacket letakaritani
    else if (alma==3) // ,Cond(==(alma,3), -- az else resze az elso Cond-nak
        korte*2;  // *(korte,2) -- itt sincs group
    else
        korte; // , korte)) -- mindket Condot zarja, azaz  Cond(,,Cond(,,)) a strukture
    // ) -- end of Group
    kutya+1; // Return(+(kutya,1))
}

s6lv() {
    let x=1;
    // Group(
    if (alma) // Cond(alma,
        korte+4; // +(korte,4) -- nincs group, mert csak ebbol al es a kulso group fogja stacket letakaritani
    else
        korte; // , korte)) -- mindket Condot zarja, azaz  Cond(,,Cond(,,)) a strukture
}

s6lv_nr() {
    let x=1;
    // Group(
    if (alma) // Cond(alma,
        korte+4; // +(korte,4) -- nincs group, mert csak ebbol al es a kulso group fogja stacket letakaritani
    else
        korte; // , korte)) -- mindket Condot zarja, azaz  Cond(,,Cond(,,)) a strukture
    return x,1;
}

s7_ifvar_ret() {
    if (let x=fcall(1,2)) { // Cond_KeepAlways(List_1(Call(fcall,1,2)), Return(Call(x,42))
        x(42);
    } // else nem resze Cond-nak, viszont akkor figyelni kell, hogy a var scopeja "kiloghat" es akar cond is deklaralhat
    else { // Return(Call(Prop4Call(console, log), "Milyen x:", var_x))
        console.log("Milyen x:", x);
    }
}

s7_ifvar_nret() {
    // Group( -- az if van groupban
    if (let x=fcall(1,2)) { // Cond_KeepAlways(Call(fcall,1,2)
        x(42); // , Call(x,42)
    } else { // 
        x; // , x )
    }
    // )
    alma; // Return(alma)
}

s8_opt_ch() {
    a?.b?.c?.(1,2)?.[3](4);
}

class Analyzer {
    closureEnv=undef;
    returns(...res) {console.log("Will return:", ...res, "!")}
    literal(l) { l; }
    binary(op, left, right) { (left,op, right); }
    unary(op, left) { (op, left); }
    compose(op /*@tuple, @dict, @array, @multi??*/, ...args) { []; }
    param(idx) { (@param, idx); } // idx is number|@this 
    resolve(name) { (@module, name); }

    newFunction(closureEnv, func) { 
        const AnalyzerType = this.constructor;
        analyze(func, AnalyzerType { closureEnv = closureEnv}); 
        func
    }
    index(options, o, p) { (...Iter.seq(o), "->", p); }
    assign(o, p, val) {console.log("assign:", o == Global ? @global : o, p, val); val; } // o=Global means global/module
    callMethod(opts, o, p, ...val) { (...Iter.seq(o), ":", p, '(', ...val, ')'); }
    resolvePrivName(privIdx) { (@privName, privIdx); }
    resolveUpValue(id) { 
        if (!this.closureEnv) {
            let kind,idx = describeVar(id); // kind is @param, @var, @closure, @this or @super
        }
        this.closureEnv.getVar(id);
    }
    assignUpValue(id, value) {
        if (this.closureEnv)
            return this.closureEnv.setVar(id, value);
        return value;
    }
    assignParam(idx, value) {value }
    condEnter(opt,...condVals) { console.log(`Enter condition ${opt.id} on condition:`, ...condVals); ...condVals; }
    condElse(bid,ifRes) {console.log(`Starting else for ${bid}`); }
    condExit(bid,...res) {console.log(`Exit condition for ${bid}`); ...res }
    groupEnter(bid) {console.log(`Entering group ${bid}`); }
    groupExit(bid, grpVals)  {console.log(`Exit group ${bid} with ${grpVals}`); }
}
class AnalyzerWithMockReturn extends Analyzer {
    returns = MockFunction { name="returns"; }
    m_assign = MockFunction { name="assign"; }
    m_assignParam = MockFunction { name = "assignParam"; }
    assign(o, p, val) {
        this.m_assign(o, p, val);
        return val;
    }
    assignParam(p, val) {
        this.m_assignParam(p, val);
        return val;
    }
}

s100(p) {
    akar += 8;
    let x =1;
    x+2+p + akarmi;
}

removeFavorite(item) {
    const favs = favoriteRegistry[item.type];
    if (favs.has(item.id)) {
        favs.remove(item.id); 
        const idx = favorites.findIndex((o) => { o.id == item.id && o.type == item.type });
        favorites.splice(idx, 1);
        saveContents();
    }
}
loadContents(favList) {
    // load from persistency
    const lst = store.getItem("list") ?? [];
    favList.push(...lst);
    for (const item in lst) {
        favoriteRegistry[item.type].set(item.id, undef);
    }
}

export async getStreamUrl(stationId) {
    var url = `${urls.api}/stations/byuuid/${stationId}`;
    var res = ??await http.get(url).then((r) => JSON.parse(r));
    // will return an array with one item
    if (res && res[0])
        return res[0];
    else return false;
}

/* todo optimize break in Xs: `if (expr) break;`
    expr JumpIf(cond,2) RS Return RS   could be simplified to: expr RetIf(!cond) RS
    expr JumpIF(cond,2) RS Jump(t) RS  could be simplified to: expr JumpIf(!cond,t) RS
    */

someLoop() {
    // let x = 0; for(let i in [1,2,3]) { if (!i) break; ++x;} else { console.log(x)}
    let x = 0; for(let i in [1,2,3]) { if (!i) break; ++x;} else { x *= 10}  console.log(x)
    // let x = 0; for(let i=0; i <3; ++i) { if (i<0) break; ++x;} else { x *= 10} 
    // let x = 0; for(let i=0; i <3; ++i) { if (i<0) break; ++x;} else { x *= 10}  console.log(x)
/*    for(const v in modVar) {
        if (v <0) break;
        if (!v) continue;
        v + 1;
    }*/
}

// overindex in processtreerange, also looks like an infinite loop
validate_email(value) {
    var reObj = new re.Regexp("[a-z0-9!#$%&'*+/=?^_`{|}~-]+(?:\.[a-z0-9!#$%&'*+/=?^_`{|}~-]+)*@(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])", "i");
    var res = reObj.exec(value);
    if (res) for (var m in res.matches) {
        if (m == value) {
            return true;
        }
    }
    return false;
}

// ASSERT(CheckOpCode(opCode, OpCode::LocalVarRef));
// tries to check `test` and `use` as global name 
addDemoForSample(test) {
    const demoData = test.suite.demo;
    registerDemo({
        title: demoData.title ?? test.suite.id,
        id: `sample.{test.suite.id}`,
        date: demoData.date,
        description: demoData.description ?? "",
        state: state{ use = frSampleDemo; test = test }
    });
}
// overindex values in ProcessTreeRange
async convertForecast( weatherLocation, res ){
    if ( res ) {
        weatherLocation.forecastList.clear();
        for ( var item in res.list ){
            var data = {};
            data.currentTemp = Math.round(item.main.temp-273);
            data.tempMin = Math.round(item.main.temp_min-273);
            data.tempMax = Math.round(item.main.temp_max-273);
            data.icon = await iconCache.get( item.weather[0].icon );
            data.description = item.weather[0].description;
            data.time = new date(int64(item.dt)*1000);
            weatherLocation.forecastList.append( data );
        }
    }
    1;
}

// overindex values in ProcessTreeRange
function expandFallbackPaths(theme){
    if (theme.name == themeManager.defaultTheme.name)
        return "<none>";

    var ret = "'";
    if ( ??theme.fallbackPaths ){
        for(var x in theme.fallbackPaths){
            ret += x + "', ";
        }
    }

    ret += "'" + themeManager.defaultTheme.name + "'";
    return ret;
}

// instead of using data inside of the for, it indexes 0 (probably i) with currentTemp etc. 
getForecast( weatherLocation ){
    if ( !len(weatherLocation.forecastList) ) {
        weatherLocation.forecastList.clear();
        var currentTime = new date();
        for ( var i=0; i<10; i++ ){
            currentTime = currentTime.add( new timespan( 3h ) );
            var data = {};
            data.currentTemp = Math.random(weatherLocation.currentTemp-5,weatherLocation.currentTemp+5);
            data.tempMin = Math.random(weatherLocation.currentTemp-5,weatherLocation.currentTemp+5);
            data.tempMax = Math.random(weatherLocation.currentTemp-5,weatherLocation.currentTemp+5);
            data.icon = "icons/02d.png";
            data.description = descriptonList[Math.random(5)];
            data.details = [];
            data.time = currentTime;
            weatherLocation.forecastList.append(data);
        }
    }
}

// crash in FinishLastCondAndCheckSkip
processShortOpt(args, i, result) {
    const arg = args[i].substr(1);
    for (let idx = 0; idx < arg.length; ++idx) {
        let opt = arg[idx];
        const descriptor = this.options.get(opt) ?? undef;
        if (descriptor) {
            let val = descriptor.nargs == 0 ? true : descriptor.default; // flags will be set to true when present
            if (descriptor.nargs > 0) {
                if (idx + 1 < arg.length) {
                    val = arg.substr(idx + 1);
                    idx = arg.length;
                } else {
                    val = args[++i] ?? descriptor.default; 
                }
            }
            if (val == undef && descriptor.nargs)
                return failure({message: `No value provided for ${opt} option`});
            if (descriptor.nargs == 2) {
                if (result.options?.[descriptor.name] == undef)
                    result.options[descriptor.name] = [];
                result.options[descriptor.name].push(val);
            } else {
                result.options[descriptor.name] = val;
            }
        } else {
            return failure({message: `Unknown short option: ${opt}`});
        }
    }
    return i;
}

garbage() {
    let toDelete = [];
    for (let item in this.windows) {
        let noParent = (item.window.parent??false) ? false : true;
        if (noParent) toDelete.push(item);
    }
    for (let item in toDelete) {
        if (item) this.deleteWindow(item.window);
    }
}

    callMethod(opts, o, p, ...args) {
        if (!o?.type) return any;
        const prop = p?.value;
        if (prop == Symbol.constructor) {
            let instance = dict.fromEntries(o);
            instance.typeInstance = 0;
            return instance
        } else if (p == Symbol.call || prop==Symbol.call) { // o is a callable object. NOTE: in this case SYmbol.call won't be converted to literal
            // todo: check arguments etc.
            return o.returnValue[0] ?? any;
        } else {
            const method = this.index({}, o, p);
            // todo: check call, argument types etc

            // return the return type of the method
            return method.returnValue[0] ?? any; // todo: handle multiple retvals
        }
    }

    listUnusedMatchers(result, stream) {
        const matches = result.matches;
        stream.add("Too many matchers specified: \n");
        for (let exp = 0; exp < this.numMatchers; ++exp) {
            if (matches[exp] != @unmatched) continue;
            addIndented(stream, "  ", `Unused matcher at index: ${exp}\n`);
        }
    }

pipeline() {
    let x,y = -19, 0; idfun(8,9,11) |> (: 2,3, (: x, ^) |> idfun(y, ^) ) |> (^,42) 
}
@registerSuite 
class XsCheckSample extends Sample {
    sample_check() {
        Analyzer a;
        analyze(listUnusedMatchers, a);
        /*analyze(garbage,a);
        analyze(s100, a);
        analyze(s8_opt_ch, a);
        analyze(convertForecast, a);
        analyze(addDemoForSample, a);
        analyze(validate_email, a);
        analyze(expandFallbackPaths, a);
        analyze(getForecast, a);
        analyze(processShortOpt, a);*/
    }

    sample_prefix() {
        analyze(s3);
        //analyze(s6lv);
        //analyze(s6lv_nr);
        // analyze(s8_opt_ch);
    }
    sample_checkfewstuff() {
        for(let x in [s1,s2,s3, s4, s5, s5_nr, s6lv, s6lv_nr, s7_ifvar_ret, s7_ifvar_nret, s8_opt_ch])
            analyze(x);
    }

    sample_parseIze() {
        dict data {
            kutya = { fule: "szep"};
            sun = Map _ [["fule", 5], [@fun, function() {42}]]; // ha itt nincs _ akkor nagyon csunyan megmakkant a parser
             // mert ITT, Xs-ben levo data expr-nel = jobb oldalan expression van es a [] indexinget jelent, amiben nem lehet tobb elem
        }
        let megpukkantEaParizel = true;
    }

    sample_condEx() {
        function f(p) {
            let x=0;
            if (p)
                x = p * 2;
            else {
                let y = p;
                p=x; x=y;
            }
            p,x;
        }
        Analyzer am;
        analyze(f, am);
    }
    
    sample_funcWithDefaults() {
        // Fails because of overindex in RelocVector
        const f = function(query = { limit: 20}) {
            this.results = new list();
            this.name = query.name ?? undef;
            this.tags = query.tags ?? [];
            this.limit = query.limit ?? 20;
        };
        AnalyzerWithMockReturn am;
        analyze(f, am);
    }
    
    sample_probablyMisalignedCalls() {
        const f = function() {
           this.filterSub = observe(()=> { this.filter }).subscribe((subs, newFilter) => {
                this.scheduleSearch();
           }) 
        };
        AnalyzerWithMockReturn am;
        analyze(f, am);
        // check callmethod in analyzer: o is set to observe, but p is the closure argument, instead of Symbol.call
    }  
    
    sample_getKeyName() {
        function getKeyName( obj, value ) {
            for( var key, v in Util.entries( obj ) ) {
                if ( v == value ) {
                    return string( key );
                }
            }
            return "";
        };
        Analyzer a;
        // crash in PostfixToPrefix
        analyze(getKeyName, a);
    }  

// constructor() {
//         this.#filterSub = observe(()=> { this.filter }).subscribe((subs, newFilter) => {
//             this.scheduleSearch();
//         })
}

@registerSuite 
class XsCheckTest extends TestSuite {
    test_propPathAndCall() {
        AnalyzerWithMockReturn am;
        EXPECT.CALL(am.returns).with(elementsAre(@module, @alma, "->", @korte, "->", @banan));
        analyze(()=> alma.korte.banan, am);

        AnalyzerWithMockReturn am2;
        EXPECT.CALL(am2.returns).with(elementsAre(@module, @alma, "->", @korte, ":", @banan, '(', 10, 20, ')'));
        analyze(()=> alma.korte.banan(10,20), am2);

        AnalyzerWithMockReturn am3;
        EXPECT.CALL(am3.returns).with(elementsAre(@module, @alma, ":", Symbol.call, '(', 1020, ')'));
        analyze(()=> alma(1020), am3);
    }
    test_assign() {
        AnalyzerWithMockReturn amA;
        EXPECT.CALL(amA.m_assign).with(elementsAre(@module, @alma, "->", @korte), @banan, 8);
        EXPECT.CALL(amA.returns).with(8);
        analyze(()=> {alma.korte.banan=8}, amA);

        AnalyzerWithMockReturn amB;
        const propVal = (@module, @alma, "->", @korte, "->", @banan);
        const sum = (propVal, @add, 8);
        EXPECT.CALL(amB.m_assign).with(elementsAre(@module, @alma, "->", @korte), @banan, sum);
        EXPECT.CALL(amB.returns).with(sum);
        analyze(()=> {alma.korte.banan += 8}, amB);
    }
    test_assingGlob() {
        AnalyzerWithMockReturn amGlob;
        const val = (@module, @alma);
        const sum = (val, @add, 42);
        EXPECT.CALL(amGlob.m_assign).with(Global, @alma, sum); // global assign gets args: `undef, name, value`
        EXPECT.CALL(amGlob.returns).with(sum);
        analyze(()=> {alma += 42}, amGlob);
    }
    test_assingParam() {
        AnalyzerWithMockReturn am;
        const val = ((@param, 1), @definedOr, 42);
        EXPECT.CALL(am.m_assignParam).with(1, val);
        EXPECT.CALL(am.returns).with((@param, 1));
        analyze((b) => {b??=42; b}, am);
    }

    test_closureGetParam() {
        class AMockParam extends AnalyzerWithMockReturn {
            param = MockFunction{name="param"};
        };
        AMockParam am;
        EXPECT.CALL(am.param).with(1).will(idx=>(@param,idx));
        EXPECT.CALL(am.param).with(@this).will(idx=>(@this));
        EXPECT.CALL(am.returns).with((@module, @invoke, ":",  Symbol.call, "(", _, ")")).times(1);
        // EXPECT.CALL(todoInnerMock.returns).with(((@this, "->", @x),(@param, 1)));
        function f(p) {
            invoke(_ => {this.x, p});
        }
        analyze(f, am);
    }

    test_closureAssignParam() {
        class AMockParam extends AnalyzerWithMockReturn {
            param = MockFunction{name="param"};
            assignParam = MockFunction{name="assingParam"};
        };
        AMockParam am;
        EXPECT.CALL(am.assignParam).with(1, (@outerThis, "->", @x)).will((_,val) => val).times(1);
        EXPECT.CALL(am.param).with(@this).will(idx=>(@outerThis));
        EXPECT.CALL(am.returns).with((@module, @invoke, ":",  Symbol.call, "(", _, ")")).times(1);
        // EXPECT.CALL(todoInnerMock.returns).with(((@this, "->", @x),(@param, 1)));
        function f(p) {
            invoke(_ => {p = this.x});
        }
        analyze(f, am);
    }

    test_assingLocVar() {
        AnalyzerWithMockReturn amGlob;
        const sum = (_, @add, 42);
        EXPECT.CALL(amGlob.m_assign).with(Global, @b, sum); // global assign gets args: Global, name, value`
        EXPECT.CALL(amGlob.returns).with(sum);
        analyze(() => {let a; b=(a+=42); a}, amGlob);
    }   
}
