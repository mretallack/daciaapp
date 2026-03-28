import { speed } from "system://format.stdProviders"
import { typeof } from "system://core"

export enum SpeedUnit{
    MPH_YARD = 0,  //miles per hour, yard based
    KMH = 1,  //km/h
    MPH_FEET = 2,  //miles per hour, feet based
}

class speed_format{
    prec_value = 0;

    constructor(prec_val){
        this.prec_value = prec_val;
    }

    mph_yard(spec, value){ speed(value, SpeedFormatProvider.getParams(spec), spec.stream, SpeedUnit.MPH_YARD, this.prec_value); }
    kmh(spec, value){ speed(value, SpeedFormatProvider.getParams(spec), spec.stream, SpeedUnit.KMH, this.prec_value); }
    mph_feet(spec, value){ speed(value, SpeedFormatProvider.getParams(spec), spec.stream, SpeedUnit.MPH_FEET, this.prec_value); }
    [Symbol.call](spec, value) { speed(value, SpeedFormatProvider.getParams(spec), spec.stream, SpeedFormatProvider.unitType, this.prec_value); }
};

export class SpeedFormatProvider extends speed_format{
    static unitType = (SpeedUnit.KMH);

    static setUnit(unit) {
        if (typeof(unit) == @int && unit <= SpeedUnit.MPH_FEET ) {
            SpeedFormatProvider.unitType = unit;
        }
    }

    static setUnitMeter() { SpeedFormatProvider.unitType = SpeedUnit.KMH; }
    static setUnitYard()  { SpeedFormatProvider.unitType = SpeedUnit.MPH_YARD; }
    static setUnitFeet()  { SpeedFormatProvider.unitType = SpeedUnit.MPH_FEET; }

    static getParams(spec) {
        return spec.formatParam ? spec.formatParam : "%D %U";
    }

    prec = new speed_format(0);
    rounded = new speed_format(1);

    constructor(){
        super(1); // default precision is rounded
    }
};
