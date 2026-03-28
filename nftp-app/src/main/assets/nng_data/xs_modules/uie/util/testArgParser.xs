import {TestSuite, EXPECT, @registerSuite, @metadata, propertiesAre, unorderedElementsAre} from "xtest.xs"
import {default as ArgParser, NArgsType} from "./args.xs"

@metadata({
    description: "",
    owner: @UIEngine,
    feature: @Unknown,
    level: @component,
    type: @functional,
})
@registerSuite
class TestArgParser extends TestSuite {
    
    createArgParser(options) {
        let argParser = new ArgParser();
        for (const opt in options) {
            const type = opt.type ?? @flag;
            const hasDefault = opt?.default;
            if (type == @flag) {
                if (hasDefault) {
                    argParser.addFlag(opt.arguments, opt.default);
                } else {
                    argParser.addFlag(opt.arguments);
                }
            } else if (type == @optionAppend) {
                if (hasDefault) {
                    argParser.addOptionAppend(opt.arguments, opt.default);
                } else {
                    argParser.addOptionAppend(opt.arguments);
                }
            } else {
                if (hasDefault) {
                    argParser.addOption(opt.arguments, opt.default);
                } else {
                    argParser.addOption(opt.arguments);
                }
            }
        }
        return argParser;
    }


    static data_Flags = [
        // [name/id, [options1, options2, ...], [arg1, arg2, ...], {expected props}]
        // options: {type: @option/@flag, arguments: argName/[array]/(tuple), default: value}
        [1,  [{arguments: ["-h", "--help"]}], [], {}],
        [2,  [{arguments: ["-h", "--help"]}], ["-h"], {help: 1}],
        [3,  [{arguments: ["-h", "--help"]}], ["--help"], {help: 1}],
        [4,  [{arguments: ["-h"]}, {arguments:["-v"]}], ["-h", "-v"], {h: 1, v: 1}],
        [5,  [{arguments: "-h"}, {arguments: "-v"}], ["-h", "-v"], {h: 1, v: 1}],
        [6,  [{arguments: ["--help"]}, {arguments: ["--version"]}], ["--help", "--version"], {help: 1, version: 1}],
        [7,  [{arguments: "--help"}, {arguments: "--version"}], ["--help", "--version"], {help: 1, version: 1}],
        [8,  [{arguments: ["-h", "--help"], default: true}], [], {help: 1}],
        [9,  [{arguments: ["-h", "--help"], default: true}], ["-h"], {help: 1}],
        [10, [{arguments: "--help", default: true}, {arguments: "--version", default: true}], [], {help: 1, version: 1}],
    ];

    ddtest_Flags(s, options, args, expectedProps) {
        let argParser = this.createArgParser(options);
        let cmdLine = argParser.parse(["program_name", ...args]);
        EXPECT.THAT(cmdLine.options, propertiesAre(expectedProps));
    }

    static data_Options = [
        // [name/id, [options1, options2, ...], [arg1, arg2, ...], {expected props}]
        // options: {type: @option/@flag, arguments: argName/[array]/(tuple), default: value}
        [1, [{type:@options, arguments: ["-c", "--connect"]}], [], {}],
        [2, [{type:@options, arguments: ["-c", "--connect"], default: "localhost:2000"}], [], {connect: "localhost:2000"}],
        [3, [{type:@options, arguments: ["-c", "--connect"]}], ["-c", "localhost:2000"], {connect: "localhost:2000"}],
        [4, [{type:@options, arguments: ["-c", "--connect"]}], ["--connect", "localhost:2000"], {connect: "localhost:2000"}],
        [5, [{type:@options, arguments: ["-c", "--connect"]}], ["--connect=localhost:2000"], {connect: "localhost:2000"}],
        [6, [{type:@options, arguments: ["-c", "--connect"], default: "localhost:2000"}], ["--connect", "localhost:2100"], {connect: "localhost:2100"}],
        [7, [{type:@options, arguments: ["-c", "--connect"], default: "localhost:2000"}], ["-c", "localhost:2100"], {connect: "localhost:2100"}],
        [8, [{type:@options, arguments: ["-c", "--connect"], default: "localhost:2000"}], ["--connect=localhost:2100"], {connect: "localhost:2100"}],
        [9, [{type:@options, arguments: ["-c", "--connect"]}], ["--connect=localhost:2100=kakukk"], {connect: "localhost:2100=kakukk"}],
    ];

    ddtest_Options(s, options, args, expectedProps) {
        let argParser = this.createArgParser(options);
        let cmdLine = argParser.parse(["program_name", ...args]);
        EXPECT.THAT(cmdLine.options, propertiesAre(expectedProps));
    }

    static data_Bundle = [
        // [name/id, [options1, options2, ...], [arg1, arg2, ...], {expected props}]
        // options: {type: @option/@flag, arguments: argName/[array]/(tuple), default: value}
        [1, [{type: @option, arguments: ["-c", "--connect"]}], ["-clocalhost:2000"], {connect: "localhost:2000"}],
        [2, [{type: @option, arguments: ["-c", "--connect"]}, {arguments: "-v"}], ["-vclocalhost:2000"], {connect: "localhost:2000", v: 1}],
        [3, [{type: @option, arguments: ["-c", "--connect"]}, {arguments: ["-v", "--version"]}], ["-vclocalhost:2000"], {connect: "localhost:2000", version: 1}],
        [4, [{type: @option, arguments: ["-c", "--connect"]}, {arguments: ["-v", "--version"]}, {arguments: ["-l"]}], ["-vlclocalhost:2000"], {connect: "localhost:2000", version: 1, l: 1}],
        [5, [{arguments: ["-l"]}, {arguments: "-c"}, {arguments: ("-a")}], ["-lac"], {l: 1, a: 1, c: 1}],
        [6, [{type: @option, arguments: "-h"}, {type: @option, arguments: "-w"}], ["-h24", "-w48"], {h: "24", w:"48"}],
        [7, [{type: @option, arguments: "-h"}, {type: @option, arguments: "-w"}], ["-h24w12"], {h: "24w12"}],
        [8, [{type: @option, arguments: "-h", default: 12}, {type: @option, arguments: "-w", default: 12}], ["-h24", "-w48"], {h: "24", w: "48"}],
        [9, [{type: @option, arguments: "-h", default: 12}, {type: @option, arguments: "-w", default: 12}], ["-h24w48"], {h: "24w48", w: 12}],
    ];

    ddtest_Bundle(s, options, args, expectedProps) {
        let argParser = this.createArgParser(options);
        let cmdLine = argParser.parse(["program_name", ...args]);
        EXPECT.THAT(cmdLine.options, propertiesAre(expectedProps));
    }

    test_DoubleDash() {
        let argParser = this.createArgParser([{type: @option, arguments: ["-c", "--connect"], default: "localhost:2000"}]);
        let cmdLine = argParser.parse(["program_name", "--connect", "localhost:2010", "--", "--all", "--beta"]);
        EXPECT.THAT(cmdLine.options, propertiesAre({connect: "localhost:2010"}));
        EXPECT.THAT(cmdLine.args, unorderedElementsAre("--all", "--beta"));

        cmdLine = argParser.parse(["program_name", "--", "--connect", "localhost:2010", "--all", "--beta"]);
        EXPECT.THAT(cmdLine.options, propertiesAre({connect: "localhost:2000"}));
        EXPECT.THAT(cmdLine.args, unorderedElementsAre("--connect", "localhost:2010", "--all", "--beta"));
    }

    test_MultipleValues() {
        // normal option
        let argParser = this.createArgParser([{type: @option, arguments: ["-l", "--library"]}]);
        let cmdLine = argParser.parse(["program_name", "-l", "lib/stdlib", "-l", "lib/extlib"]);
        EXPECT.THAT(cmdLine.options, propertiesAre({library: "lib/extlib"}));
        cmdLine = argParser.parse(["program_name", "--library", "lib/stdlib", "--library", "lib/extlib"]);
        EXPECT.THAT(cmdLine.options, propertiesAre({library: "lib/extlib"}));


        let multiParser = this.createArgParser([{type: @optionAppend, arguments: ["-l", "--library"]}]);
        let multiCmdLine = multiParser.parse(["program_name", "-l", "lib/stdlib", "-l", "lib/extlib"]);
        EXPECT.THAT(multiCmdLine.options, propertiesAre({library: ["lib/stdlib", "lib/extlib"]}));
        multiCmdLine = multiParser.parse(["program_name", "--library", "lib/stdlib", "--library", "lib/extlib"]);
        EXPECT.THAT(multiCmdLine.options, propertiesAre({library: ["lib/stdlib", "lib/extlib"]}));
    }

    test_AddArgument() {
        let argParser = new ArgParser();
        argParser.addArgument(["--help", "-h"], NArgsType.Zero);
        argParser.addArgument(["--connect", "-c"], NArgsType.One);
        argParser.addArgument(["--library", "-l"], NArgsType.Multiple);
        let cmdLine = argParser.parse(["program_name", 
            "-l", "lib/stdlib", 
            "--connect=localhost:2012", 
            "--library=lib/extlib", 
            "--help", 
            "--", 
            "--library=lib/beta"]);
        
        EXPECT.THAT(cmdLine.options, propertiesAre({
            library: ["lib/stdlib", "lib/extlib"],
            help: 1,
            connect: "localhost:2012"}));
        EXPECT.THAT(cmdLine.args, unorderedElementsAre("--library=lib/beta"));
    }
}