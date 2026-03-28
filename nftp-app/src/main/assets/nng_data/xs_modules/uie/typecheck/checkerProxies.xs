import { EXPECT, Sample, @registerSuite, @metadata, @tags, Async, indentStreamAndPrependBy } from "xtest.xs"
import { EXPECT_TYPE, hasType, typesOfCall, typesOfCallArgs, typesOfCallRetvals, resolveOverload } from "./typeSystem.xs"
import { typeof, hasProp,weak, strongref, getFailObject } from "system://core"
import  proxy  from "system://core.proxy"
import  Reflect from "system://core.reflect"
import { WeakMap } from "system://core.types"
import { chain, repeat, zipWith} from "system://itertools"

WeakMap proxiedObjects;
WeakMap implTypes;

export createProxy(val, type, name = undef) {
    if (type && type?.applyProxy)
        type.applyProxy(ProxyTraps.createProxyIfNeeded, val, name );
    else
        val;
}

export registerTrapType(obj, type) {
    implTypes.set(obj, type);
}
getImplType(obj) {
    implTypes?.[obj] ?? implTypes?.[obj?.constructor];
}

updateProxyType(trap, type) {
    // if type is dervied of actual type modify it 
    if (type == trap.type || trap.isCallable())
        return;
    for(let btype = type; btype; btype = btype?.extends?.[0]) {
        if (btype == trap.type) {
            trap.type = type;
            break;
        }
    }
}

namespace ProxyTraps {
    export createProxyIfNeeded(val, type, name = undef) {
        let target,trap = unproxy(val);
        let implType = getImplType(target ?? val);
        if (implType) // maybe should check if real derived
            type = implType;
        if (trap) { // already proxied value but update proxy
            // if type is dervied of actual type modify it 
            if (type != trap.type && !trap.isCallable())
                updateProxyType(trap, type);
            return val;
        }
        let kind = type?.kind;
        if (kind == @method)
            kind = @callable;
        if (!kind || (kind != @callable && kind != @interface)) // only wrap callables aind interfaces
            return val;
        // based on type, we wrap the value in a new proxy
        // TODO: tuples, argot array?,struct
        // this might be called with kind == @method in case of module level exported functions
        if (typeof(val) == @object) {
            let res;
            const checkProxyType = w => {
                let t,trap = unproxy(w);
                if (trap && trap?.type != type && !trap.isCallable())
                    updateProxyType(trap, type);
                w;
            };
            const createProxyImpl = () => {
                weak(
                  res = new proxy(val, 
                    kind == @callable || kind == @method ? new CallableCheckerProxyTraps(name, type) 
                                                         : new InterfaceCheckerProxyTraps(type))
                 )};
            let wr= proxiedObjects.upsert(val,
                                              w => w ? checkProxyType(w) : createProxyImpl(),
                                              createProxyImpl);
            return res ?? strongref(wr);
        }
        return val;
    }
}

class ProxyTrapsBase {
    token() { 42; /*token is a function object, used for identifying proxy instances. (A function is used to ensure that is can be stored in the prototype) */}
};

export const unproxy = proxy.unproxyByToken(ProxyTrapsBase.prototype.token, ?);
export const unwrapProxy = proxy.unwrapByToken(ProxyTrapsBase.prototype.token, ?);

class InterfaceCheckerProxyTraps extends ProxyTrapsBase {
    type;
    constructor(type) { 
        super();
        this.type = type;
    }
    isCallable() { false; }
    
    hasProp(object, prop) {
        // replace special names with argot names
        // Note: i don't dare to create dict with special names
        if (prop == Symbol.length)
            prop = "_len";
        else if (prop == Symbol.dispose)
            prop = "__dispose";
        else if (prop == Symbol.iterator)
            prop = "__iterator";

        let member = this.type.findMember?.(prop);
        if (member?.type?.kind == @method)
            return @method;
        else if (member)
            return @get;
        else if (this.type.hasCustomKeys?.())
            return; // ask target enumerator
        else
            return false;
    }
    get(object, prop) {
        if (prop == Symbol.iterator || prop == Symbol.dispose)
            return proxy.NoProperty;
        let member = this.type.findProp?.(prop);
        const isIndexOp = member?.name == "[]";
        if (!member || (!isIndexOp && member?.type?.kind == @method)) // methods will be handled by callMethod
            return proxy.NoProperty;

        let val = Reflect.get(object, prop, undef, proxy.NoProperty );
        if (val == proxy.NoProperty) {
            if (!isIndexOp && !member?.optional)
                error_handler.raise(`mandatory property ${string(prop)} is missing`);
            return val;
        }

        if (isIndexOp) { // check index operator
            let sprop = +prop ?? string(prop); // convert to number or string
            if (hasType(member.type.arguments[0].type, sprop, new Util.ErrorStream)) {
                // index operator cannot be spread so don't have to use typesOfCallRetvals(member.type)
                EXPECT_TYPE(val, member.type.returnValue.type,
                                                            `Type error while indexing ${this.type.name} with ${sprop}\n`);
                return createProxy(val, member.type.returnValue.type, member.name);
            } else 
                return proxy.NoProperty;
        }
        // no need to check callables. methods already handled ( member.type?.kind != @method ) amd callables are called without this

        if (member?.optional && val == undef) // optional prop allowd undef to represent no property and must not be typechecked
            return val;

        EXPECT_TYPE(val, member.type, `Type mismatch, while getting property ${string(prop)} of ${this.type.name}:\n`);
        // based on type, we wrap the value in a new proxy
        return createProxy(val, member.type, member.name);
    }

    set(object, prop, val) {
        let member = this.type.findProp?.(prop);
        if (member?.name == "[]") { // check index operator
            let gprop = +prop ?? string(prop); // convert to number or string to much generic props
            if (hasType(member.type.arguments[0].type, gprop, new Util.ErrorStream)) {
                EXPECT_TYPE({arguments: [gprop], retvals: [val]}, typesOfCall(member.type), 
                                                            `Type error while setting ${gprop} on ${this.type.name}\n`);
                val = createProxy(val, member.type.returnValue.type, member.name);
                return Reflect.set(object, prop, val);
            } else member = undef
        }

        if (!member)
            error_handler.raise(`Setting unknown property ${string(prop)}\n`);
        else if (member.type?.kind == @method)
            error_handler.raise(`Setting method ${string(prop)} which is considered immutable\n`);
        else {// has type desc. 
            EXPECT_TYPE(val, member.type, `Type mismatch, while setting property ${string(prop)} of ${this.type.name}:\n`);
            if (!member?.mutable)
                error_handler.raise(`Setting immutable property ${string(prop)}\n`);
            // based on type, we wrap the value in a new proxy
            val = createProxy(val, member.type, member.name);
        }
        return Reflect.set(object, prop, val);
    }

    handleIteration(object, thisArg) {
        if (let itType = this.type.getIteratorType?.()) {
            if ( hasProp( object, Symbol.iterator ) )
                return Iter.map(object, createProxy(?, itType));
        }
        return proxy.NoFunction;
    }
    forwardSpecCall( object, prop, argotName, args) {
        if (hasProp(object,prop) && !this.type.findMember(argotName))
            error_handler.raise(`${argotName} requested on object but interface ${this.type.name} has not declared it`);
        ?? object[prop]?.(...args);
    }

    callMethod(object, prop, thisArg, ...args) {
        if (prop == Symbol.iterator)
            return this.handleIteration(object, prop);
        if (prop == Symbol.dispose)
            return this.forwardSpecCall(object, prop, "__dispose", args);
        if (prop == Symbol.asyncDispose)
            return this.forwardSpecCall(object, prop, "__asyncDispose", args);
        let candidates = this.type.getOverloads?.(prop) ?? ();
        let funcType = resolveOverload(candidates, args);
        if (funcType)
            ?? callWrapped(object[prop](?), thisArg, args, funcType.type, prop );
        else {
            error_handler.raise(`Called not existing method ${string(prop)}`);
            object[prop](...args);
        }
    }
    keys(object) {
        return proxy.UseTargetKeys, ...this.methodNames(), Symbol.dispose, Symbol.iterator;
        // this can be used with non optional mandatory properties. Now it is better to return oroginal enumerator
        //if (!this.type.hasCustomKeys?.()) return ...this.propNames();
    }
    *methodNames() {
        for(let type = this.type; type; type = type?.extends?.[0]) {
            yield* Iter.flatMap(type.members??(), m => m.type?.kind == @method ? m.name : (:));
        }
    }
    *propNames() {
        for(let type = this.type; type; type = type?.extends?.[0]) {
            yield* Iter.flatMap(type.members ??(), m => m.type?.kind != @method ? m.name : (:));
        }
    }
}

export wrapOverloadedFunc(func, overloads, name, ...args) {
    let funcType = resolveOverload(overloads, args);
    if (funcType)
        callWrapped(func, this ?? undef, args, funcType.type, name );
    else
        func(...args);
}

proxyArgs(args, argTypes) {
    let lastArg = argTypes?.[-1];
    zipWith((val,type) => createProxy(val, type.type, type?.name), args, lastArg?.isSpread ? chain(argTypes, repeat(lastArg)) : argTypes);
}

callWrapped(callee, thisArg, args, funcType, name) {
    EXPECT_TYPE(args, typesOfCallArgs(funcType), `Type error while calling ${string(name)}\n`);

    let res = [?? Reflect.apply(callee, thisArg, proxyArgs(args, funcType.arguments))];
    const retType = ??funcType.returnValue.type;
    if (funcType?.async && (!res.length || !hasProp(res[0], @then)))
        error_handler.raise(`Method ${name} expected to return a promise. It returned `, res);
    if (len(res) <= 0 || (!retType && !funcType.throws))
        return ...res;
    return ?? (funcType?.async ? asyncCheckCallRetval : checkCallRetVal)({funcType, name }, ?? ...res);
}

const asyncCheckCallRetval = Promise.lift(checkCallRetVal);
checkCallRetVal(actCall, ...res)
{
    let funcType = actCall.funcType;
    if (res.length) {
        if (let f = getFailObject(??res[0])) {
            if (!funcType?.throws && !funcType?.async)
                error_handler.raise(`Calleble ${string(actCall.name)} not expected to throw: `, ??res[0]);
            return ??...res;
        }
    }

    EXPECT_TYPE(res, typesOfCallRetvals(funcType), `Type error after called ${string(actCall.name)}\n`);
    // and proxy retvals (at least first returnValue for argot types)
    const retType = ??funcType.returnValue.type;
    // todo: error handling! and wrap all retvals/spread
    if (!retType || !len(res))
        return ...res;
    else if (funcType.returnValue?.isSpread)
        return ...Iter.map(val => ??createProxy(val, retType), res);
    else
        createProxy(res?.[0], retType);
}

class CallableCheckerProxyTraps  extends ProxyTrapsBase { 
    type;
    name;
    isAsync = false;
    constructor(name, type, isAsync = false) { 
        super();
        this.type = type;
        this.name = name;
        this.isAsync = isAsync;
    }
    
    call(callee, thisArg, ...args) {
        // TODO: mayebe thisArg should be ignored
        thisArg =unwrapProxy(thisArg);
        /// @xts-ignore: FIX IT
        ?? callWrapped(callee, thisArg, args, this.type, this.name, this.isAsync )
    }
    isCallable() { true; }

}

