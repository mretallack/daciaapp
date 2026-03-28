import {Reader,addEscapedText} from "system://web.xml"
import {identifier, isCallable, typeof, isBool} from "system://core"
import {isBufferLike} from "system://core.types"
import {decode,encode} from "system://web.Base64"
import Stream from "system://core.StringStream"

parseValue(xml, type) {
    const cdepth=xml.depth+1;
    if (type == "array") {
        const v=[];
        while((type = xml.toNextNode(cdepth))) {
            v.push(parseValue(xml,type))
        }
        return v;
    } else if (type == "dict") {
        const v={};
        let key = undef;
        while((type=xml.toNextNode(cdepth))) {
            if (type == "key")
                key = identifier(xml.text());
            else if (key) {
                v[key] = parseValue(xml, type);
                key = undef;
            }
        }
        return v;
    } else if (type == "string")
        return xml.text();
    else if (type == "true")
        return true;
    else if (type == "false")
        return false;
    else if (type == "integer" || type == "real")
        return +xml.text();
    else if (type == "data")
        return decode(xml.text(), @asBuffer);
    else if (type == "date")
        return xml.text();

    return undef;
}
export parseXml(str) {
    const xml=Reader(str);
    if (xml.toNextNode()!= "plist")
        return undef;
    parseValue(xml, xml.toNextNode());
}

const xmlHead = `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
`;

writeNode(stream, node, content) {
    stream.add("<",node, ">");
    if (isCallable(content))
        content(stream);
    else
        stream.add(content);
    stream.add("</",node, ">");
}
addXmlValue(stream, data) {
    const t = typeof(data);
    if (isBool(data))
        stream.add(data ? "<true/>" : "<false/>");
    else if (t == @int || t== @int64)
        writeNode(stream, "integer", data );
    else if (t== @float || t==@double)
        writeNode(stream, "real", data );
    else if (t == @string)
        writeNode(stream, "string", addEscapedText(?, data));
    else if (t == @object || t == @tuple) {
        // TODO: date
        if (isBufferLike(data))
            writeNode(stream, "data", () => { stream.add(encode(data)); });
        else if (data?.length != undef && data.length == (len(data)??undef)) {
            stream.add('<array>');
            for(const v in data) {
                addXmlValue(stream, v);
            }
            stream.add('</array>');
        } else {
            stream.add("<dict>");
            for(const k in data) {
                writeNode(stream, "key", addEscapedText(?, k));
                addXmlValue(stream, data[k]);
            }
            stream.add("</dict>");
        }
    }
    else // always add something to prevent bad plist errors
        stream.add("<false/>");
}

export toXml(data) {
    const stream = Stream(xmlHead);
    addXmlValue(stream, data);
    stream.add('\n</plist>\n');
}