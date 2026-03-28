import { mass } from "system://format.stdProviders"

export enum MassUnit{
    METRIC_TON = 0,
    LONG_TON = 1,
    SHORT_TON = 2, 
}

class mass_format{
    prec_value = 0;

    constructor(prec_val){
        this.prec_value = prec_val;
    }

    short_ton(spec, value){ return mass(value, MassFormatProvider.getParams(spec), spec.stream, MassUnit.SHORT_TON, this.prec_value); }
    long_ton(spec, value){ return mass(value, MassFormatProvider.getParams(spec), spec.stream, MassUnit.LONG_TON, this.prec_value); }
    metric_ton(spec, value){ return mass(value, MassFormatProvider.getParams(spec), spec.stream, MassUnit.METRIC_TON, this.prec_value); }
    [Symbol.call](spec, value) { return mass(value, MassFormatProvider.getParams(spec), spec.stream, MassFormatProvider.unitType, this.prec_value); }
};

export class MassFormatProvider extends mass_format{
    static unitType = (MassUnit.METRIC_TON);

    static setUnit(unit) {
        if (typeof(unit) == @int && unit <= MassUnit.METRIC_TON ) {
            MassFormatProvider.unitType = unit;
        }
    }

    static setUnitShortTon() { MassFormatProvider.unitType = MassUnit.SHORT_TON; }
    static setUnitLongTon()  { MassFormatProvider.unitType = MassUnit.LONG_TON; }
    static setUnitMetricTon()  { MassFormatProvider.unitType = MassUnit.METRIC_TON; }

    static getParams(spec) {
        return spec.formatParam ? spec.formatParam : "%D %U";
    }

    prec = new mass_format(0);
    rounded = new mass_format(1);

    constructor() {
        super(0); // default format is prec
    }

};

