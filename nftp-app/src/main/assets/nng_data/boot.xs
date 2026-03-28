import {listen} from "system://socket"

const server = listen(#{host:"0.0.0.0", port:9876});
if (server) {
    server.subscribe(s => {}, e => {}, () => {});
}
