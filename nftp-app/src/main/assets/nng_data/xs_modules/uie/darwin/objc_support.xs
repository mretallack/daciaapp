import {objDescriptor} from "system://objc"?
import {defineProperty} from "system://core"
import * as os from "system://os";

export decorator @objcProto(classDesc) {
    @register(objDescriptor ? o => defineProperty(o?.prototype ?? o, objDescriptor, #{value:classDesc}) : void)
}
