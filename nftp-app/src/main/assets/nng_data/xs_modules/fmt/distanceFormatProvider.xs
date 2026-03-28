import { distance } from "system://format.stdProviders"
import { typeof } from "system://core"

export enum DistanceUnit{
    YARD = 0,
    KILOMETERS = 1,
    FEET = 2,
}

class distance_format{
    formatid = 0;

    constructor(format_id){
        this.formatid = format_id;
    }

    yard(spec, value){ return distance(value, DistanceFormatProvider.getParams(spec), spec.stream, DistanceUnit.YARD, this.formatid); }
    kilometer(spec, value){ return distance(value, DistanceFormatProvider.getParams(spec), spec.stream, DistanceUnit.KILOMETERS, this.formatid); }
    km(spec, value){ return this.kilometer(spec, value); }
    feet(spec, value){ return distance(value, DistanceFormatProvider.getParams(spec), spec.stream, DistanceUnit.FEET, this.formatid); }
    [Symbol.call](spec, value) { return distance(value, DistanceFormatProvider.getParams(spec), spec.stream, DistanceFormatProvider.unitType, this.formatid); }
};

export class DistanceFormatProvider extends distance_format{
    static unitType = (DistanceUnit.KILOMETERS);

    static setUnit(unit) {
        if (typeof(unit) == @int && unit <= DistanceUnit.FEET ) {
            DistanceFormatProvider.unitType = unit;
        }
    }
    static setUnitMeter() { DistanceFormatProvider.unitType = DistanceUnit.KILOMETERS; }
    static setUnitYard() { DistanceFormatProvider.unitType = DistanceUnit.YARD; }
    static setUnitFeet() { DistanceFormatProvider.unitType = DistanceUnit.FEET; }

    static getParams(spec) {
        return spec.formatParam ? spec.formatParam : "%D %U";
    }

    constructor() {
        super(0); // default format is prec
    }

    prec = new distance_format(0);
    rounded = new distance_format(1);
    hidden = new distance_format(2);
    midround = new distance_format(3); // 10, 20.. 100m, 120, 140..200, 200m...950m, 1km, 1.1km...9.9km 10km, 11km
    small_unit = new distance_format(4); // diplay only the small
    midround_round_below_100 = new distance_format(5); // like midround, but below 100, it will be lower-rounded.
    prec_round_below_100 = new distance_format(6); // like prec, but below 100, it will be lower-rounded.
    // Actually it is same as midrange, the comment is not good: "like prec, but negative values are valid too."
    //custom_2 = new distance_format(7);
    simple_prec_base = new distance_format(8); // meters/yards/feets as xx.yy
    midround_50 = new distance_format(9); // Same as MIDROUND, but 100, 150, 200, ...
};
