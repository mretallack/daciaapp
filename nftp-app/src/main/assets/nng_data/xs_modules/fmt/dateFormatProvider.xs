import { date } from "system://format.providers"
import { typeof, hasProp, deleteProp } from "system://core"

class Date_RFC822
{
    [Symbol.call](spec, value) { date(value, "%LE, %DD %LM %yyyy %HH:%mm:%ss", spec.stream); }
    date(spec, value) { date(value, "%LE, %DD %LM %yyyy", spec.stream); }
};
class Date_ISO8601
{
    static #GetString(spec, value, dateOnly){
        let includeT = spec.formatSpec.indexOf("%T") != -1;
        let omitHyphen = spec.formatSpec.indexOf("0") != -1;

        let datePart = omitHyphen ? "%yyyy%MM%DD" : "%yyyy-%MM-%DD";

        if (dateOnly)
            return datePart;

        let timePart = omitHyphen ? "%HH%mm%ss" : "%HH:%mm:%ss";
        let connectString = includeT ? "T":" ";
        
        return datePart + connectString + timePart;
    }

    [Symbol.call](spec, value) { date(value, Date_ISO8601.#GetString(spec, value, false), spec.stream); }
    date(spec, value) { date(value, Date_ISO8601.#GetString(spec, value, true), spec.stream); }
};

export class DateFormatProvider{
    RFC822 = new Date_RFC822();
    ISO8601 = new Date_ISO8601();

    static #customDateFormats = odict{
        long = "%yyyy-%MM-%DD %HH:%mm:%ss";
        short = "%MM-%DD %HH:%mm";
        time = "%HH:%mm:%ss";
        time_short = "%HH:%mm";
        date = "%yyyy-%MM-%DD";
        date_short = "%MM-%DD";
    };

    [Symbol.call](spec, value) {
        let lastParam = spec.formatType.size > 0 ? spec.formatType[-1] : "";
        if (hasProp(DateFormatProvider.#customDateFormats, lastParam))
        {
            return date(value, DateFormatProvider.#customDateFormats[lastParam], spec.stream);
        }

        return date(value, spec.formatParam, spec.stream);
    }

    static SetCustomDateFormat(name, formatString){
        if (typeof(name) == @string && name != "" && name.indexOf(":") == -1){
            if (typeof(formatString) == @string)
                DateFormatProvider.#customDateFormats[name] = formatString;
            else if (formatString == undef)
                deleteProp(DateFormatProvider.#customDateFormats, name);
        }
    }
    
};

