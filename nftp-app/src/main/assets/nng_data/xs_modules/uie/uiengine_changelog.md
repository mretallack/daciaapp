# Changelog
All notable changes to this domain will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## 2024.06.10

### Added
- `switchShrink` property to the switch component that can control the `canShrink` property of the knob.

## 2024.04.22

### Added
- Yellow heca config.

### Changed
- Heca try to read local config relative to working directory first.

## 2024.02.26

### Added

### Changed
- removed obsolete builtin unit formatters "%{}" for the format/sprintf family (e.g. "%{data}", distance, timespan...)

## 2023.06.15

### Added
- Android softinput integration improved. It is now closer to proper working. (Copy paste, selection still missing)

## 2023.05.18

### Added
- fs.acrhive module (WIP)
- richFmt of fmt module accepts formatted parameter (a tuple) copied as is to the output for `text` property of text widgets
- URL object and parse added to web.URI module
- date object got `time` property for utc timestamp
- map object forEach, removeIf

### Changed
- xscript breaking change: comparison of failures used to result in failure now it yields true/false result. A failure is only equal to itself
- http fetch request body accepts Uint8Array
- assert debug break fix during restart
- ifw safer object cast

## 2023.04.20

### Added
- `textWidget.reevaluteText()` reevaluates text causing
  - toString() to be called again (e.g. when localization changes of i18n) 
  - refreshes any richText styles (normally non-widget styles are not expected to change)
  - reevaluates text binding if passed a true parameter
- add `import {} from "uie/util/refreshTextOnLangChange.xs"?` to reevalute text props on lang change
- can import json modules, e.g. `import jsonData from "some.json" with {type: json}`
  - json modules (aka https://www.proposals.es/proposals/JSON%20Modules)
  - import, export attributes (aka https://github.com/tc39/proposal-import-attributes)
  - added option to sysImport(), e.g. `sysImport("sample.json", #{ with: #{type: @json }})`
- json parser can accept __jsonc__ , pass @jsonc to parse function or use `{type: jsonc }`

### Changed
- `querySelector` and `querySelectorAll` only checks its descendants (see https://developer.mozilla.org/en-US/docs/Web/API/Element/querySelectorAll)
- `querySelectorAll(selector)` returns an iterable instead of multiretval (search is made on-demand)

## 2023.03.01

### Added
- `Promise.withResolver()` returns a promise and its resolve and reject functions.
- Shebang (`#!`) is ignored at beginning of an xs file
- Linux (posix) some signals can be handled in xscript
- `htons` and `htonl` to socket module
- DataReader and writer size can be changed by setting its `byteLength` property

### Changed
- android module - use Long instead of kotlin's ULong since function names will be mangled by kotlin
- Improved version info of xs executable
- Improved where xs, uie executable on linux where it looks for its libraries (set runpath to $ORIGIN)
- fixed X11 international keyboard handling 
- Most of the Math functions returns float when operating with float
- Math trigonometric function accepts `@deg` beside the true value to use degrees instead of radian

## 2023.01.31

### Added 
- Added float support, literal and arithmetic
- Added module system://geo, with distance and spatial index, see system.geo.d.xs
- Added module system://db.WordIndex 

### Changed
- Fahrenheit unit literal should be writter as `Fh` instead of `F` since `1F` is float. (Unit.value(num, @F) still accepted)
- await in xscript supports multiple return values. e.g. `let a,b = await multiRetvalFunc()` works. Used to return a tuple
- optional pipeline operator (`|?>` or `?|>`) short circuits if left side is undefied.. It skips over the entire right pipeline <br>
 e.g. a ?|> b(^) |> c(^) won't call neither b nor c. If `a` is list (multiple values) it is kept, undef if empty or if first value is not defined (undef or failure)
 
## (NSDK 1.10.0-alpha.17561)
- added custom ui event definition and dispatching interface
  - `defineEvent(evt, handler)` from `ui.core` module can define a new custom event, handler property on widgets automatically adds event listeners
  - `CustomEvent` constructor or call can create a new custom event
  - added `dispatchEvent(evt)` to visual object to dispatch an event
  - added `currentTarget` property to Ui events to be used instead of `this` when handler is arrow function (normal function are called with this set to the widget)
- XTest supports visual check
- `Date` contrustor has `now()` method returning millisecs from epoch, Date is an alias of date (import {Date} from "system://core.types" or Uiml.Date.now())
- `debug.screenshot(displayAndOptions, @image)`  returns an image object
- `debug.saveScreenshot()` saves screenshot as ffscreen*.bmp as usual
- undlerline text via `underline` widget property
- map, memoize and zipWith list transformations
- changed default screenshot format to `.png`. Removed deprecated `[interface] capture_to_jpeg`. You can still change screenshot format via `[interface]  screenshot_format` setting
- added the `passwordSmartphone` attribute to `input`component

## Some (NDSK 1.10.0)
- `onWheel` event handler on visual objects:
  - wheel event contains delta, deltaX, deltaY, deltaZ properties
  - for example deltaY containts the actual scroll amount which is calculated by `delta * scrollLineHeight * wheelScrollLines`
  - `scrollLineHeight` is a window property
  - `wheelScrollLines` default value is 3. On windows it is configurable with `Choose how many lines to scroll each time` setting.
- wheel widget can scroll with wheel events
- xscript: negate operator (!) used to keep failure. Now it will result in true but yield an error if it is not marked.
- await ignores synchronous failures on its right side letting the left side to handle the resulting failure. So no more need to write `?? await (?? mayFailSynchronosly)`. Nothing changes in case of rejected promises (async fails)
- Added `getOrDefault` and `getOrElse` to module `system://core` to facilitate failure handling. Both return the original value if it is not a failure. On failure `getOrDefault` returns its second argument while `getOrElse` invoces its second argument and returns its result.


Migration of ! operators constructs:
- `!maybeFail ?? true` should be written as `!??maybeFail`. Note: negation has higher precedence than `??` operator.
- `!maybeFail ?? false` should be written as `!??(maybeFail??true)` unless it is important to keep the true value on undef
- use `!getOrDefault(??maybeFail, true)` in case it is important that undef results in true ( instead of `!maybeFail ?? false`)

Examples
```javascript
// no extra ?? is needed in case it is already marked as handled
let res = ?? maybeFail;
if (!res) { /* failure or other falsy value*/
}
```

Example with getOrElse
```javascript
import {getOrElse} from "system://core"

registerAtPath(){
  getOrElse(??nng.map.MapWindowHelper, () => System.registerAtPath( "nng.map.MapWindowHelper", MapWindowHelper ));
}
```

## Medusa (NSDK 1.10.0)

### Added
- Kolin/Java binding. Import kotlin modules via `android://moduleName` syntax. InterfaceMapping.xs supports `android://` scheme
- Heca: `system://childProcess` module support stdin,out and err to be piped. Pipe reading interface
- Added `substr`, `substring`, `subarray`, `copyWithin`, `set`, `fill` and `reverse` to `TypedArray`s. Specialized `slice`, `indexOf`, `includes` and `lastIndexOf`.
- Added `observeValue` and `onChange` to `system://core.observe` module to support value observation with proper subscription. onChange will only trigger after the value changes while observeValue will trigger with each value including the initial value (see `some.xsbook` )
- Added `Iter.iterable(func,...args)` that wraps a function returning an iterable into an iterator. Can be used to wrap Iter functions into repeatable iterable. So
```js
const filtered = Iter.iterable(Iter.filter(?));
onlyEven(seq) {
  return filtered(seq, v => v%2 == 0);
}
f() {
  const e = onlyEven([10,3, 50, 8]); // can be iterated as many times it is needed
  ...e,...e;
}
```


## (NSDK 1.8.x)
### Added
- DBus support in the engine: `dbus/dbus.xs`. Making connections, registering objects, calling remote proxy objects.
- Key events provide meta key state in `altKey`, `ctrKey`, `metaKey` and `shiftKey` members. `repeat` property is set to true
 when the keydown event is repeated.
- Contents of the system clipboard may be read and written in textual from with the help of `system://clipboard` module  
- Added `object {}`, prototype based object for xscript
- classes and object {} can have static init block (static {}) to initialize class or object
- added xml reader and xmlNode (system://web.xml and core/web/xml.xs

## Hecatoncheires (NSDK 1.x.x)
### Added
- string.charCodeAt or string.codePointAt returns the character code at position (decodes utf8)
- added ENV object to get environment variables. ENV object is default exported by `system://app.env` module
- added getString and setString to DataView
- added {readTextFile,readTextFileSync} to system://fs module
- support playback of mjpeg streams via httpSprite component
- console.dir and console.log can be used as tagged template literal (e.g. console.log`message ${myArray}`)
- module data can be decorated with `@dispose` causing it to be called at the time of onUnload (custom function is not accepted)
- XsBook support
- widget property `touchEvents=@box` allows it to be clicked in the area specified by width and height
- Symbol(), Symbol(desc) support.
  - symbols are unique value and can be used for this purpose (e.g proxy.NoProperty or X._ placeholder)
  - use `symbol.description` to get the original description, stringified by `"" + symbol`.
  - properties can be symbols (like Symbol.iterator), can be added to state,dict, odict, event, controller, class, own block
  - ui widget allows arbitrary symbol to be stored and observed
  - computed property syntax not yet supported (besides dict literal).
  - symbol properties are not enumerable (neither Symbol iterator)
- argot
  - IFW more forgiving on the number of retvals (e.g. it is not an error to return something from a void function)
  - Optional retval in argot (`func(): T?`), 
    - xs can return nothing (retunr; or void(); ) or in most cases `undef` is sufficient (except in case of any)
    - C++ optional retval is converted to undef in Xs or to no retval in case of any
  - structs also accepts undef instead of not existing property (except in case of any)
  - length property to readonly list, list argot harmonizd
  - argot for Map
- Itertools
  - min,max,minBy,maxBy, toTuple, zipWith, zipLongestWith, includes, any, all, unique, nth, last
  - toTuple
  - append,prepend, intersperse, enumerate
  - zipLongest and zipLongestWith accepts {fill: value}
  - mreduce multiarg reduce
- functional/Xscript
  - pipeline operator |>
  - tap(func) - passes args to `func` when called but returns the original args, usefull to log a pipeline
  - converge(convFunc, ...funcs), juxt(...funcs) - dispatchign argument to multipe functions and passes to convFunc or returns
  - constant(...args) - a function when invoked returns the original arg (e.g. functin with fixed return value) (alias is always)
  - thunk(f, ...args), thunkify(f) - creates a thunk from f, when returned function is called it will the function `f` with the original args, can be used for deferred calls. thunikify created a curried version of this. The thunk is only created once all args are provided
  - pipe,compose,juxt,converge passes this around so can be used to compose methods
  - void(...args) - does nothing and returns nothing can be used to evaluate args for its side effects or to enforce return nothing from a function
  - objOf to create an object with a single property (e.g iterator, toString)
  - id function (in core moudle)
  - string.eq, string.cmp (core)
  - ident builtin (core)
- typchecking
  - @ifwType decorator to hint for derived
  - observation proxy
- XTest

  - Any function may be turned into and executed as a testcase, using the `test(name, func)` function from testRunner module

### Changed
- fixed breakpoint handling in case step is requested but there is a breakpoint in the function stepped over
- dict literal properly parses numeric keys and accepts quotes around strings
- modules can contains cosnt values not only objects (export const Pi = Math.PI)
- XTest: updated the implementation of `unorderedElementsAre` matcher, using a Maximum bipartite matching algorithm, and honoring matcher arguments passed as expectations

## 2021.04.31 - Harpy (NSDK Release 1.0.3)
### Added
- proxy object support similar to javascript. See Module `system://core.proxy`.
- JS like Reflect tools support via module `system://core.reflect`
- const defintions in xs modules alllow arbitrary values. E.g `const name=42;` or `expost const myTuple="alma",42;` 
- `findLast` and `findLastIndex` for sequence objects to find sequence item backwards choosen by predicate functions (simialar to `find` and `findIndex`). See doc for more info
- `string()` conversion function added to core module. failures are returned as is (e.g. `string(f??a) == string(f) ?? string(a))
- added identity function to core module. It is more or less `id(...args) { ...args}` without the temporary array
- `apply(func, iterableOfArgs)` to functional module, can be curried: e.g. `apply(func)(argArray)` (`apply(func,args)` == `func(...args)` but can be curried and can be more effective)
- `applyMethod(obj, method, args)` or `applyMethod(method, obj, args)` calls method or callable property of an object with args from array
- `method(methodName, objOrValue, ...args)` calls method or callable property. It is autocurried, so
```js
import {method} from "system://functional"
let startsWith = method(@startsWith);
startsWith("alma", "al"); // true
startsWith("alma", "ma"); // false
```
- `Promise.lift(func)` created a function that can be called with promises/thenables and resolves all argument and will pass the result to func
```js
let asyncLog = Promise.lift(console.log(?)); 
asyncLog(Promise.resolve(42),2); // prints 42,2
console.log(Promise.resolve(42),2); // prints: Promise { [state]:fulfilled, [value]:42 }, 2
```
- Itertools 
  - toArray, find, forEach, inspect (calls function with eatch item but doesn't change iteration)
  - take, drop, stepBy shorthand for slice
  - alternate can be used as postfix

- @metadata decorator for TestSuite. Metadata fields are {description, owner, feature, level, type}. See [nsdk-meta.xs](./xs_modules/xs_tests/nsdk-meta.xs) for predefined values.
- @timeout decorator for TestSuites and TestCases. Possible values are defined in [nsdk-meta.xs](./xs_modules/xs_tests/nsdk-meta.xs).

### Changed
- fixed state controller switching state removing not only the top state but the one before the top also
- fixed a heap corruption that could occur if a property's onchange invoked during the build of own block and script vivified another property
- JSON `parse()` function accepts BufferObject as well

## 2021.03.31 - Cerberus (NSDK Release 1.0.1)
### Added
- templateType function of listView and lister is invoked with a ctx parameter that can be used instead of `item` and `index` special name (ctx.item is the same as item). This should ease passing parameter around.
- template and fragment head can be any widget (fragment and template is an alias for group)
- for better clarity template's and fragment can be written in front of the widget type
```xml
<template:button tItem>
   <text text=(item.name)>
</template:button> // can be shortened to </template>
```
- fragments and templates can extend another. own blocks are combined to single onwl block, children respect includeChildren in bases. 
- component can also extend each other
- Effective css classes of a wiget are combination of effective class values calculated from all of deerived and base fras well as base and derived components

### Changed
- listView's and lister's templateType function runs in its original context (name resolution) with added `item` and `index` special names
- <includeChildren> work through multiple nesting. E.g. when a component instance is embedded in another component, that instance will properly get children imported via includeChildren in the instance definition
- duplicated properties in own {} block are checked during parse time
- widget's class property accepts not only tuples but tuple of tuples

## 2021.02.25 - Cyclops (NSDK Release 1.0.1)

### Added
- `@declare` blocks in NSS stylesheets. In `@declare` blocks you can introduce 
declarative parameters, with the same syntax as in `@params` block. 
  > **Note:** Declarative parameters cascade differently, than params. Always the last definitions wins out, and this does not depend on the point of usage.
- Style blocks can be composed into a tree hierarchy, to facilitate better cascading order. 
All style blocks got the `add(subSheet)` and `insert(subSheet [, where])` methods to add new subSheets to them. 
Also with the `unlink()` method you can remove a style block from its parent.
- Create window paramater's `styles` property can be a custom style block. If given it's subSheets and styles are used instead of the global one
- `run` subcommand to ui_runner (now called uie). You can launch more easily applications using it: `uie run [options] <application> [app-options]`. For more details see [ui runner documentation](../applications/ui_runner/app_ui_runner/README.md)
  
### Changed
- `@params` block in NSS stylesheet are deprecated. Currently a parse warning will be emitted about it, but soon they will behave just as declarative parameters introduced in `@declare` blocks
- Style blocks see all symbols from the enclosing module's scope. No need to chain them through `@params` blocks
- Multi-Directional layouts can be built more easily via the help of the *direction* property on widgets, window and screen. When *direction* is set to `rtl`(right to left) and the *r2lInvert* property is set to true, paddings and alignments will be inverted, as well as element ordering in horizontal flexible boxes.   
- A new value is added to the set of possible values of *direction*: `window`. This can be used to switch back from a preset direction (like `ltr`) to the main direction of the window.
- ui_runner executable renamed to uie, for easier and more consistent command line usage 

### Removed
- Directionality of widgets is no longer influenced by the currently set UI language (gIsR2l). Set the *direction* property on your applications window, based on the UI language to achieve the same effect.

### Known issues
-  style {} blocks is not supported by the reload CSS development helper utilitiy

## 2021.2.1 - Minotaur (NSDK Release 1.0.0)

### Added
- `using` directive support in XScript
- hook registrator is disposable
- tuple constructor to help creating tuple (tuple.of or tuple.from)
- can call a few string methods on identifiers as well (e.g. `let name = @test_alma; name.substr(5))
- can decorate functions in uiml tree (written in text content but not yet on attribute syntax e.g. `<group>@decor onRelease() {}</group>`)
- added XTest matchers: isErrorWithMsg, hasSubstr, matchesRegexp

### Changed 
- whenever gcoor is accepted (builtin.distance) an object with {latitude,longitude}  properties or {lat,lon} for short are accepted
- Event hook no longer checks and prohibits the same function to be registered multiple times
- Click events on disabled widgets bubble up the dom tree, just as click events on non disabled targets. Click handlers on the widgets won't be invoked, only handlers installed via the `addEventListener` method. In your handler (installed on the window for ex.) you can decide what action to take, when `event.target.enable` is false. For example usage see: [disabledClickSamples.xs](./xs_modules/uie/samples/disbledClickSamples.xs)


### Removed
- Removeed obsolete builtin functions from builtin module: .convert_unit, defined, Array, Dict, odict, tuple, substr
  For creating tuple, array, dict or odict you can either use `(,)`, `[]`,`{}` or `odict {}` xscript syntax or call the appropriate constructor. substr is a method of string values. Use hasProp or `??` operator instead of defided or the function from core module.

## 2020.11.04

### Added
- `@tags(t1, t2, ...)` decorator to xtest. Use it to tag test suites or test cases. It will concatenate the new tags with the existing tags. Consider using this method instead changing the tags and caseTags static properties
```js
import {TestSuite, @registerSuite, EXPECT, @tags} from "xtest.xs"

@registerSuite @tags(@cool, @tag2)
class MyTests extends TestSuite {
    @tags(@important)
    test_superTest() {
      
    }
}
```

## 2020.10.28

### Removed
- model interfaces from widgets (dTooltip, fonts/render_quality, textW, history)
- chart widget
- smartscroll widget
- button widget
- obsolete ui settings
- sprite providers

## 2020.10.26

### Added
- JS like optional chaining via `?.` operator (e.g. `obj?.prop`, `obj?.[expr]`, `func?.()`)
- two-way binding can be places in data objects and classes defined in xscript functions
- two-way binding with non-object path can ommit the function keyword (syntax: `prop <=> {block}, (newval) {updateBlock}` )
- mixins and enum in xscript functions

### Removed

### Changed
- a null weak ref is undefined
- `:=` is supported an the preferred way to make bindings instead of using `()`. However, for uiml attributes the usage of `{}` block form is mandatory (e.g `attr := {`...`}`)


## 2020.10.07

### Added
- `listView.scrollToItem()` - to scroll to an item
- `@register` decorators run on widgets after its subtree has been built 
- `widget.querySelector(nssSelector)` and `querySelectorAll(selector)` can be used to get descendants (or the widget itself) that matches the given nss selecotr (e.g "template.vertical"). `querySelector` returns the first match in depth-first order and `querySelectorAll` return all matches by multiple retval (put square brackets around the call to get an array)
- Added ChangeObserver that observe changes of given objects and calls the associated change function. observables can be added on demand. `observe` should be used to observe the value of a given expression. ChangeObserver can be used to observe any properties of objects. Usage
  - `obs = new ChangeObserver(changeFunc, ...observeSpec);`
  - `obs = ChangeObserver(changeFuncm ...observeSpec);` same as above but with function call syntax instead of new
  - `obs.observe(obj)` will also observe any property change on `obj` (if supported)
  - `obs.observe(obj.prop)` will observe `prop` of `obj` 
  - `obs.unobserve(...observeSpec)` stops observing the objects or properties given by observeSpec
  -  data object syntax can be used to create a ChangeObserver with using the initializer for `onChange` and `observe` (it can be used only for initialization)
```js
ChangeObserver obs {
  onChange(change) { /* change function body. The ChangeObserver passed as `this` */  }
  observe = observeSpecTuple;
}
```
- ChangeObserver passes the list of changes to the onChange function

  ChangeObserver 
### Changed
- Gradient can be given in data form e.g. `img = LinearGradient [ 90deg, #ffffffff, #000000ff]` so don't have place it into binding or write `new LinearGradient..`

## 2020.09.23

### Added
- Object's toString method is called to get its string representation in certain cases. Such is when setting the `text` property of _text_ widgets and handling format parameters. This can be used to do deferred text processing such as translation (e.g. text is only translated or formatted at the place of usage) e.g. can wrap a text into an object forcing it to be translated when assigning it to the `text` property
- The `system://i18n` module contains a translate function that can be used to translate a text on demand
- The `%I` format specified in `format` and `sprintf` will translate a string parameter (only if it is a string)
- Example 
```js
import {translate} from "system://i18n"
class Stringify
{
	toString = undef;
}
deferredTranslate(s) {
	return Stringify { toString() {translate(s) } }
}
i18n(strs, firstItem) {
	deferredTranslate(strs[0]);
}
odict d { text=i18n`translate this` } // will translate on demand
<text text=1i8n`Find my POI`/>
```
- listView got sevaral helpers to show an item and query view stats. All offsets are relative to the viewport ususally measured in pixels but its exact interpretation depends layouter (for example wheel layout uses it as rotation angle after dividing it by viewSize)
    * `firstItem` and `firstItemOffset` cna be used to save actual view state (se listView doc)
    * `showItem(itemIndex, viewOffset)` method can be used the show an item at a given pos or restore view based previously saved by firstItem and firstItemOffset
    * `getItemTrackPos(itemIndex)` and `getItemViewOffset(itemIndex)` to get position of a rendered item


### Removed
- Removed wstring from object system. The `L"str"` syntax is still accepted but it will produce a simple string.
- Automatic text translation based on string types are removed
- `powerlessness` property removed from`<wheel>` widget. Use the `deceleration` property instead. The default for deceleration is `@normal`, which corresponds to the powerlessness value used to this point by most projects. Probably no action is required besides removing `powerlessness` usage

### Changed
- Builtin sprintf and format does the same except `format` will translate the format string if it is a string (stringified objects are not). See `test_formatTranslates`
- Fixed unnamed data object can be returned without explicit `return`. Named data objects still require explicit return
- list and array types can be imported from `system://core` and can be used to construct data objects

## 20.5.0 - 2020-09-09

### Added
- New theme manager xscript module: [Theme manager](https://bitbucket.nng.com/projects/UE/repos/uie-docs/browse/guides/uie_modules/theme_manager.md)
- Missing resources (like `.svg` and `.png` files) will be reported in the debug console (new `NNG debugger` vscode extension is needed)
- Can use alias type names for dict and odict data objects ( e.g. `let myd = Uiml.dict; let d = myd {a=1}` )
- `@registerSuiteIf(cond)` helps conditional suite registration

### Changed
- wheel widget used transition logic internally for changing the value
- wheel widget's `value` proeprty can be transitioned

### Removed
- Theme manager related (see: [Theme manager migration guide](https://bitbucket.nng.com/projects/UE/repos/uie-docs/browse/migration_guides/theme_manager_migration_guide.md)):
  - Old theme manager interface (based on model system)
  - Skin-config support
- wheel widget doesn't support fixing methods and fixed values.
- `maxSpeedAfterRelease` property deprecated in wheel widget. Scrolling is more natural, if release speed isn't capped.

## 20.4.2 - 2020-08-26

### Added
- `@customProps` decorator applied to a class definition allows its instances to have arbitrary properties besides the declared ones. Properties are observable and created as usual in the same way as for an odict.
- onChange and setter for real class properties (a property not defined by a getter). Use `onChange prop(newVal, oldVal, isSetProp )` after property definition (e.g. `prop=initExp;` or `prop=(binding)`) to define onChange script for prop. Setter can be also defined for real properties. <br> onChange is invoked even if the property is changed from binding after it has been set. While setter only if set via set property. You can combine setter and onChange for properties.
- classes can be defined in XScript functions and local variables are properly accessible. Also other `data {}` syntax can be used like `odict { a=5};`
- within data objects defined in XScript use `prop:=expr` to define bindings instead of `prop=(...)` syntax. Parsing of the right side of `:=` follows the rules of arrow functions. Namely simple expressions doesn't have to be bracketed. In case of more complex bindings, curly braces should be used to enclose the body of the binding (e.g. `prop:={let a=...}`)
- `prop:=expr` syntax can be used in uiml data objects as well. NSS also supports this syntax.
- `calcDpValue(lengthSpec,widget,parentSize)` from `system://ui.units` can be used to calculate `dp` value from length spec (can use units such as `px`, `cm`, `dp`). If percent or `p` units are used the appropriate proportion of parentSize is added. It returns the sum of length converted to `dp` using the metrics of the window associated with the given `widget`. When `fr` units are used the `fr` value is returned as the second return value

### Changed
- added `trackStart` method and `dependsOnLayoutProperty` property to list layouter. listView will occasionally invoke the `trackStart` method to get the start index of the track before the item index given by the first parameter. <br> listView will invalidate a cell on layout property change, if the layouter has `dependsOnLayoutProperty` property with a true value.
- `alignSelf` and `justifySelf` properties are layout params that can be used by layouters.

## 20.4.1 - 2020-07-21

### Added
- A subset of object system leaks can be detected (when instances of classes are leaked). To enable and set up the feature, use the following command line flags
  - **--leakcheck-objsys** to enable checking
  - **--leakcheck-backtrace-size \<val\>** to set backtrace size (default 0, max 8)      
When leaks are detected, the results will be printed in `leaks_objsys_<current_date_time>.txt` in the current working directory
- `onBeforeRelease` event handler to components:
  - like its name suggests, the script will run at the target phase, before the onRelease handler. You may stop event propagation at this point
  - this property may only used on components, geared towards writing default release handlers (for setting internal state, like checked, selected etc.)
  - if you write an onBeforeRelease handler, the componenet instances will become mouse targets. No need to add an empty onClick handler
- Added "ifw://..." module scheme that can be mapped to system or xs files via InterfaceMapping.xs
- Type {} can build any object of Type if Type name is in scope (imported via module) and supports construction
- Transform type from `system://list.transforms` can be used to create a list transform host as a replacemennt of  import part of `<listModel><import></listModel>`.
  * list concatenation can be declarativelly created by `const lm = listTrans.concat(l1,l2, ...)`
```javascript
import {from as ListFrom, concat as ListConcat, Transform as ListTransform} from "system://list.transforms"
export const lmPart1 = ListFrom(colorList).build();
ListTransform lm2 { model= (FilterData.list); filter=( FilterData.f1, FilterData.f2 ) }
export const lm = ListConcat(lm1, lm2);
```

### Removed
- All data builder using the <data> syntax
- global unnamed and autostarted observers are not supported (named global observers are not started unless `@preload`)
- Building layers from dependent layers
- global object cannot be used to invoke screen methods
- `<listModel>` removed, used Transfrom from `system://list.transforms`
- global state are never automatically acitvated. This task is always left to onStart scripts
- state ancestor must be a state and won't resolve identifiers when building (e.g extends="alma", @korte are not valid)

### Deprecated
- `<own>` block is deprecated, use `own {}`

### Fixed
- fixed a crash in getsture recognizer when recognizer target has been destroyed
- fixed a leak in enum objects

## 20.2.3 - 2020-07-10

### Changed
- VS Code Inspector are using fragment instead of debug layer 
- Replace xhtml layer with low cost xhtml widget

### Removed
- Delete global State queue
- Remove rolling engine from smartscroll widget and remove direct setup in wheel widget
- Delete UI layers
- Delete circular scrolling

## 20.2.3 - 2020-06-03

### Added
- Decorators accepted on Module level const declarations (e.g `@register(..) const alma=..;`)
- Added WeakMap to `system://core.types` that can map from object to values without keeping ownership of object keys. Will delete entries when object is deleted
- Data declaration accepts initial list of items if its type supports creatign instance via the `from` method (e.g OrderedMultiSet)
```js
const NameList = new OrderedMultiSet((l,r) => {l.name <=> r.name});
NameList nameData [{name: "banana", color: "yellow"}];
```
- Added `@bindToListVia` decorator and replaceSortedList to `listUtisl/listChanges.xs` to ease keeping a sorted copy of a list
```js
@bindToListVia(contacts, replaceSortedList)
const contactByName = NameList.from(contacts);
```

### Changed
- OrderedMap and Set rejects inserting item when comparator returns a failure
- `Map` can be created from object properties. It will consist of its key, values if passed to Map.from()

### Fixed
- Improved JSON stringify. It was incorrect for some tuples and map objects

## 20.2.3 - 2020-05-20
### Added

- Added iter methods to `system://itertools`
  - `alternate(...iterables)`  to alternate between multiple iterators (wave iterators together)
  - `flatMap(func, iterable)` or `flatMap(iterable, func)` to expand the result of map result
  - `reverse(sequence)` reverse iterator over an indexable sequence (will get propertys length -1, ... 2,1,0)
- Added Set and more Map object into `system:://core.types`
  - Set types only stores ordered values. 
  - MulitMap, MultiSet allows repeating keys
  - OderedMap, OrderedMultiMap, OrdederedSet and OrderedMultiSet allows creating a new ordered container with a used given comparator function. The resulting type can be used to construct container instances (e.g. `OrderedMultiSet(cmp).from(iterable)`)
  - Sets provides an observable list interface as well (items are ordered)
  - All container supports `lowerBound`, `upperBound`, `clear`, `has`, `removeAt`, `removeRange`.
  - Unique container supports `get`, `getIndex`, `remove`
  - Set `add`, map: `insert`
  - MultiSet, MultiMap: `insertAt`, `equalRange`, `getAll`, `removeAll`
  - Unique set methods `add`, `get`, `getIndex` .
  
### Changed

- map object's view are observeable much like a list
- map object's value access by key is observable (`map[key]`, `map.get(key)` and `map.has(key)`)
- Partial application creates a function that is always called even if called with less parameters than required e.g.
   `obj.method(?)()` will call `obj.method()`

## 20.2.2 - 2020-05-12
### Added
- `w` and `h` property of widgets support `@auto`. Auto width(`w`) be useful if width should be measured but both `left` and `right` might be set and it should not override width.
- Supports widget position transition if transition involved different combination of left, w, right. This is to better support slide in and slide out transitions.
- `translateX`, `translateY` besides `translateZ` widget proeperties can be used to offset widget property relative to current position. The x, y properties accepts percentage values and it is relative to the node itself (not to its parent). So setting left to 50% and translateX to 50% will place the widget horizontally in the center of its parent. There is shorthand property called `translate` taking a 2 or 3 element tuple.
- `debug.reloadCss()`. Use it to reload all styles in your application
- Better error messages in ui_runner app, when the project is misconfigured. Show errors when:
  - project config can't be found
  - application directory (skin_folder) can't be found
- Visual test cases can be described with `async` methods. You can use `await` for `visualCheck()`s

### Changed
- Options for `visualCheck()` should be specified in a dictionary like argument, instead of the named method pattern earlier. Option names are normalized: `colorTolerance`, `badPixels`, `method` and `displays`. If you want to check the contents of all windows, use the special `@all` value for displays.

  Example:
  ```js
  // old:
  Async.visualCheck().bad_pixels(4).color_tolerance(25).displays()
  // now
  Async.visualCheck({ badPixels: 4, colorTolerance:25, displays: @all})
  ```

### Deprecated
- Contents of `xs_modules` won't be accessible from app root (mostly the working directory). This means that you shouldn't store resources (data files, images etc.) together with your script modules. 

  The engine won't be able to load them in the future!

  For example: `.nmea` files for tests, and `.svg` files for samples

### Removed
- Obsolete import specifications, like `import "all:<path>"` and `import "~res/<path>`. Only `~/` is kept as a special prefix, denoting the current application (skin) directory

### Fixed
- `transition` property parsing fixed so it supports sequence of sequence combinations (e.g array or arrays, tuples of arrays).
- Resolving filenames from import statements works reliably in development layout, from distributions using `data.zip` or simply deploying files beside `ui_runner.exe`

## 20.2.1 - 2020-03-31
### Added
- Can add styles to window via NSS (e.g. `window {}`). The option parameters of createWindow can contain `id` and `class` properties that will be set on window object. 
The preferred way of setting common text props is to set it on window and let it be inherited
- `fontSize` supports parent relative font size via `em` or percentage. Unit `rem` is proprtion of 16dp, later might be window dependant.
- Fragments marked as permanent will not be hidden by state controllers.
- State conroller can delegate state animation to a transition controller object. Various methods of transition controller's is called on state change. The methods can be asynchronous and can be used to postpone some effects
  * `deactive(ctrl)` method is called before the last active state's is deactivated. It is awaited before state done is called. Can be used to perform hide transition of the current fragments (e.g. slide out). Symbol `transitionState` is set to `hidden`
  * `hide(ctrl, fragmentsToHide)` method is called before former fragments are hidden and removed. Can be used to implement crossfase animation by delaying the hide of former fragments.
  * `show(ctrl)` method is called after new fragments are created. Its behaviour is not yet decided
- Added `allChildAnimFinished` to the new `uie/naimation/finish.xs` module to help awaiting to the finish of animations. It returns a promise that is resolved
when there are no more running animation or transition of any of child widget of the given parameter. It is well suited to be used in state change transitions.
- `System.import` function accepts an error collector object argument to collect any parse error during import (even if error happened in the imported module)
- `System.errorCollector()` function creates an error collector that can be passed to `import`. Use `hasError`, `errorInfo` or `message` properties to access details (`errorInfo` provides access to the location info embedded in message)
 ```javascript
 let collector = System.errorCollector();
 if (let m = ?? System.import("someFile.xs", collector)) 
    console.log("loaded", m);
 console.log(collector.hasError, collector.errorInfo);
 ```
 * Added `LinearGradient` and `RadialGradient` to `system://ui.gradient`. Both follow the notation of the css standard gradient (e.g. https://developer.mozilla.org/en-US/docs/Web/CSS/linear-gradient).

### Changed
- `removeEventListener` on a widget retunrs undef to help cleanup of stored handles. In order to ease usage it will not report error if called with undef or released weak ref so result of `addEventListener` can be stored as weak ref. This is to help the following common pattern.
```javascript
handler = weak(obj.addEventListener(evt, () => { ...; obj.removeEventListener(evt, handler);}));
// or later
obj.removeEventListener(evt, handler);
```
* Changed gradient notation to match the standard descriptor.
```javascript
import { LinearGradient }  from "system://ui.gradient"
...
/* Migration of gradients: start and end points defaults to 0% and 100%, hence they are not need to be set. "Position, color" style stops switched to "color, {position}, {length}" enumeration.
*/
img=(@vertical,0.0,0xff00ff00,0.75,0xffffffff,0.75,0xffffffff,1.0,0xff0000ff)
img=(LinearGradient(0deg,0xff00ff00,0xffffffff,75%,0xffffffff,75%,0xff0000ff))
  
img=(@horizontal,0.0,0x5500ff00,0.75,0xccffffff,0.75,0xccffffff,1.0,0x880000ff)
img=(LinearGradient(90deg,0x5500ff00,0xccffffff,75%,0xccffffff,75%,0x880000ff))
```
### Fixed
- `Chrono.passTime(delay)` accept unit value, default unit is milliseconds. In can be used instead of `incrementTime()` to pass time when timemachine is paused. 
- text prop inheritance might have not worked in some cases

## 20.1.4 - 2020-03-11
### Added
- `Chrono.delay` returns a promise that is resolved after the given delay (similar to Async.delay in test environment).
  ```javascript
  await Chrono.delay(100);
  console.log("After 100ms delay");
  ```
- Focus wheel simulation with mouse wheel. Hold `shift` key pressed, while rolling the mouse wheel, which in turn will synthetize special wheelUp(`0x3a`) and wheelDown(`0x3b`) key events
- Focus group and traverse strategy objects can be enumerated (expanded from the Debugger)
- `uie/appState.xs` module. It provides functionality for initializing the *hot reload* feature (`initReload`) and persisting application state between reloads (`appState` odict).
- `system://childProcess` module. Use the `spawn(path, ...args)` method to spawn new processes. The resulting childProcess object can be terminated with the `kill()` method. Also you can subscribe to the close event, via the `onClose` event hook.


### Changed
- Renamed properties and methods in focus system to adhere to the camelCase naming convention (from `<token_name>` to `<tokenName>`). Examples: focusedObject, traverseStrategy, initialSearch, rowChangeAllowed, cyclicHorizontal, cyclicVertical, wideSweepHorizontal, currentId, nextGroup, prevGroup, selectGroup 
- Focus reinitialization takes into account the `trapFocus` property of the current focus group. If `trapFocus` is set, then focusing objects from other groups is only allowed when the current group contains no focusable elements.
If a focusable element appears in the original focus group while `reinitTimeout` is active, then it will be selected.
- The `measure` method on widgets takes into account the desired extents specified on the widget
- Flex layout will treat maximum size constraints as container size in the future. Child widgets won't be srtrictly resized when their inherent size is greater than the container size. Currently desired extents greater than container size won't be descreased, but left as is.
- Renamed `on_connection_event` to `onNetworkChanged` in `system://remoting` module. When triggered it will be passed an action code (`@connected` or `@disconnected`) together with the affected peer object

### Removed
- Removed `nbt_remoting` object from global namespace, use the `system://remoting` module instead

### Fixed
- Setting `boxAlign` to `@stretch` behaves well, when parent widget's extent on cross axis is unknown

## 20.1.3 - 2020-02-26
### Added
- Fragments can be embedded in data objects
- new expressions in own {} block (e.g. `let alma=new Type(....)`)
- New gesture recognizer interface (see: [Gesture recognizers](https://confluence.nng.com/display/FEDP/Gesture+Recognizer))
    - `recognizers=(recogObj, ...)` property instead of the procedural `addGestureRecognizer`
    - `on<Gesture>` event handlers (like onPan, onPinch) instead of the procedural `addEventListener`
- `settings` object to focus interface. Settings include reinitialization, reinitialization timeout and whether disabled elements may be focused
- `findFirstFocusable` and `findNextFocusable` methods added to traverse strategies. They behave just like `findFirst` and `findNext`, but only operate on focusable elements 
- `uie/focus.xs` module, it includes the `FocusHandler` class to aid hadling focus inside listViews
### Changed
- `tween_to`, `tween_from` renamed to `tweenTo`, `tweenFrom` in Animations module
- Focus system no longer marks focused objects with the *defaultFocusImportant* flag. Use the `selected` property, to achieve a similar effect

### Removed
- `set_reinit_timeout` and `set_last_focused` methods from focus interface



## 20.1.2 - 2020-02-12
### Added
- New own block syntax: `own {}`.
- Enumerators for event objects. Event objects may be expanded while debugging.
### Changed
- `onRelease` and `onClick` event handlers will run only in target phase (previously they ran also in bubbling phase)
- Sped up calculations and rendering for listviews using templates with `flex` layout
### Fixed
- Borders appear correctly, even when perspective/3D transforations are applied.
- Crashfix when animating properties of an object, which gets destroyed at the end of animation

## 20.1.1 - 2020-01-29
### Added
- Scalable main and additional windows. Use the following config: `[rawdisplay] scale = 0.5`.
- New features in inspector: raise window, go to file, improved picking and debug context.
- Margin support inside flex boxes (marginLeft, marginTop, marginRight, marginBottom).
### Changed
- Updated makedist script to support deploying files besides the data.zip.
