/// [module] app://downloadManager
import {Map, Storage} from "system://core.types"
import {typeof} from "system://core"
import {statSync, ensureParentDirSync, removeSync, renameSync} from "system://fs"
import * as path from "system://fs.path"
import env from "system://app.env"
import {spawn} from "system://childProcess"
import * as networkStatus from "android-mocks/networkStatus.xs"

// Tasks
// =====
// - persist details of ongoing downloads
// - onStart/init (either onstart or on the first interaction) will check for interrupted downloads and restart them with curl (resuming them would be better)
// - when a download completes it will be persisted in the completed state as well  to return filename and sizes

const windowsHide = true;
const limitRate = "";
// const limitRate = "1M";

const data = {
    // NOTE: using string values in sysconfig, as int64 not supported...
    nextId: int64(SysConfig.get("downloadManagerWindows", "nextId", "1")),
    downloads: new Map(),
    completeHandler: undef,
    downloadTasks: new ThrottledTasks(5), // max 5 concurrent downloads,
    // persisted state of downloads, running downloads are consulted only when manager is initalized
    // completed downloads are stored "forever", so they can be consulted whenever a query is requested with an unknown id
    runningDownloads: new Storage("downloadManager-win-running"),
    completedDownloads: new Storage("downloadManager-win-completed"),
};

export const downloadDirectory = SysConfig.get("downloadManager", "downloads", `${env.USERPROFILE ?? env.HOME}/.yellowbox/downloads`);

const step = 5_000_000;

interface Options {
    allowMetered = true;
}

/// @param uri 
/// @param destinationSubPath
/// @param {Options} options download options
export enqueue(uri, destinationSubPath, options={allowMetered: true}) {
    const id = data.nextId++;
    SysConfig.set("downloadManagerWindows", "nextId", string(data.nextId));
    const filePath = generateFilePath(destinationSubPath, id);
    ensureParentDirSync(filePath);
    // remove file if already exists, before  download starts
    const removeRes = ??removeSync(filePath);
    const element = {id, totalSize: 1, progress: 0, status: "pending", fileName: filePath, url: uri };
    data.downloads.set(id, element);
    persistDownloadState(data.runningDownloads, id, element);
    
    data.downloadTasks.run(id, async ()=> {
        element.status = "running";
        await checkNetworkStatus(options);
        const size = await queryFileSize(uri);
        element.totalSize = size;
        persistDownloadState(data.runningDownloads, id, element);
        const args = ["-o", filePath];
        if (limitRate) args.push("--limit-rate", limitRate);
        element.proc = spawn("curl", ...args, uri, #{windowsHide});
        const res = await element.proc.status;
        downloadProcessCompleted(res, element);
    });
    
    return id;    
}

downloadProcessCompleted(res, element) {
    element.completed = true;
    element.status = res == 0 ? "success" : "failed";
    element.progress = res == 0 ? element.totalSize : 0; 
    element.proc = undef;
    data.runningDownloads.removeItem(string(element.id));
    if (element.status != "success") {
        const removeRes = ??removeSync(element.fileName);
    }
    persistDownloadState(data.completedDownloads, element.id, element);
    data.completeHandler?.(element.id, element.fileName);
}

export query(id) {
    if ( let element = data.downloads.get(id) ?? undef ) {
        if (!element?.completed) {
            element.progress = statSync(element.fileName)?.size ?? 0;
            persistDownloadState(data.runningDownloads, id, element);
        }
        return element;
    } else {
        // check inside already completed downloads
        const state = data.completedDownloads.getItem(string(id)) ?? undef;
        if (!state)
            return undef;
        return #{id, totalSize: state.totalSize, progress: state.progress, status: state.status, fileName:state.fileName, url: state.url}
    }
}

export remove(id) {
    const element = query(id);

    // remove from DB
    data.runningDownloads.removeItem(string(id));
    data.completedDownloads.removeItem(string(id));
    if (!element) {
        console.warn("no element found for id: ", id);
        return false;
    }

    const inQueue = data.downloadTasks.cancel(id);
    if (!inQueue) {
        async do {
            let inProcess = false;
            while (element.status == "running" && !inProcess) {
                // edge case when start to execute the task, but process is not started yet
                inProcess = await killProcess(element);
                if (!inProcess) await Chrono.delay(0.5s);
            }
            await removeFile(element, 5);
        };
    }

    return !??statSync(element.fileName);
}

async killProcess(element) {
    if (element?.proc) {
        ?? element.proc.kill(15);
        const win = await.race(element.proc.status, Chrono.delay(5s));
        return win;
    }
}

async removeFile(element, retryCount=1, delay=1s, maxDelay=5s) {
    for ( let try=1; try<=retryCount; try++ ) {
        let res = removeSync(element.fileName) || !??statSync(element.fileName);
        if (res) {
            console.warn("removing file succeeded: ", element.fileName, ", retry: ", try );
            break;
        } else {
            console.warn("removing file failed: ", element.fileName, ", retry: ", try, "res: ", res);
        }
        await Chrono.delay( delay );
        if (delay < maxDelay) delay *= 2;
    }
}

export onDownloadComplete(handler) {
    data.completeHandler = handler
}

checkNetworkStatus(options) {
    const canDownload = (status)=> { status.internet && (options?.allowMetered || !status.metered);};
    return new Promise(resolve => {
        const status = networkStatus.getStatus();
        if (canDownload(status)) { 
            resolve(status);
            return;
        }
        let onNetworkStatusSub;
        onNetworkStatusSub = networkStatus.subscribe((status) => {
            if (canDownload(status)) {
                onNetworkStatusSub.cancel();
                resolve(status);
            }
		});
    });
}

async queryFileSize(downloadUrl) {
    const proc = spawn("curl", "-sI", downloadUrl, #{stdout: @piped, windowsHide: true});
    const out = (await proc.output()).substr();
    const status = await proc.status;
    if (status != 0) return undef;

    const headerLength = "Content-Length:";
    const contentLenPos = out.indexOf(headerLength) + len(headerLength);
    const size = int64(out.substr(contentLenPos, out.indexOf("\n", contentLenPos) - contentLenPos));
    return size;
}

persistDownloadState(storage, id, state) {
    storage.setItem(string(id), #{ totalSize: state.totalSize, progress: state.progress, status: state.status, fileName:state.fileName, url: state.url });
    storage.save();
}

generateFilePath(destinationSubPath, id) {
    const dest = destinationSubPath;
    const fileName = path.filename(dest) + `-${string(id)}` + path.extname(dest);
    return path.join(downloadDirectory, path.dirname(dest), fileName);
}

@onStart
onStart() {
    // resume pending downloads from the storage
    for (const idStr, state in data.runningDownloads) {
        const id = int64(idStr);
        const element = { id, totalSize: state.totalSize, progress: state.progress, status: state.status, fileName: state.fileName, url: state.url };
        data.downloads.set(id, element);
        
        data.downloadTasks.run(id, async () => {
            // - Use "-C -" to tell curl to automatically find out where/how to resume the transfer.
            const args = ["-C", "-", "-o", state.fileName];
            if (limitRate) args.push("--limit-rate", limitRate);
            element.proc = spawn("curl", ...args, state.url, #{windowsHide});
            const res = await element.proc.status;
            downloadProcessCompleted(res, element);
        });
    }
}

// todo: this could be part of core modules async lib
/// ThrottledTasks is task executor limiting the number of maximum paralelly running concurrent tasks
/// Use it through the run(task) function, where task is a runnable returning a Promise
/// run will behave as you would have called simply `task()` but will ensure that only maxConcurrent instances run the same time.
class ThrottledTasks {
    #numRunning = 0
    #maxConcurrent;
    #queue = [];
    
    constructor(maxConcurrent = 16) { this.#maxConcurrent = maxConcurrent }

    run(id, task) {
        if (this.#numRunning < this.#maxConcurrent) {
            ++this.#numRunning;
            const result = task();
            result.finally(()=> this.#taskCompleted());
            return result
        } else return this.#queueTask(id, task)
    }

    cancel(id) {
        const size = this.#queue.length;
        this.#queue = Iter.filter(item => item.id != id, this.#queue).toArray();
        return size != this.#queue.length;
    }

    #queueTask(id, task) {
        return new Promise((resolve, reject) => {
            this.#queue.push(#{
                id, 
                task,
                resolve,
                reject
            })
        })
    }

    private #taskCompleted() {
        --this.#numRunning;
        if (this.#numRunning < this.#maxConcurrent && this.#queue.length > 0) {
            const next = this.#queue.shift();
            ++this.#numRunning;
            const result = next.task();
            result.then(next.resolve, next.reject);
            result.finally(()=> this.#taskCompleted())
        }
    }
}
