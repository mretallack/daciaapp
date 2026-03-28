import { formatter} from "system://fmt"
export * from "system://fmt";
import { typeof, hasProp, deleteProp } from "system://core"
import { DistanceFormatProvider } from "./distanceFormatProvider.xs"
export { DistanceFormatProvider, DistanceUnit } from "./distanceFormatProvider.xs"
import { DateFormatProvider } from "./dateFormatProvider.xs"
export { DateFormatProvider } from "./dateFormatProvider.xs"
import { SpeedFormatProvider } from "./speedFormatProvider.xs"
export { SpeedFormatProvider, SpeedUnit } from "./speedFormatProvider.xs"
import { GcoorFormatProvider } from "./gcoorFormatProvider.xs"
import { TemperatureFormatProvider } from "./temperatureFormatProvider.xs"
export { TemperatureFormatProvider, TemperatureUnit} from "./temperatureFormatProvider.xs"
import { MassFormatProvider} from "./massFormatProvider.xs"
export { MassFormatProvider, MassUnit } from "./massFormatProvider.xs"

/**
* The FormatProvider manages custom format handlers using the system's fmt module.
* You can add custom formatters for custom format types.
*/
@preload @dispose
export object formatProvider
{
    #formatters;
    // Registers the format provider into the fmt lib
    @dispose
    #formatterSubs = do { formatter.subscribe(this.#handleFormat(?)) }

    #handleFormat(spec, value)
    {
        if (spec.formatType.length == 0)
            return spec.next(spec, value);

        let formatterFunctionOwner = this.#formatters;
        let formatterFunction = this.#formatters;
        let formatterFunctionName = undef;

        for(let f in spec.formatType){
            if (hasProp(formatterFunction, f)){
                formatterFunctionName = f;
                formatterFunctionOwner = formatterFunction;
                formatterFunction = formatterFunction[f];
            } else {
                break;
            }
        }

        if (formatterFunction != this.#formatters)
            return formatterFunctionOwner[formatterFunctionName](spec, value); //Provides 'this' for the called function
        else
            return spec.next(spec, value);
    }
    
    /**
    * Adds a new formatter under the specified name.
    * If name is 'myformat', and '{:myformat}' is being formatted, then the FormatProvider will call 
    * the specified formatter expecting it to provide formatting.
    * @param name - The formatters name
    * @param handler - The formatter function
    */
    addFormatter(name, formatter)
    {
        if ( typeof( name ) == @string )
        {
            this.#formatters[name] = formatter;
        }
    }

    /**
    * Removes a previously added formatter
    * @param name - The formatters name
    */
    removeFormatter(name)
    {
        if ( typeof( name ) == @string )
        {
            deleteProp(this.#formatters, name);
        }
    }

    /**
    * Removes all previously added formatters
    */
    reset()
    {
        this.#formatters = {
            distance: new DistanceFormatProvider,
            datetime: new DateFormatProvider,
            speed: new SpeedFormatProvider,
            gcoor: new GcoorFormatProvider,
            temperature: new TemperatureFormatProvider,
            mass: new MassFormatProvider
        };
    }
    static {
        this.reset();
    }
}
