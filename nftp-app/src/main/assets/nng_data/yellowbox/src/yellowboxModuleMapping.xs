import {entries} from "system://core"
import * as iter from "system://itertools";
import * as os from "system://os"

export const mapping = getMappings();

const modules = #{
    "app://yellowbox.updateApi" : #{ 
                                    module: "nngfile://app/yellowbox/src/service/updateAPI.xs",
                                      mock: "nngfile://app/yellowbox/src/mock/update_service_mock.xs",
                                  },
};

const appModules = #{
    "app://downloadManager": #{
        win32: "nngfile://xs/core/platform/winDownloadManager.xs",
        android: "android://downloadManager",
        ios: "nngfile://app/yellowbox/src/toolbox/platform/iosDownloadManager.xs"
    }

};

getMappings() {
    const useMocks = SysConfig.get("yellowBox", "useMocks", false );
    const impl = useMocks ? @mock : @module;
    const mapping = iter.fromEntries(modules).mapApply( (k,v) => (string(k), v[impl]) ).toArray();

    for(const k,v in entries(appModules)) {
        const value = v?.[os.platform] ?? v?.default;
        if (value)
            mapping.push( (string(k), value) );
    }
    return mapping;
}