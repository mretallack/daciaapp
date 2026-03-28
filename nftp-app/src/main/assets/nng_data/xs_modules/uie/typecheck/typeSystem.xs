import { typeof, isCallable, hasProp, entries, ident, string } from "system://core"
import { dict } from "system://core.types"
import { map } from "system://functional"
import { @curry } from "core://functional"
import { TypeRepository } from "./typeRepo.xs"

import { getCallerLocAndId } from "xtest/TestFramework.xs"
import { elementsAreFrom, AnyOf, AllOf, indentStreamAndPrependBy } from "xtest/Matchers.xs"

// classes representing types and operation on types

// there are builtin types and user types
// both may have type params (generics)
// also there is a special callable type, representing callable objects (like functions)
// there are some composite types, like tuples or union types
//
// also there are some simple builtin types, like integral types and strings
// the goal is to structure them so they can easily converted from json descriptor, and provide operations to aid easy type checking
// 
// structured types may have special members
// * constructor [Symbol.constructor]
// * index operator - [Symbol.getItem](item:itemType) could be a good match
// structured type members may be also static (probably marked with `static:true` in the member descriptor)
// also structured type may extend other structured types
//
// arguments for callable types may have restArgs: ...arg:type
// and also may return "spreads" (retvals with spread syntax), like call(a,b): ...T, meaning multiretval having elements with the same type

// Problem 1. type references with generic type params: should create some easy to work with object, using the generic type
// Problem 2. how to use check ops on them, maintaining matcher signature, options (type instance should be passed as matcher first arg?) 


class SimpleType {
    name;
    kind = @simple;
    optional = false;
    // mutable;
    constructor(name) {
        this.name = ident(name);
    }
    check(valType, val, stream) { 
        hasBasicType(this.name, val, stream);
    }
}

export class StructuredType {
    kind;
    name;
    members = [];
    extends;
    
    constructor(kind = @interface, name = "") {
        this.kind = ident(kind);
        this.name = ident(name);
    }
    check(valType, val, stream) {
        // todo: maybe returning curried matcher would be better as callstack would be shorter
        if (valType != @object && val != undef) {
            stream.add(`Expected an object with type ${this.name}`);    
            return false;
        }
        
        if (this.kind == @struct && val != undef)
            return hasStructureType(this, val, stream);
        else return true; // see valType check above
    }
    applyProxy(proxyFunc, val, name) {
        if (this.kind != @struct)
            proxyFunc(val, this, name);
        else
            val; // TODO: maybe should copy?
    }
    findMember(prop) {
        for(let type = this; type; type = type?.extends?.[0])
            if (let m = type.members.find(m => string.eq(m.name, prop)))
                return m;
    }
    findProp(prop) {
        if (let m = this.findMember(prop == Symbol.length ? "__len" : prop))
            return m;
        else
            this.findMember("[]"); // maybe findoverloads?
    }
    hasCustomKeys() {
        return this.findMember("[]");
    }
    getIteratorType() {
        if (let m = this.findMember("__iterator")) {
            if (let next = m.type.returnValue?.type?.findMember?.("next"))
                if (let nextRetVal = next.type?.returnValue?.type) {
                    if (nextRetVal?.kind == @union) // hope that first member is the return type
                        return nextRetVal.items?.[0];
                    else
                        return nextRetVal;
                }
        }
        return undef;
    }
    getOverloads(prop) {
        let candidates = [];
        for(let type = this; type; type = type?.extends?.[0]) {
            for(let m in type.members) {
                if (string.eq(m.name,prop)) {
                    if (m.type?.kind != @method)
                        break;
                    candidates.push(m);
                }
            }
        }
        return candidates;
    }
}

class CallableType {
    kind = @callable;
    async = false;
    throws; // true if throws otherwise it can be undef or false 
    arguments = [];
    returnValue = { type: undef, isSpread:false };
    check(valType, val, stream) {
        if (valType != @object) {
            stream.add("Expected a callable object\n");    
            return false;
        }
        return true;
    }
    applyProxy(proxyFunc, val, name) {
        proxyFunc(val, this, name);
    }
}
class Method extends CallableType {
    kind = @method;
}

class UnionType {
    kind = @union;
    items = [];
    check(valType, val, stream) {
        return AnyOf(map(this.items, type => hasType(type)), val, stream);    
    }
    // TODO: applyProxy
}

class EnumType {
    kind = @enum;
    name;
    items = [];
    constructor(name, items) {
        this.name = name;
        this.items = items;
    }
    check(valType, val, stream) {
        let ret = valType == @int && 0 <= val && val < len(this.items);
        ret = ret || valType == @identifier;
        if (!ret) {
            stream.add(`Expected an enum value, got ${val}\n`);
        }
        return ret;
    }
}

@curry
applyProxyFuncIf(proxyFunc, type, val) {
    if (type?.applyProxy)
        type.applyProxy(proxyFunc, val);
    else
        val;
}
class TupleType {
    kind = @tuple;
    items = ();
    check(valType, val, stream) {
        if (valType != @tuple) {
            stream.add("Expected a tuple");
            return false;
        } else {
            // check tuple elements
            return elementsAreFrom(Iter.map(this.items, hasType), val, stream);
        } 
    }
    applyProxy(proxyFunc, val) {
        Iter.zipWith(applyProxyFuncIf(proxyFunc), this.items, val).toTuple();
    }
}

class ArrayType {
    kind = @array;
    itemType;
    check(valType, val, stream) {
        if (valType == @object && typeof(val) == @object && hasProp(val, Symbol.length)) {
            if (this.itemType)
                return elementsAreFrom(Iter.repeat(hasType(this.itemType), len(val)), val, stream);
            return true;
        } else {
            stream.add("Expected an array");
            return false;
        } 
    }
    applyProxy(proxyFunc, val) {
        if (this.itemType)
            Iter.map(applyProxyFuncIf(proxyFunc, this.itemType), val).toArray();
        else
            val.copy();
    }
}

interface ParamSpec {
    name;
    default = undef;
}

interface ParamRef {
    param = 0;
}

interface TypeRef {
    path = [];
    params = []; // ParamRef|TypeRef
}

registerTypeIfNeeded(type, options) {
    if (options?.onCreated)
        options.onCreated(type);
    return type
}

/// @param {TypeRepository} repo
/// @param {string[]} path name of the type (should be a tuple)
/// @param {[]} params instantiation parameters of this type
/// @param {[]} outerParams instantiation context for resolving types in `params`
export resolveType(repo, path, params = undef, outerParams=undef)
{
    if (typeof(path) != @tuple)
        path = Iter.seq(path).toTuple();
    if (path == ("struct",))
        return undef;
    const refParams = params ? typesFromSequence(repo, params, { params : outerParams }) : ();

    let baseType = repo.getType(path);
    if (baseType == undef) {
        console.warn("Invalid type reference: " + path.join("."));
        return new StructuredType(@invalid, path[-1])
    }
    if (refParams) {
        if (let type = repo.getTypeInstance(baseType, refParams))
            return type;
        if (!baseType?.typeParams) // not a generic? TODO: maybe should check for defaults as well
            console.log(`Invalid type instantiation: ${path.join(".")}`);
    } else if (baseType?.constructor)
        return baseType; // already resolved

    let isInRepo = false;
    let refType = typeFrom(repo, baseType, {params:refParams,
        onCreated(type) {
            isInRepo = true;
            if(refParams)
                repo.registerInstanceOf(baseType, refParams, type);
            else
                repo.registerType(path, type);
        }});
    return refType, isInRepo;
}

interface TypeBuildOptions {
    params? = [];
    onCreated?= (obj => {});
}

/// Converts source to a type descriptor objects
/// if a path is specified in options, the type will be registered in the type repo.
/// Types may contain references to their own type (like methods returning the same type)
/// so resolving references should work while building the types themselves.
/// This method should be called only after all type specs are registered to the type repo.
/// It will replace specs with resolved types as it encounters type references from the repo
/// @param {TypeRepository} repo
/// @param source type source
/// @param {TypeBuildOptions} options
export typeFrom(repo, source, options) {
    if (!source || ??source.constructor) {
        return source; // already a resolved type
    } 
    const sourceType = typeof(source);
    const params = options.params ?? ();
    if (sourceType == @identifier || sourceType == @string) { // simple builtin types
        return registerTypeIfNeeded(new SimpleType(source), options);
    } else if (hasProp(source, @path)) { // typeref, this will get a new param list to use towards further resolving
        let refType, isInRepo = resolveType(repo, source.path, source?.params, params);
        if (isInRepo)
            return weak(refType);
        return refType;
    } else if(hasProp(source, @param)) { // resolve parameter
        if (source.param < len(params)) {
            const paramSpec = params[source.param];
            return typeFrom(repo, paramSpec, { });
        }
        return source;  // generic type definition
    } else { // it should be a structured or callable type source, at least a kind member is needed
        let res;
        let kind = ident(source.kind);
        // map arrays of members, arguments and returnValue here recursively
        // but maybe this structure may be better used inside of matchers
        if (kind == @method || kind == @callable ) {
            res = registerTypeIfNeeded(new (kind == @method ? Method : CallableType), options);
            if (source?.throws)
                res.throws=true;
            res.arguments = typesFromSequenceWithAttrs(repo, source.arguments, { params });
            const retval = ??source.returnValue;
            if (retval) {
                res.returnValue.type = typeFrom(repo, source.returnValue.type, { params });
                res.returnValue.isSpread = source.returnValue.isSpread ?? false;
                if (source.returnValue?.optional)
                    res.returnValue.optional = true;
            }

        } else if (kind == @union) {
            res = registerTypeIfNeeded(new UnionType(), options);
            res.items = typesFromSequence(repo, source.items, { params });
        } else if (kind == @tuple) {
            res = registerTypeIfNeeded(new TupleType(), options);
            res.items = typesFromSequence(repo, source.items, { params });
        } else if (kind == @array) {
            res = registerTypeIfNeeded(ArrayType{ itemType = typeFrom(repo,source.params?.[0], {params})}, options);
        } else if (kind == @enum) {
            res = registerTypeIfNeeded(new EnumType(source.name, source.items), options);
        } else {
            // at this point we either have a structured type, which could be generic
            // if the type is generic and no type params are defined for resolving, we simply store the raw generic type
            // otherwise we will resolve the generic params, and store a newly created structured type
            if (hasProp(source, @typeParams) && len(params) == 0) { // generic, but no params defined to resolve...
                return source
            }
            res = registerTypeIfNeeded(new StructuredType(source.kind, source.name), options);
            if (??source.extends) {
                res.extends = typesFromSequence(repo, source.extends, { params });
            }
            res.members = typesFromSequenceWithAttrs(repo, source.members, { params });
        }
        return res;
    }
}

typesFromSequence(repo, seq, options) {
    Iter.seq(seq).map(item => {
        typeFrom(repo, item, options)
    }).toTuple()
}

typesFromSequenceWithAttrs(repo, seq, options) {
    Iter.map(seq, item => {
        const typeWithAttrs = dict.fromEntries(item);
        typeWithAttrs.type = typeFrom(repo, item.type, options);
        if (item?.optional && hasProp(typeWithAttrs.type, @optional))
            typeWithAttrs.type.optional = true;
        if (typeWithAttrs?.async) // (typeWithAttrs is not shared since only methods support)
            typeWithAttrs.type.async = typeWithAttrs?.async; // move async flag inside callable type too
        if (typeWithAttrs?.throws)
            typeWithAttrs.type.throws = typeWithAttrs?.throws;
        return typeWithAttrs
    }).toTuple();
}

/// Types are compatible
wideType(from ,to) {
    if (from == to)
        return true;
    if (from == @identifier && (to == @int || to == @string))
        return true;
    const toIsFloat = (to == @double || to== @float);
    if (from == @int) {
        if (to == @int64 || toIsFloat) return true;
    }
    if (toIsFloat && (from == @int64 || from == @float || from == @double))
        return true;
    return false;
}

/// Covert argot type into Xscript type
export convertBasicType(type) {
    const typeMap = {
        @int32:    @int,
        @uint32:   @int,
        @uint64:   @int64,
        @float:    @double, // TODO: remove, but adjust overloadArgScore to allow conversion between float and double
        @bool:     @int
    };
    return typeMap[type] ?? type;
}

/// Convert SimpleType/EnumType/... into XScript type alternative
overloadArgScore(type, arg) {
    // will add result to score:
    // +2 perfect score
    // +1 lower prio
    if (!type) return 0;
    if (type?.optional && arg == undef) 
        return 2;
    if (type.kind == @simple) {
        if (type.name == @any)
            return 1;
        const basicType = convertBasicType(type.name);
        if (typeof(arg) == @identifier) {
            if (basicType == @string || basicType == @int)
                return 2;
        }
        return basicType == typeof(arg) ? 2 : 0;
    }
    if (type.kind == @callable || type.kind == @method)
        return isCallable(arg) ? 2 : 0;
    if (type.kind == @enum)
        return (typeof(arg) == @int || typeof(arg) == @identifier) ? 2 : 0;
    if (type.kind == @union) {
        return Iter.map(type.items, overloadArgScore(?, arg)).max();
    }
    if (type.kind == @struct) {
        for (let struct = type; struct; struct = struct?.extends?.[0]) {
            for (const m in struct.members ) {
                if (!m?.optional && !hasProp(arg, m.name)) // missing mandatory 
                    return 0;
                // TODO: later we might have tocheck type ov value: ??arg?.[m.name]
            }
        }
        return 2;
    }
    if (type.kind == @array) {
        return hasProp(arg, Symbol.length) ? 2 : 0;
    }
    if (type.kind == @interface) {
        // TODO: refine this
        return typeof(arg) == @object ? 2 : 0;
    }
    return typeof(arg) == type.kind;
}

export resolveOverload(candidates, args) {
    if (len(candidates) <= 1)
        return candidates?.[0];

    const numArgs = len(args);
    let bestIdx = 0;
    let bestScore = -1;
    for (let i = 0; i < len(candidates); ++i) {
        let score = 0;
        if (numArgs <  getNumStrictArgs(candidates[i].type.arguments))
            continue;
        for (let argIdx = 0; argIdx < numArgs; ++argIdx) {
            score += overloadArgScore(candidates[i].type.arguments?.[argIdx]?.type, args[argIdx]);
        }
        if (score > bestScore) {
            bestIdx = i;
            bestScore = score;
        }
    }
    candidates[bestIdx];
}

// type matchers ------------------------------------------------------------------------------------------------------

/// generic type matcher
/// @param type represents a type structure defined above: SimpleType, Structured etc.
@curry export hasType(type, val, stream) {
    const valType = typeof(??val);
    if (type == undef) {
        if (val != undef) {
            stream.add(`Expected undef. `).add("Got: ").addSource(val).add("\n");    
        }
        return val == undef;
    } else if (val == undef && type?.optional) {
        return true;
    } else if (typeof(type) == @identifier) 
        return hasBasicType(type, val, stream);
    else 
    // todo: if it has @param, then replace with the correct type
        return type.check(valType, val, stream);
}

@curry
export hasBasicType(type, val, stream) {
    if (type == @any) return true;
    const valType = typeof(val);
    const expType = convertBasicType(type);
    if (valType != expType && !wideType(valType, expType)) {
        stream.add(`Expected an ${type}. Got `).addSource(val).add(` with type ${valType}\n`);
        return false;
    }
    if (type == @bool && (val < 0 || 1 < val)) {
        stream.add(`Expected a @bool. Got `).addSource(val).add(` with type ${valType}\n`);
        return false;
    }
    return true;
}

/// @param {StructuredType} type structured type descriptor
/// this checks should be performed only on structs (where `type.kind == @struct`)
@curry export hasStructureType(type, val, stream) {
    let res = true;
    const startPos = stream.pos;
    for (let struct = type; struct; struct = struct?.extends?.[0]) {
        for (const m in struct.members ) {
            const lastPos = stream.pos;
            let memVal = ?? val?.[m.name];
            if (memVal == undef) {
                if (!(m?.optional)) {
                    res = false;
                    stream.add(`Member missing: ${m.name}\n`);
                }
            } else if (!hasType(m.type, memVal, stream)) {
                indentStreamAndPrependBy(stream, lastPos, "  ", () => {
                    stream.add(`While checking meber: ${string(m.name)}\n`);
                });
                res = false;
            }
        }
    }
    if (!res) {
        indentStreamAndPrependBy(stream, startPos, "  ", () => {
            stream.add(`Expected a value with type ${type.name}\n`)
        })
    }
    return res;
}

getNumStrictArgs(typeArgs) {
    let numTypeArgs = len(typeArgs);
    if (typeArgs[-1].isSpread ?? false)
        --numTypeArgs; 
    let numStrictArgs = numTypeArgs; // the arguments have to be provided, as they aren't defaulted
      while (numStrictArgs > 0 && (hasProp(typeArgs[numStrictArgs - 1], @default)|| typeArgs[numStrictArgs - 1]?.optional)) {
        --numStrictArgs;
    }
    return numStrictArgs;
}
/// @param {array} args arguments of call
/// checkk the arguments of call matches its type
@curry export typesOfCallArgs(callableType, args, stream) {
    let numArgs = len(args);
    let success = true;
        
    const typeArgs = callableType.arguments;
    let numTypeArgs = len(typeArgs);
    let hasRestArgs = typeArgs[-1].isSpread ?? false;
    if (hasRestArgs) {
        --numTypeArgs; 
    }
    let numStrictArgs = getNumStrictArgs(typeArgs);
    if (numArgs > numTypeArgs && !hasRestArgs) {
        while(numArgs > numTypeArgs && args[numArgs-1] == undef)
            --numArgs;
    }
    
    if (numArgs < numStrictArgs) {
        stream.add(`Not enough arguments provided for call, expected at least ${numStrictArgs} arguments`);
        success = false;
    } else if (numArgs > numTypeArgs && !hasRestArgs) {
        stream.add(`Too many arguments provided, more than ${numTypeArgs}`);
        success = false;
    }
            
    for (let idx = 0; idx < numArgs; ++idx) {
        const arg = idx < numTypeArgs ? typeArgs[idx] : (hasRestArgs ? typeArgs[-1] : undef );
        if (arg) {
            const lastPos = stream.pos;
            if (!hasType(arg.type, args[idx], stream)) {
                indentStreamAndPrependBy(stream, lastPos, "  ", ()=> stream.add(`While checking argument no. ${idx + 1} (${arg.name})\n`));
                success = false;
            }
        }
    }
    return success;
}

/// @param {array} res arguments of call
/// checkk the retvals of a call matches its type
@curry export typesOfCallRetvals(callableType, res, stream) {
    // check retvals
    let success = true;
    const retType = ??callableType.returnValue;
    if (len(res) > 0 && retType) {
        if (retType.isSpread) { // check all retvals for the same spread type
            for (let idx = 0; idx < res.length; ++idx) {
                const lastPos = stream.pos;
                if (!hasType(retType.type, res[idx], stream)) {
                    indentStreamAndPrependBy(stream, lastPos, "  ", ()=> stream.add(`While checking ${idx+1}th return value\n`));
                    success = false;
                }
            }
        } else {
            const lastPos = stream.pos;
            const val = retType.type ? res[0] : undef;
            if (retType?.optional && val == undef)
                return true;
            if (!hasType(retType.type, val, stream)) {
                indentStreamAndPrependBy(stream, lastPos, "  ", ()=> stream.add(`While checking return value\n`));
                success = false;
            }
        }
    }
    return success;
}

/// @param actual is in {arguments, retvals } format
@curry export typesOfCall(callableType, actual, stream) {
    typesOfCallArgs(callableType, actual.arguments, stream);
    typesOfCallRetvals(callableType, actual.retvals, stream);
}

export EXPECT_TYPE(val, typeMatcher, message, srcLoc) {
    var s = new Util.ErrorStream;
    // convert typeMatcher to matcher if it isn't
    if (!isCallable(typeMatcher))
        typeMatcher = hasType(typeMatcher);
        
    var res = typeMatcher(??val, s);
    if (!res) {
        // todo: this source location handling may be refined later, to display error at the location of call, prop access etc.
        // add source loaction to the start of the stream
        if (message) {
            indentStreamAndPrependBy(s, 0, "  ", ()=>{
                if (isCallable(message)) message(s);
                else s.add(message);
            });
        }
        if (!srcLoc) 
            srcLoc = getCallerLocAndId(1, @EXPECT_TYPE);
        var lastPos = s.pos;
        s.addSrcInfo(srcLoc);
        s.moveTailToPos(0, lastPos);
        
        error_handler.raise(s); 
    }
}
