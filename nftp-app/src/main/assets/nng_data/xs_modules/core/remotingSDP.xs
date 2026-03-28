import * as remoting from "system://remoting"
import {registerService} from "system://dns-sd"
import { DisposeSet } from "system://core.types"
import { disposeSeq } from "system://core"

@dispose
object srvs 
{
    @dispose(disposeSeq)
    regs = [];

    register(name, type, ...ports) {
        for(const port in ports) {
            if (port <= 0) continue;
            if (let r = ??registerService({name, port, type}))
                this.regs.push(r);
        }
    }
}

@onLoad
registerAll() {
    const name = SysConfig.get("remoting", "dns_sd_name", "");
    if (name) {
        srvs.register(name, "nng-ipc", remoting.ports());
        srvs.register(name, "nng-ipc-ws", remoting.ports());
    }
}
