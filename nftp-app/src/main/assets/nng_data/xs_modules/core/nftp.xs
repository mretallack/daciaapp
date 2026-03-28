import {DataReader,Uint8Array,ArrayBuffer, DataWriter, Map,dict, record} from "system://core.types"
import {and, or, shr,shl} from "system://math"
import {typeof, dispose, tryDispose, failure, ident} from "system://core"
import {objOf, always} from "system://functional"
import {Stream, Reader} from "system://serialization"
import {Observable} from "system://core.observe"
import {joinPath} from "core/ioUtils.xs"

export const Version = 1;
export enum Message {
    Init = 0,
    PushFile = 1,
    Commit = 2, // handled but not used
    GetFile = 3,
    QueryInfo = 4,
    CheckSum = 5,
    DeleteFile = 6,
    RenameFile = 7,
    LinkFile = 8, // link(orig,new, makeHardLink: bool) symlink by default or hardlink
    UpdateSelf = 9, // not implemented
    PrepareForTransfer = 10, // tell yellowtool we will try to start a fileTransfer
    TransferFinished = 11,   // tell yellowtool it can restart igo when needed
    Mkdir = 12,
    Chmod = 13,
    Event = 14, // not handled
}

export enum CtrlMessage {
    StopStream  = 0,
    PauseStream = 1,
    ResumeStream = 2
}

export enum Response
{
    Success = 0,
    Failed = 1,
    BadFilePos = 2,
    UnknownParam = 0x7e, // e.g. could be unknown checksum method
    Unknown = 0x7f
}

export enum PushOptions
{
    None = 0,
    TruncateFile = 1, // truncates the file before opening
    UsePartFile = 2, // write content to file.part and rename it when operation completes (successfully)
    OverwriteOriginal = 4, // rename original file to part file if used with UsePartFile
    TrimToWritten = 8, // trim file to the written length when push finishes usefull to overwrite the tail with possible shorter data
    OnlyIfExists = 0x10, // don't create the file if it doesn't exist
    // maybe:
    // NoOverwrite: file must not exists
}

export enum ChecksumMethod
{
    MD5 = 0,
    Sha1 = 1,
}

// maps checksum method to method names in digest/nftp module
export const checksumMethod = {
    [ChecksumMethod.MD5]: @md5,
    [ChecksumMethod.Sha1]: @sha1,
};

const flowControlMethods = {
    [CtrlMessage.StopStream] : @stopStream,
    [CtrlMessage.PauseStream] : @pauseStream,
    [CtrlMessage.ResumeStream] : @resumeStream,
};

pktTypeAndAborted(idField, reqId) {
    if (idField == 0xC000)  // control is 0x8000+0x4000 with zero request id
        return #{type:@control};
    const isRspBit  = and(idField, 0x8000);
    return #{ type:    isRspBit ? @response : @request, 
              aborted: and(idField, 0x4000) ? true : Symbol.NoProperty };
}

pktMessageId(reqId, type, aborted) {
    if (type == @control)
        return 0xC000;
    return reqId + (type == @response ? 0x8000 : 0) + (aborted ? 0x4000 : 0);
} 

export async *msgExtractor(r) {
    let buf = DataReader(64*1024);
    let n = (await r.read(buf)) ?? -1;
    if (n < 0) return;
    while(true) {
        let nn = n < buf.length ? r.read(buf.subarray(n)) : undef; // schedule next read if we have space but don't await it
        while(buf.pos + 4 <= n) {
            let pktLenF = buf.u16();
            let idField = buf.u16();
            let len = and(pktLenF, 0x7fff)-4;
            if (buf.pos + len > n) {
                buf.pos -= 4;
                break;
            }
            const requestId = and(idField, 0x3fff);
            yield #{requestId, final: !shr(pktLenF, 15), data: buf.subarray(buf.pos, buf.pos+len),
                    ...pktTypeAndAborted(idField, requestId) };
            buf.pos += len;
        }
        if (nn) {
            nn = (await nn) ?? -1;
            if (nn < 0) { // no more data
                if (buf.pos != n) {
                    console.log("nftp recv broken packet (connection closed?)");
                    //yield buf.substring(last,n);
                }
                break;
            }
            n += nn;
        }
        else if (!buf.pos) {
            console.log("nem szabadna ilyennek lennie");
            debug.pause();
            break;
        }
        if (buf.pos) {
            buf.copyWithin(0, buf.pos, n);
            n -= buf.pos;
            buf.pos = 0;
        }
    }
}

export class StreamWrapper {
    stream;
    #reqId = 1;
    nextRequestId() {
        const id = this.#reqId++;
        if (this.#reqId >= 0x4000)
            this.#reqId = 1;
        return id;
    }
    prepareMsg(len=0) {
        const w = DataWriter(4+len);
        w.pos = 4;
        return w;
    }
    sendImpl(pkt, data) {
        let reqId = pkt?.requestId;
        if (!reqId && (!pkt?.type || pkt?.type == @request)) {
            reqId = this.nextRequestId();
        }
        let len = data.byteLength;
        if ((!reqId && pkt?.type != @control)|| len < 4) {
            error_handler.raise(reqId ? "Bad packet length" : "Send expected a request id");
            return undef;
        }
        const msgId = pktMessageId(reqId, pkt?.type, pkt?.aborted);
        data.u16At(2, msgId);
        if (len < 0x8000)
            data.u16At(0, (pkt.final ?? true) ? len : (0x8000 + len));
        else {
            // fragment message into `frameLen` long frames by inserting frame headers at boundaries
            const frameLen = 0x7fff;
            data.u16At(0, frameLen + 0x8000); // set continue bit (0x8000) on first frame
            const xframes = (len + 3)/(frameLen-4);  //number of extra frames, payload of frame is 4 bytes less the length of frame
            let se = data.byteLength;
            let moreBit = (pkt.final??true) ? 0 : 0x8000;
            data.fill(0, se, se + xframes * 4 ); // extend buffer by adding extra frames times header size byte
            for(let i = xframes; i > 0; ) {
                const ft = i * frameLen; // frame start: frameLen + (i-1)*frameLen
                --i;
                const s  = ft - i * 4; // payload start
                data.copyWithin(ft+4,s, se); // move payload
                data.u16At(ft+2, msgId);
                data.u16At(ft, se - s +4 + moreBit); // length of frame + continuation bit
                se = s;
                moreBit = 0x8000;
            }
        }
        reqId, this.stream.write(data);
    }
    send(pkt) {
        const reqId = this.sendImpl(pkt, pkt.data);
        return reqId,
    }
    sendPrepared(pkt, data) {
        if (!pkt.requestId)
            error_handler.raise("sendPrepared must have a request id");
        const rq,prom = this.sendImpl(pkt, data ?? pkt.data);
        return prom;
    }
}
export wrapNftpStream(s) { StreamWrapper { stream = s} }

object fragmentSink {
    next() {}
    done() { undef; } // resposne already sent
}

export class NftpMessenger {
    conn;
    setupCompleted=false;
    #requests = Map {};
    #handlers; /* dict mapping message type to handlers. handler is called with signature(pkt, messenger, userData) */
    #fragProc = Map {};
    #flowCtrls = Map {};
    constructor(conn, handlers) {
        this.conn = conn;
        this.#handlers = handlers;
    }
    get requests() { return this.#requests; }
    
    [Symbol.dispose]() {
        const closeFail = failure("closing");
        for(const r in this.#requests.values) {
            if (r?.obs) {
                ?? r.clear();
                r.obs.error?.(closeFail);
            } else
                r?.reject(closeFail);
        }
        for(const p in this.#fragProc.values)
            tryDispose(p);
        this.#requests.clear();
        this.#fragProc.clear();
        tryDispose(this.conn);
        this.conn = undef;
    }
    /// Call this function when a new nftp packet is received
    /// @returns true when the request is handled by the messenger
    onReceive(pkt, userData) {
        if (pkt.type == @control && this.#handlers)
            return this.handleControl(pkt, userData);
        if (pkt.type == @request && this.#handlers)
            return this.handleRequest(pkt, userData);

        // handle pending responses, if any
        if (pkt.type != @response)
            return false;
        const reqIdx = this.#requests.getIndex(pkt?.requestId);
        if (reqIdx == undef) return false;
        const req = this.#requests.values[reqIdx];
        if (!req?.resolve) {
            req.obs.next?.(pkt);
            if (!pkt.final)
                return true;
            this.#requests.removeAt(reqIdx);
            req.obs.complete?.();
            req.clear();
            return true;
        }
        if (!pkt.final && !req?.data ) {
            const data = DataWriter(pkt.data); // copies, TODO: no need to copy if using nftp
            data.pos = data.byteLength;
            this.#requests.values[reqIdx] = #{data, ...req };
            return true;
        }
        if (req?.data && req?.proc) // don't save further data if there is no processor since only status
            req.data.writeBytes(pkt.data);
        if (pkt.final) {
            this.#requests.removeAt(reqIdx);
            const r = req?.data ? DataReader.view(req.data) : DataReader(pkt.data); //TODO: no need to copy if using nftp
            const res = r.u8();
            req.resolve(req?.proc ? ?? req.proc?.(r, res) : res); // has to process response other result might be lost
        }
        return true;
    }
    sendHandlerResponse(pkt, resp) {
        this.sendResponse(pkt.requestId, resp?.status ?? resp, resp?.body);
        return true;
    }

    handleRequest(pkt, userData) {
        let processor  = ?? this.#fragProc[pkt.final ? @getAndRemove : @get](pkt.requestId);
        if (processor) {
            let resp = pkt?.aborted ? processor.error?.(pkt) : processor.next(pkt);
            if (resp?.status != undef) {
                this.sendHandlerResponse(pkt, resp);
                tryDispose(processor);
                processor = undef; // will be overridden by fragmentSink if needed
            } else if (!pkt.final) // return without setting processor
                return true;
        } else {
            const handler = this.#handlers?.[pkt.data[0]] ?? this.#handlers?.default;
            if (handler) {
                const resp = handler(pkt, this, userData );
                if (resp?.next)
                    processor = resp;
                else if (resp?.status != undef) // response without `status` means response is or will be sent by other means (but multiple fragment are ignored)
                    return this.sendHandlerResponse(pkt, resp);
            } else {
                this.sendResponse(pkt.requestId, Response.Unknown);
            }
        }
        if (!pkt.final)
            this.#fragProc.set(pkt.requestId, processor ?? fragmentSink);
        else if (processor) {
            const resp = processor.done?.(userData, this, pkt?.aborted);
            tryDispose(processor);
            if (resp?.status != undef)
                this.sendHandlerResponse(pkt, resp);
        }
        return true;
    }
    handleControl(pkt, userData) {
        const data = DataReader.view(pkt.data);
        const ctrlType = data.u8();
        if (const flowMethod = flowControlMethods[ctrlType]) {
            const streamId = data.u16();
            if (const f = ??this.#flowCtrls[flowMethod == @stopStream ? @getAndRemove : @get](streamId)) {
                f[flowMethod]();
                return;
            }
            this.#handlers?.[flowMethod]?.(streamId, data, userData);
        }
    }
    
    sendSimpleMessage(msg) {
        if (!this.conn) return failure("Connection closed");
        const id = this.sendPacket(#{type:@request}, w => {
            w.u8(msg);  // message type    
        },1);
        return new Promise((resolve, reject) => {
            this.#requests.set(id, #{resolve, reject});
        });
    }
    asyncResponse(reqId, proc=undef) {
        if (!this.conn) return failure("Connection closed");
        new Promise((resolve, reject) => {
            this.#requests.set(reqId, #{resolve, reject, proc});
        });
    }
    sendRequest(bodyWriter, proc=undef, lenHint=32) {
        if (!this.conn) return failure("Connection closed");
        const id = this.sendPacket(#{type:@request}, bodyWriter, lenHint);
        return this.asyncResponse(id, proc);
    }
    removeRequestHandler(reqId) {
        if (this.#requests.remove(reqId))
            flowControl(this, CtrlMessage.StopStream, reqId + 0x4000);
    }

    subscribeRequestImpl(bodyWriter, obs, lenHint=32) {
        let reqId = this.sendPacket(#{type:@request}, bodyWriter, lenHint);
        this.#requests.set(reqId, #{obs:obs, clear: () => {reqId = undef}});
        return () => reqId && this.removeRequestHandler(reqId); 
    }
    Request(bodyWriter, lenHint) { 
        if (!this.conn) return failure("Connection closed");
        Observable(this.subscribeRequestImpl(bodyWriter, ?, lenHint))
    }
    
    sendResponse(requestId, statusCode, bodyWriter) {
        if (!this.conn) return failure("Connection closed");
        this.sendPacket(#{type:@response, requestId}, w => {
            w.u8(statusCode);
            bodyWriter?.(w);
        },1)
    }

    sendPacket(pktHead, bodyWriter, lenHint=0 ) {
        if (!this.conn) return failure("Connection closed");
        const w = this.conn?.prepareMsg(lenHint) ?? DataWriter(lenHint);
        bodyWriter(w);
        return ?? this.conn.send(#{...pktHead, data:w.trim(w.pos)});
    }
    flowCtrl(streamId) { // todo: map.emplace or upsert
        if (!this.conn) return failure("Connection closed");
        const flowCtrls = this.#flowCtrls;
        const pos, suc = flowCtrls.insert(streamId, undef);
        if (suc) {
            flowCtrls.values[pos] = new class {
                resolve = undef;
                pauseStream() {
                    if (!this.resolve)
                        this.flow.resumption = new Promise(resolve => {this.resolve = resolve});
                }
                resumeStream() {
                    this.#resolve(true);
                }
                stopStream() { 
                    this.flow.stopped = true;
                    this.#resolve(false);
                }
                #resolve(cont) {
                    this.resolve?.(cont);
                    this.resolve = undef;
                    this.flow.resumption = undef;
                }
                flow = object {
                    stopped = false;
                    resumption = undef;              
                    [Symbol.dispose]() { flowCtrls.remove(streamId); }
                }
            };
        }
        flowCtrls.values[pos].flow;
    }
    responseFlowCtrl(requestId) { this.flowCtrl(requestId + 0x4000) }
}

export writeValue(writer, val) {
    const stream = Stream(@compact);
    stream.add(val);
    writer.writeBytes(stream.transfer());
}

export readValue(reader) {
    const des = new Reader(reader.subarray(reader.pos));
    const val = des.next();
    reader.pos += des.pos;
    return val
}

export flowControl(messenger, ctrlType, streamId) {
    messenger.sendPacket(#{type:@control}, w=> w.u8(ctrlType).u16(streamId), 3);
}

export async queryInfo(messenger, ...keys) {
    return messenger.sendRequest(w => {
        w.u8(Message.QueryInfo);  
        writeValue(w, keys)    
    }, (r,status) => status == 0 ? readValue(r) : @error);
}

*restToChildren(mapper, i) { // map rest of items via mapper to @children, childList pair or to nothing
    i.map(mapper).toTuple() |> ^ && (yield (@children, ^))
}
export mapLsEntry(fields, e) {
    let i = Iter.from(e);
    record.fromEntries(Iter.zip(fields, i).chain( restToChildren(mapLsEntry(fields, ?), i)) )
}

makeFileQuery(path, opts) {
    // calculate fields: must be identifier, @name is always added and should be the first
    const fields = Iter.seq(opts?.fields ?? @size).flatMap(s => ident(s) ?? (:)).filterFalse(f=>f==@name).prepend(@name).toTuple();
    return (@ls, path, #{...(opts??#{}), fields}), fields;
}
export async queryFiles(messenger, path, opts) {
    const query, fields = makeFileQuery(path, opts);
    let res = ?? ... await queryInfo(messenger, query);
    res && mapLsEntry(fields, res);
}

export mapLsFlat(fields, e, nameFunc) {
    const epath = nameFunc(e[0]);
    let i = Iter.from(e);
    const rec =  record.fromEntries(Iter.zip(fields, i).append((@path, epath)));
    i.flatMap(mapLsFlat(fields, ?, joinPath(epath, ?))).prepend(rec);
}

export async queryFilesFlat(messenger, path, opts) {
    const query, fields = makeFileQuery(path, opts);
    let res = ?? ... await queryInfo(messenger, query);
    res && mapLsFlat(fields, res, always(path)).toArray();
}

export procCheckSumMsg(msg) {
    const r = DataReader(msg.data);
    r.u8();
    const methodId = r.u8();
    const method = checksumMethod?.[methodId];
    if (!method)
        return #{ status: Response.UnknownParam};
    const reqId = msg.requestId;
    const fname = r.string();
    const from = r.vlu();
    const len = !r.finished ? r.vlu() : undef;
    return #{file:fname, reqId : msg.requestId, method, from, len};
}

export queryChecksum(messenger, fileName, method, from=0, len=undef) { // async
    messenger.sendRequest(w => {
        w.u8(Message.CheckSum);
        w.u8(method);
        w.string(fileName);
        w.vlu(from);
        if (len) w.vlu(len);
    }, (r,s) => {
        s == 0 ? Uint8Array(r.subarray(r.pos)) : failure("checksum failed", s); // must copy
    });
}

export responseFailString(r, status) {
    status ? (r.string() ?? "fail") : undef;
}

export responseString(r, status) {
    status == 0 ? r.string() : ?? responseAsFail(r, status)
}

export responseAsFail(r, status) {
    if (status == 0) return true;
    failure(r.string() ?? "failed", status);
}

export responseDataOrFail(r, status) { // extract data subarray or fail string
    if (status != 0)
        return failure(r.string() ?? "fail", !r.finished ? r.vli() : undef);
    // TODO: should not need separate subarray
    r.subarray(r.pos); // no need to copy, r expected to be own data
}

export getSmallFile(messenger, fileName, from=0, len=0) { // async
    messenger.sendRequest(w => {
        w.u8(Message.GetFile).string(fileName);
        w.vlu(from).vlu(len)
    }, responseDataOrFail);
}

// simple filesystem request via messenger, with given failename. Additional parameters can be written by given rest func
// async function returns string on failure or undef on success
export requestFsOperation(messenger, type, fileName, rest) { // async
    messenger.sendRequest(w => {
        w.u8(type).string(fileName);
        rest?.(w)
    }, responseAsFail);
}