export * from "system://web.xml";
import {Reader} from "system://web.xml"
import {typeof, isCallable} from "system://core"
import {record} from "system://core.types"
import {method} from "system://functional"

export attrValue(r) {
    if (const name = r.nextAttr())
        return name, r.attrValue();
    else
        return undef;
}

export attrs(r) {
  const d={};
  for(let name; (name = r.nextAttr());) {
      d[name] = r.attrValue();
  }
  d;
}
export *attrList(r) {
    for(let name; (name = r.nextAttr());)
        yield (name, r.attrValue());
}

export xmlNode(r, nodeName) {
    r = typeof(r) == @string ? new Reader(r) : r.copy();
    return object extends r {  // tdod extends should accept an expression (or update xs parizel)
        name = isCallable(nodeName) ? nodeName(r) : nodeName;
        *children() {
            let cr = this.copy();
            for(let cname = cr.toChild(); cname; cname = cr.toSibling())
                yield xmlNode(cr, cname);
        }
        get firstChild() { xmlNode(this, method(@toChild))}
        get nextSibling() { xmlNode(this, method(@toSibling))}
        get nextNode() { xmlNode(this, method(@toNextNode))}
        nextNodeOf(name) { xmlNode(this, method(@toNextNode, ?, name))}
        attrList() { attrList(this.copy()); } // generator
        get attrs() { attrs(this.copy()); }
        get attrRec() { attrList(this.copy()) |> record.fromEntries(^) }
        text(ws) { r.copy().text(ws) }
    }
}
