import * as impl from "android://clipboard"
export * from "android://clipboard"
import {connectable} from "system://core.observe"

export const clipboardChanged = connectable(impl.onClipboardChanged(?));
