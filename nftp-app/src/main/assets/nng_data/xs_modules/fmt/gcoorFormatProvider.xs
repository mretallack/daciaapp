import { gcoor } from "system://format.stdProviders"

enum GcoorFormat {
    DDD,
    DDM,
    DMS,
    NUMBER
}

export class GcoorFormatProvider{

    [Symbol.call](spec, value) {
        this.ddd(spec, value);
    }

    // default mode: %lat %lon
    // default format: DDD
    // L"{:gcoor}" == L"{:gcoor:ddd|%lat %lon}"

    static getMode(spec) {
        return spec.formatParam ? spec.formatParam : "%lat %lon";
    }

    ddd(spec, value) {
        let modeStr = GcoorFormatProvider.getMode(spec);
        gcoor(value, modeStr, spec.stream, GcoorFormat.DDD, spec.formatSpec);
    }

    ddm(spec, value) {
        let modeStr = GcoorFormatProvider.getMode(spec);
        gcoor(value, modeStr, spec.stream, GcoorFormat.DDM, spec.formatSpec);
    }

    dms(spec, value) {
        let modeStr = GcoorFormatProvider.getMode(spec);
        gcoor(value, modeStr, spec.stream, GcoorFormat.DMS, spec.formatSpec);
    }

    number(spec, value) {
        let modeStr = GcoorFormatProvider.getMode(spec);
        gcoor(value, modeStr, spec.stream, GcoorFormat.NUMBER, spec.formatSpec);
    }

};
