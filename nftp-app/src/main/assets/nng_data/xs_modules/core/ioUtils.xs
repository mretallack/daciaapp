import {Uint8Array,ArrayBuffer, DataReader} from "system://core.types"
import {typeof, failure} from "system://core"
import * as  digest from "system://digest"
import {open} from "system://fs"
import * as fs from "system://fs"

/*
 * const it = iterateReader(f, {
 *   bufSize: 1024 * 1024
 * });
 * for await (const chunk of it) {
 *   console.log(chunk);
 * }
 * f.close();
 * ```
 *
 * Iterator uses an internal buffer of fixed size for efficiency; it returns
 * a view on that buffer on each iteration. It is therefore caller's
 * responsibility to copy contents of the buffer if needed; otherwise the
 * next iteration will overwrite contents of previously returned chunk.
 */
const  DefaultBufferSize = 32 * 1024;
export async *iterateReader(r, options  /* bufSize:number*/ ) { // asyncinterable<Uint8Array
  const bufSize = options?.bufSize ?? DefaultBufferSize;
  const b = new Uint8Array(bufSize);
  while (true) {
    const result = (await r.read(b)) ?? -1;
    if (result == 0) continue;
    if (result < 0)
      break;

    yield b.subarray(0, result);
  }
}

export async readAll(r) {
    let buf = Uint8Array(32*1024);
    let n = (await r.read(buf)) ?? -1;
    if (n < 0) return Uint8Array(0);
    while(true) {
        if (n>=buf.length) {
            let nextBuf = Uint8Array(2*buf.length);
            nextBuf.set(buf);
            buf = nextBuf;
        }
        const nn = (await r.read(buf.subarray(n))) ?? -1;
        if (nn<0)
            break;
        n += nn;
    }
    buf.subarray(0,n);
}

getLineExtractor(cr, withLineEnd) {
    if (withLineEnd)
        return (data,last, pos) => data.substring(last, pos+1);
    else
        return (data, last, pos) => {
            if (last != pos && data[pos-1] == cr)
                --pos;
            data.substring(last, pos);
        };
}
export *lineIter(data /*buffer or string*/, withLineEnd=false) {
    let last = 0;
    const lf = typeof(data) == @string ? "\n" : 10;
    const lineExtractor = getLineExtractor(lf == 10 ? 13 : "\r", withLineEnd);
    while(true) {
        const pos = data.indexOf(lf, last);
        if (pos < 0)
            break;
        yield lineExtractor(data, last, pos);
        last = pos +1;
    }
    if (last != data.length)
        yield data.substring(last);
}

export async *lineReader(r, withLineEnd=false) {
    let buf = Uint8Array(32*1024);
    const lineExtractor = getLineExtractor(13, withLineEnd);
    let n = (await r.read(buf)) ?? -1;
    if (n < 0) return;
    while(true) {
        let last = 0;
        let nn = n < buf.length ? r.read(buf.subarray(n)) : undef; // schedule next read if we have space but don't await it
        let data = buf.subarray(0,n);
        while(last < data.length) {
            const pos = data.indexOf(10, last);
            if (pos < 0)
                break;
            yield lineExtractor(data, last, pos);
            last = pos+1;
        }
        if (nn) {
            nn = (await nn) ?? -1;
            if (nn < 0) { // no more data
                if (last != n)
                        yield buf.substring(last,n);
                break;
            }
            n += nn;
        }
        else if (!last) { // the entire 32K buffer has been filled and no lineterminator has been found.
            yield buf.substring(0, n); // return entire buffer, very unlikely that a text file contains line with more than 32k characters, later this can be fixed if needed
            last = n;
        }
        if (last) {
            buf.copyWithin(0, last, n);
            n -= last;
        }
    }
}

export async* readFile(fileName, from=0, len=0) {
    if (len == 0)
        len = -1;
    let buf = DataReader(64*1024);
    let nbuf = DataReader(64*1024);
    const f = ?? await open(fileName);
    if (!f)
        return f;
    if (from) {
        const res = await f.seek(from);
        if (!res) return res;
    }
    let n = ?? await f.read(len >= 0 && len < buf.byteLength ? buf.subarray(0,len) : buf);
    if (!n) return n == undef ? true : n;
    while(true) {
        if (len >= 0)
            len -= n;
        let nn = len < 0 || len > 0 ? f.read(len > 0 && len < nbuf.byteLength ? nbuf.subarray(0,len) : nbuf) : undef; // schedule next read but don't await it
        yield n < buf.byteLength ? buf.subarray(0,n) : buf;
        if (len == 0)
            return true;
        n = ?? await nn;
        if (!n) 
            return n == undef ? true : n;
        const t= buf; buf=nbuf; nbuf=t;
    }
    return true;
}

export async checksum(fileName, methodName, from=0, len=0, blocks=0) {
    const method = digest?.[methodName];
    if (!method)
        return failure("no such digest method", methodName);
    let digest = new method();
    let result = undef;
    async function *wrapIt(it) {
        result=?? (yield* it);
    }

    for await (const b in wrapIt(readFile(fileName, from, len))) {
        digest.append(b);
    }
    result ? digest.result() : ??result;
}

export joinPath(dir, name) {
    if (!dir)
        name ? name : ".";
    else if (!name || dir.endsWith('/'))
        `${dir}${name}`;
    else
        `${dir}/${name}`
}

export dirName(path) {
    const idx = path.lastIndexOf('/');
    if (idx == 0) return "/";
    if (idx < 0) return ".";
    return path.substring(0, idx-1);
}
walkEntry(dirEntry, dirPath, fname) {
    if (!dirPath && fname)
        dirPath = dirName(fname);
    return object extends dirEntry {
        #path = fname;
        dirPath = dirPath;
        get name() { super.name ?? this.#path.substr(this.#path.lastIndexOf("/") + 1)}
        get path() { 
            if (this.#path == undef)
                this.#path = joinPath(this.dirPath, this.name);
            this.#path
        }
    }
}

// possible option could be { maxDepth, includeFiles, includeDirs, followSymlinks, exts, match, skip }?: WalkOptions)
export* walkSync(filename, opts) {
    const e = ?? fs.statSync(filename);
    if (!e)
        return e;
    yield walkEntry(e, undef, filename);
    if (e.isDirectory)
        yield* walkDirSync(filename, opts)
}

*walkDirSync(path, opts) {
    for(const e in fs.readDirSync(path)) {
        yield walkEntry(e, path);
        if (e.isDirectory)
            yield* walkDirSync(joinPath(path, e.name), opts);
    }
}