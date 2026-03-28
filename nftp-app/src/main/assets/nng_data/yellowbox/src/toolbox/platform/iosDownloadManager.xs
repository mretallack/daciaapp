/// [module] app://downloadManager
import * as objc from "system://objc"
import {@objcProto} from "uie/darwin/objc_support.xs"
import {Map, Uint8Array, Storage} from "system://core.types"
import {ensureParentDirSync, resolveFileUri} from "system://fs"
import { encode } from "system://web.URI"
import {propOr} from "core://functional"
import * as fs from "system://fs"
import {yellowBoxAppDelegate} from "~/src/service/ios/appDelegate.xs"
import {getFailObject} from "system://core"
import {networkStatusModule} from "./iosNetworkStatus.xs"

const NSURLSession = objc.class.NSURLSession;
const NSURLSessionConfiguration = objc.class.NSURLSessionConfiguration;
const NSFileManager = objc.class.NSFileManager;
const NSError = objc.class.NSError;
const NSURL = objc.class.NSURL;
const NSMutableURLRequest = objc.class.NSMutableURLRequest;
// TODO: proper directory
const NSDocumentDirectory = 9;
const NSUserDomainMask = 1;
const NSURLErrorCancelled = -999;
const NSURLSessionDownloadTaskResumeData = "NSURLSessionDownloadTaskResumeData";

const downloadDirUrl = NSFileManager.defaultManager.URLForDirectory_inDomain_appropriateForURL(NSDocumentDirectory, NSUserDomainMask, undef, false, undef);
export const downloadDirectory = resolveFileUri(downloadDirUrl.absoluteString);

enum SessionType {
    foreground,
    background,
}

const DownloadDelegateDesc = objc.ClassDesc()
         // [NSURLSessionDelegate](https://developer.apple.com/documentation/foundation/nsurlsessiondelegate?language=objc)
          .addMethod("URLSessionDidFinishEventsForBackgroundURLSession:", 'v@:@', @didFinishEventsForBackgroundURLSession)
          // [NSURLSessionTaskDelegate]   
          .addMethod("URLSession:task:didCompleteWithError:", "v@:@@@", @taskDidCompleteWithError)
          // [NSURLSessionDownloadDelegate](https://developer.apple.com/documentation/foundation/nsurlsessiondownloaddelegate?language=objc)
          // task-level events specific to download tasks
          .addMethod("URLSession:downloadTask:didFinishDownloadingToURL:", 'v@:@@@', @didFinish)
          .addMethod("URLSession:downloadTask:didWriteData:totalBytesWritten:totalBytesExpectedToWrite:", "v@:@@qqq", @didWriteData)
          .build();

@objcProto(DownloadDelegateDesc)
class DownloadModule {
    #subs;
    foregroundSession = undef;
    backgroundSession = undef;
    downloads = new Map();
    completedDownloads = new Storage("downloadManager-ios-completed");
    @dispose #netStatusSubs;

    constructor() {
        this.#netStatusSubs = networkStatusModule.subscribe((netStatus) => {
            this.#maintainDownloads(netStatus);
        });
    }

    initSession() {
        if (this.foregroundSession && this.backgroundSession) return;
        console.log("Init NSURLSession.");
        const fgConfig = NSURLSessionConfiguration.defaultSessionConfiguration;
        fgConfig.sessionSendsLaunchEvents = true;
        fgConfig.discretionary = false;
        this.foregroundSession = NSURLSession.sessionWithConfiguration_delegate(fgConfig, this, undef);
        const bgConfig = NSURLSessionConfiguration.backgroundSessionConfigurationWithIdentifier("DownloadSession");
        bgConfig.sessionSendsLaunchEvents = true;
        bgConfig.discretionary = false;
        this.backgroundSession = NSURLSession.sessionWithConfiguration_delegate(bgConfig, this, undef);
        this.#subs = yellowBoxAppDelegate.getEvent().subscribe((name) => {
            if (name == @AppGoToBackground) {
                this.#moveTasksBetweenSessions(this.foregroundSession, this.backgroundSession);
            }
            if (name == @AppGoToForeground) {
                this.#moveTasksBetweenSessions(this.backgroundSession, this.foregroundSession);
            }
        });
    }

    enqueue(uri, destinationSubPath, options={allowMetered:true}) {
        this.initSession();
        const fileName = downloadDirUrl.URLByAppendingPathComponent(destinationSubPath).absoluteString;
        const removeRes = ??fs.removeSync(fileName);
        ensureParentDirSync(fileName);

        const url = NSURL.URLWithString(encode(uri));
        const request = NSMutableURLRequest.requestWithURL(url);
        const allowsCellularAccess = propOr(true, @allowMetered, options);
        request.allowsCellularAccess = allowsCellularAccess;
        const task = this.foregroundSession.downloadTaskWithRequest(request);
        const id = task.taskIdentifier;
        const element = {id, task, allowsCellularAccess, totalSize:1, progress:0, status:"pending", fileName, sessionType:SessionType.foreground};
        this.downloads.set(id, element);
        this.completedDownloads.removeItem(string(id));
        const netStatus = networkStatusModule.getStatus();
        if (canDownload(element, netStatus)) { 
            this.#startDownload(element);
        }
        return id;
    }

    query(id) {
        this.downloads.get(id) ?? this.completedDownloads.getItem(string(id)) ?? undef;
    }

    remove(id) {
        let res = false;
        if (const element = ?? this.downloads.getAndRemove(id)) {
            element.task.cancel();
            console.log(`download task cancelled: ${element.id}`);
            res = true;
        }
        if (const element = ?? this.completedDownloads.getItem(string(id))) {
            this.completedDownloads.removeItem(string(id));
            res = fs.removeSync(element.fileName);
            console.log(`file removed: ${element.fileName}`);
        }
        return res;
    }

    didFinishEventsForBackgroundURLSession(session) {
        // TODO: maybe check whether all tasks are fininshed, or check session identifier
        // getTasksWithCompletionHandler -> downloadTasks count is 0
        const completionHanlder = yellowBoxAppDelegate.bgCompletionHandler;
        yellowBoxAppDelegate.bgCompletionHandler = undef;
        completionHanlder?.();
        console.log("All download task finished in background session.");
    }
    
    taskDidCompleteWithError(session, task, error) {
        if (error == undef) return;
        const err = getFailObject(??error);
        if (err.code == NSURLErrorCancelled) return;

        const element = this.#getElement(session, task);
        if (!element) return; // skip removed elements
        const resumeData = err?.userInfo?.[NSURLSessionDownloadTaskResumeData];
        if (resumeData) {
            element.status = "paused";
            element.resumeData = resumeData;
            this.downloads.set(element.id, element);
            console.log(`download task paused: ${string(element.id)}`);
            return;
        }
        console.error(`[error][${element.id}] ${error}`);
        element.status = "failed";
        this.downloads.set(element.id, element);
        persistDownloadState(this.completedDownloads, element.id, element);
    }

    didFinish(session, downloadTask, location){
        const element = this.#getElement(session, downloadTask);
        if (!element) return; // skip removed elements
        if (downloadTask.response.statusCode >= 200 && downloadTask.response.statusCode < 299) {
            element.status = "success";
            // let res, outErr = NSFileManager.defaultManager.moveItemAtPath(from, to, objc.outarg);
            const res = copyFile(location.absoluteString, element.fileName);
            if (!res) {
                element.status = "failed";
                console.error("[error] failed to move file");
                // console.error(`[error] ${outErr}`);
            }
        } else {
            element.status = "failed";
        }
        this.downloads.set(element.id, element);
        persistDownloadState(this.completedDownloads, element.id, element);
    }

    didWriteData(session, downloadTask, bytesWritten, totalBytesWritten, totalBytesExpectedToWrite) {
        const element = this.#getElement(session, downloadTask);
        if (!element) return; // skip removed elements
        const MB = 1024 * 1024;
        const STEP = 1 * MB;
        if (element.progress == 0 || totalBytesWritten > element.progress + STEP || totalBytesWritten == totalBytesExpectedToWrite) {
            // console.warn(`[${element.id}] ${totalBytesWritten/MB}/${totalBytesExpectedToWrite/MB} MB`);
            element.totalSize = totalBytesExpectedToWrite;
            element.progress = totalBytesWritten;
            this.downloads.set(element.id, element);
            // TODO: send updated progress
        }
    }

    #moveTasksBetweenSessions(fromSession, toSession) {
        const getTasksCB = objc.makeBlock("v@?@@@", (dataTasks, uploadTasks, downloadTasks) => {
            for (const oldTask in downloadTasks) {
                const element = this.#getElement(fromSession, oldTask);
                if (!element) return; // skip removed elements
                const resumeDataCB = objc.makeBlock("v@?@", (resumeData) => {
                    if (!resumeData) return;
                    this.#initDownloadWithResumeData(toSession, resumeData, element);
                    this.#startDownload(element);
                });
                oldTask.cancelByProducingResumeData(resumeDataCB);
            }
        });
        fromSession.getTasksWithCompletionHandler(getTasksCB)
    }

    #getSessionType(session) {
        return (session == this.foregroundSession) ? SessionType.foreground : SessionType.background;
    }

    #getElement(session, task) {
        const sessionType = this.#getSessionType(session);
        for (const id,element in this.downloads) {
            if (element.sessionType == sessionType && element.task.taskIdentifier == task.taskIdentifier)
                return element;
        }
        console.warn("missing", sessionType==SessionType.foreground?"foreground":"background", "element", task.taskIdentifier);
    }

    #maintainDownloads(netStatus) {
        for (const id,element in this.downloads) {
            const possible = canDownload(element, netStatus);
            if (possible && element.status == "pending") {
                this.#startDownload(element);
            }
            if (element.status == "paused") {
                if (element?.resumeData) {
                    console.log(`download task resumed: ${string(element.id)}`);
                    this.#initDownloadWithResumeData(this.foregroundSession, element.resumeData, element);
                    if (possible) this.#startDownload(element);
                } else {
                    element.status = "failed";
                    this.downloads.set(element.id, element);
                    persistDownloadState(this.completedDownloads, element.id, element);
                }
            }
        }
    }

    #startDownload(element) {
        element.status = "running";
        this.downloads.set(element.id, element);
        element.task.resume();
    }

    #initDownloadWithResumeData(session, resumeData, element) {
        if (!resumeData) return;
        element.task = session.downloadTaskWithResumeData(resumeData);
        element.status = "pending";
        element.sessionType = this.#getSessionType(session);
        this.downloads.set(element.id, element);
    }
}

@dispose
export DownloadModule downloadModule;

copyFile(from, to) {
    let inp = ??fs.openSync(from);
    if (!inp) {
        console.warn(inp);
        return false;
    }
    let f = ??fs.openSync(to,{write: true, truncate: true} );
    if (!f) {
        console.warn(f);
        return false;
    }
    let b = Uint8Array(16*1024);
    let sum = 0;
    while(true) {
        const n = ?? inp.readSync(b);
        if (!n)
            break;
        f.writeSync(b.subarray(0,n));
        sum += n;
    }
    f.close();
    inp.close();
    return true;
}

interface Options {
    allowMetered = true;
}

/// @param uri 
/// @param destinationSubPath
/// @param {Options} options download options
export enqueue(uri, destinationSubPath, options) {
    downloadModule.enqueue(uri, destinationSubPath, options);
}

export query(id) {
    downloadModule.query(id);
}

export remove(id) {
    downloadModule.remove(id);
}

persistDownloadState(storage, id, state) {
    storage.setItem(string(id), #{ totalSize: state.totalSize, progress: state.progress, status: state.status, fileName:state.fileName });
    console.log(`download task completed: ${string(id)} - ${state.status}`);
}

canDownload(requestOptions, networkStatus) {
    return networkStatus.internet && (requestOptions.allowsCellularAccess || !networkStatus.metered);
}
