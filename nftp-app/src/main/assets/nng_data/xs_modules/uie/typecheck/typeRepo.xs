import { hasProp, typeof } from "system://core"
import { slice } from "system://itertools"
import {Map} from "system://core.types"

export class TypeRepository {
    tree = {}; // repository of user types
    system = {}; // should fill system types, like array, list, etc.
    instances = Map {};
    registerType(path, type) {
        let package = this.tree;
        //slice(path, 0, len(path)-1).reduce((package, p) => (package[p] ??={}), this.tree);
        for (const p in slice(path, 0, len(path) - 1)) {
            package = (package[p] ??={});
        }
        package[path[-1]] = type;
    }

    registerInstanceOf(genType, params, type) {
        this.instances.set((genType, params), type);
    }
    getTypeInstance(genType, params) {
        this.instances?.[(genType,params)];
    }

    getType(path) {
        let res = this.tree;
        for (const p in path) 
        {
            res = res?.[p];
            if (!res) return res;
        }
        return res;
    }
}
