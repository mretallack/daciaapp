import { temperature } from "system://format.providers"
import { typeof } from "system://core"

export enum TemperatureUnit{
    Celsius = 0,
    Fahrenheit = 1,
    Kelvin = 2
}

export class TemperatureFormatProvider{
    static unitType = (TemperatureUnit.Celsius);

    static setUnitCelsius() { TemperatureFormatProvider.unitType = TemperatureUnit.Celsius; }
    static setUnitFahrenheit()  { TemperatureFormatProvider.unitType = TemperatureUnit.Fahrenheit; }
    static setUnitKelvin()  { TemperatureFormatProvider.unitType = TemperatureUnit.Kelvin; }

    [Symbol.call](spec, value) {
        temperature(value, spec.formatParam, spec.stream, TemperatureFormatProvider.unitType, TemperatureFormatProvider.unitType);
    }

    fromCelsius(spec, value){
        temperature(value, spec.formatParam, spec.stream, TemperatureFormatProvider.unitType, TemperatureUnit.Celsius);
    }

    fromKelvin(spec, value){
        temperature(value, spec.formatParam, spec.stream, TemperatureFormatProvider.unitType, TemperatureUnit.Kelvin);
    }

    fromFahrenheit(spec, value){
        temperature(value, spec.formatParam, spec.stream, TemperatureFormatProvider.unitType, TemperatureUnit.Fahrenheit);
    }
};
