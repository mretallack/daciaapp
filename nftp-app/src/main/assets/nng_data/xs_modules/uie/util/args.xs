import { hasProp, typeof, failure } from "system://core"
import { Map } from "system://core.types"
import { seq } from "system://itertools"

export enum NArgsType {
    /// Flag
    Zero = 0,
    /// Normal option
    One = 1,
    /// Option with multiple values
    Multiple = 2,
}

export default class ArgParser {
    #options;
    #defaults = [];
    
    constructor() {
        this.#options = new Map();
    }

    version() {
        return "2021.04.01";
    }
    
    /// flags are boolean options, they never take arguments (do not consume more items from the command line)
    /// the name of the flag will be inferred from the flag specified. If the long version is specified, it will be used
    /// otherwise the short version. In both cases the preceding `-` marks will be removed. 
    ///
    /// @param flag the short/long name of the flag, or an array/tuple of alternatives.
    ///      for ex. "-h", or "--help" or both: ["-h", "--help"]
    /// calls of this method can be chained with other addFlag or addOption calls
    addFlag(flag, default = false) {
        this.addArgument(flag, 0, default);
    }
    
    /// Option. One argument is consumed from command line.
    addOption(option, default = undef) {
        this.addArgument(option, 1, default);
    }

    /// Option with multiple values. 
    /// It returns with an array of values, even only one value defined.
    addOptionAppend(option, default = undef) {
        this.addArgument(option, 2, default);
    }

    /// Universal method for adding new argument to ArgParser.
    ///
    /// @param option {string}/{array} The short/long name of the flag, or an array/tuple of alternatives.
    /// @param nargs {int} Number of arguments consumed. (Use NArgsType) Zero, One, or Multiple
    /// @param default Optional value used when it is not defined from commandline
    addArgument(option, nargs, default = undef) {
        const descriptor = {
            nargs,   // currently 0 or 1, 2=>array
            default,
            name: undef
        };
        for (const opt in seq(option)) {
            // todo: add options without -/--
            if (typeof(opt) != @string || !opt.startsWith('-')) {
                console.error(`Invalid ${nargs ? "option" : "flag"} name: ${opt}`);
                continue
            }
            if (!this.#options.has(opt)) {
                const longName = opt.startsWith('--');
                const optName = opt.substr(longName ? 2 : 1);
                if (longName || descriptor.name == undef) {
                    descriptor.name = optName;
                }
                this.#options.set(optName, descriptor);
            } else {
                console.error(`Duplicate definition for ${nargs ? "option" : "flag"} "${opt}"`)
            }
        }
        
        if (descriptor.name                                             // means: successfully added descriptor
                && descriptor.default != undef && (descriptor.nargs > 0 || descriptor.default != false)) {  // has a valid default
            this.#defaults.push(descriptor);
        }
        return this
    }

    #processShortOpt(args, i, result) {
        const arg = args[i].substr(1);
        for (let idx = 0; idx < arg.length; ++idx) {
            let opt = arg[idx];
            const descriptor = this.#options.get(opt) ?? undef;
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

    #processLongOpt(args, i, result) {
        let arg = args[i].substr(2);
        let optVal = undef;
        const eqIdx = args[i].indexOf("=");
        if (eqIdx > 0) {
            arg = args[i].substr(2, eqIdx -2);
            optVal = args[i].substr(eqIdx + 1);
        }
        const descriptor = this.#options.get(arg) ?? undef;
        if (descriptor) { // option
            let val = descriptor.nargs == 0 ? true : descriptor.default; // flags will be set to true when present
            if (descriptor.nargs > 0) {
                val = optVal ?? args[++i] ?? descriptor.default; 
            }
            if (val == undef && descriptor.nargs)
                return failure({message: `No value provided for ${arg} option`});
            if (descriptor.nargs == 2) {
                if (result.options?.[descriptor.name] == undef)
                    result.options[descriptor.name] = [];
                result.options[descriptor.name].push(val);
            } else {
                result.options[descriptor.name] = val;
            }
        } else { // positional arg or unknown option
            if (arg.startsWith("-")) {
                return failure({message: `Unknown option: ${arg}`});
            }
            
        }
        return i;
    }

    /**
    * Parse the given argument list
    * @param args arguments array, in unix standard commandline format. 0th argument is the program name
    * @param parseOptions an optional object containing any of the following options
    *   * shouldStop - a function which will be called with the argsand current results
    * @returns an object containing the parsed options and positional arguments:
    *   * options: the parsed options as a dictionary, option names as key (derived from the long name)
    *   * args: array of positional arguments
    *   * processed: the last arg index processed
    */
    parse(args, parseOptions) {
        const result = {
            options: {}, // options and flags
            args: [],     // positional arguments
            processed : 0 // number of processed arguments
        };
        
        const shouldStop = ??parseOptions.shouldStop; 
        let doubleDash = false;
        for (let i = 1; i < args.length; ++i) {
            const arg = args[i];
            if (arg == "--") {
                doubleDash = true;
                continue;
            }
            if (arg.startsWith('--') && !doubleDash) {
                i = this.#processLongOpt(args, i, result);
            } else if (arg.startsWith('-') && !doubleDash) {
                i = this.#processShortOpt(args, i, result);
            } else {
                result.args.push(arg);
            }

            result.processed = i;
            if (shouldStop && shouldStop(args, result)) 
                break;
        }
        // check defaults not yet set...
        for (const def in this.#defaults)  {
            if (!hasProp(result.options, def.name)) {
                result.options[def.name] = def.default;
            }
        }
        return result;
    }
}
