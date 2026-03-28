import MockModuleRegistry from "system://mock.moduleRegistry"
import { map as Map } from "system://core.types"
import { curry } from "system://functional"
import { isCallable} from "system://core"

const registry = new MockModuleRegistry();
const sandbox = System.sandbox(registry); 
 
class ImportCollector {
    modules = (new Map());
    #lastModule = undef;

    constructor(filteredPath = undef) {
        registry.getModule = (path, currentFile, srcInfo, modAttrs) => {
            if (path == filteredPath)
                return @fallback;
            if (!this.modules.has(path))
                this.modules.set(path, #{ path: path, imported: [], source: srcInfo, with:modAttrs });
            this.#lastModule = this.modules.get(path);
            return true;
        };

        registry.resolveExport = (name) => {
            // always resolves imports
            // add to the imports list of lastModule
            var import = this.#lastModule.imported.find((item) => { name == item });
            if (!import) {
                this.#lastModule.imported.push(name);
            }
            return this.#lastModule, name;
        };
    }

    get lastModule() { this.#lastModule;}

    unregister() {
        registry.getModule = registry.resolveExport = undef;
    }
}

convertToParseInfo(def) { debug.parseInfo(@nested, def) }

export parseModuleContents(moduleString, parseListener, config = undef) {
    var importCollector = new ImportCollector();
    var id = 0;
    const definitionMapper = isCallable(config) ? config : (config?.definitionMapper ?? convertToParseInfo);
    var module = ??sandbox.parseModule(moduleString, {
        onDefinition(loc, name, def, kind) {
            var defInfo = def;
            if (kind != @namespace) {
                defInfo = definitionMapper(def);
                if (parseListener) parseListener.onDefinition(loc, name, defInfo, kind);
            } else {
                if (parseListener) parseListener.onDefinition(loc, name, defInfo, kind, ++id);
                return id;
            }
        },
        onImport(loc, name, def, srcInfo) {
            if (parseListener) parseListener.onImport(loc, name, def, srcInfo);
        },
        onExport(loc, name, exportSource, localName, srcInfo) {
            if (!localName) {
                //console.log("export", name);
                if (parseListener) parseListener.onExport(loc, name, undef, undef, srcInfo);
            } else {
                var lastModule = importCollector.lastModule;
                if (name == "*") {
                    //console.log("export * from", lastModule.path);
                    if (parseListener) parseListener.onExport(loc, name, lastModule.path, localName, srcInfo, lastModule?.with);
                } else if (exportSource){
                    //console.log("export", localName, "as", name, "from", lastModule.path);
                    if (parseListener) parseListener.onExport(loc, name, lastModule.path, localName, srcInfo, lastModule?.with);
                }
                else {
                    //console.log("export", localName, "as", name);
                    if (parseListener) parseListener.onExport(loc, name, undef, localName, srcInfo);
                } 
            }
        }
    }, config?.langId);

    for (let impModule in importCollector.modules.values) {
        if (impModule.imported.length == 0) { // empty import
            if (parseListener) parseListener.onImport(id, undef, (impModule, undef), impModule.source);   
        }
    }

    importCollector.unregister();
    return module;
}

export parseModule(modulePath) {
    // todo: maybe use System.getf for loading file contents
    var importCollector = new ImportCollector(modulePath);
    
    var module = ??sandbox.loadModule(modulePath);

    importCollector.unregister();

    return module;
}

export parseNssContents(moduleString, parseListener, definitionMapper = convertToParseInfo) {
    let res, style = ??System.parseNss(moduleString);
    if (style) {
        let defInfo = definitionMapper(style);
        if (parseListener) parseListener.onDefinition(0, "stylesheet", defInfo, @object);
    }
    return res;
}
