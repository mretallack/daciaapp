/// [module] core://functional
import { curry, curryN, objOf, apply, tap, thunk, thunkify, pipe, prop, path, cmp } from "system://functional"
export * from "system://functional";

export decorator @curry { @wrap(curry) }
export decorator @curryN(n) { @wrap(curryN(n)) }

@curry
export applyIterValue(mapFunc, kv) { (kv[0], mapFunc(kv[1])); }
@curry
export applyIterKey(mapFunc, kv) { (mapFunc(kv[0]), kv[1]); }

// takes: iter,s and selects items from iter where s is true
export const compress = Iter.zipWith((val,s) => s ? val : (:));

//  makes an iterable object from a function that returns an iterator
export const toIterable = objOf(Symbol.iterator); // same as toIterable(f) { return { [Symbol.iterator]() { f(); }} } // maybe should check if is not an iterator but an iterable
/*
  Usage of genToIter: 
    *gen(a,b) { ... }
    let iterable = genToIter(gen, 1, 2);
    iterable can be iterated as many times as wanted each iteration will invoke gen
  Above genToIter is the same as
     genToIter(gen, ...args) { toIterable(thunk(gen, ...args)) } // or
     genToIter(gen, ...args) { thunk(gen, ...args) |> toIterable(^) } 
     const genToIter = +> toIterable(thunk(^)) = +> thunk(^) |> toIterable(^)

  Usage of iterify:
   let g = iterify(gen);
   let iterable = g(1,2);
   let iter2 = g(42,54); // or g(42)(54)
  `iterable` is the same as above
 */
export const genToIter /*(gen, ...args)*/ = pipe(thunk, toIterable); // +> toIterable(thunk(^)) thunk ensures that 
export iterify(g) { curry(pipe(thunkify(g), toIterable)); } // outer curry ensures that pipeline will be only created and called if arity of g is matched
export iterifyN(n,g) { curryN(n, +> toIterable(thunk(g,^)))}

export logInspectM(msg) { tap(console.log(msg, ?)) }
export const logInspect = tap(console.log(?)); // passes to log but returns

_cmpBy(argsMap) { pipe(argsMap, cmp)} // generic version should use mapArgs, but prop and path already does this
export cmpByProp(name) { _cmpBy(prop(name))}
export const cmpByPath = +> _cmpBy(path(^))
