import {statSync} from "system://fs"
import {Message, responseFailString, queryChecksum, ChecksumMethod, PushOptions, queryFilesFlat, queryInfo} from "core/nftp.xs"
import {DataWriter, Set} from "system://core.types"
import {failure, hasProp, getFailObject, entries, dispose, typeof} from "system://core"
import * as iter from "system://itertools";
import { CancellationTokenSource, onChange} from "system://core.observe"
import * as path from "system://fs.path"
import {compareChecksum} from "~/src/utils/box.xs"
import {CompareResult} from "./headUnitContentCache.xs"
import { @disposeNull } from "core/dispose.xs"
import {mapTypeCodeToPath} from "./fileMapping.xs"
import { i18n } from "system://i18n"
import {fmt} from "fmt/formatProvider.xs"

// Content updater flow:
//   - query available free space and list of installed content from YellowTool,  having map info (CID and contentversion would be nice)
//   - specify fileset to update (list of maps, pois, licenses). 
//     If the head unit has the same map installed (can be checked by computing md5 checksum, when headers and filesizes match), we don't have to update it 
//   - specify options (these have defaults) for the update: do we need backup on the phone? other?
//   - it may happen that there isn't enough free space to perform the update
//     - either this can be solved by backing up some of the old files to be replaced on the users phone (this can be performed even without confirmation)
//     - or this could be only solved by deleting some other content on the device (for ex. if all the maps/pois are new)
//     - or the number of files to update could be shortened, or the transfer cancelled
//   - prepare for transfer (stop igo remount fs, etc.), store the progress of the update in memory. If an update is unfinished after app restart we can compute the list of the files which need update
//   - perform update. Repeat for all files:
//     1. When backup on phone needed and older map exists on the head unit: copy backup of old file to HU (with md5 check)
//     2. Pushfile: `filename.new` -> `/navi/content/map/filename.fbl.new.part` while transferring, `filename.fbl.new` after transfer finished
//     3. Rename old file, when present. When renaming `filename.fbl.old`
//     4. Checksum check on new file
//       * When checksum matches rename new file to `filename.fbl`. Delete old file
//       * If checksum fails: notify user? Retry, or Not. If not retrying, keep old file (rename back to `filename.fbl`). Otherwise go back to step 2
//   - finish transfer (remount fs as readonly and start iGO), remove session identifier
//   - hope that new content is working
//   - what happens with the downloaded content on the user's phone? Ask user if he/she wants to delete it, or keep it?

// Resuming broken transfer:
//   - An unique transfer session id should be stored on the headunit. Also details of the transfer session should be saved in yellowBox.
//   - When there is a `.part` file, we can try to resume the transfer from that point (first checking md5 sum of the part and the corresponding file in yellowbox)
//   - If there's no part file, resume transfer based on the stored session's progress (I think this is unlikely, that transfer breaks at that point)

//  Tasks
//  ======
//  - ContentUpdater should store the status of the current update flow (including progress and info texts)
//  - Implement content backup con yellowbox side
//  - We should be able to cancel an update (use cancelation token)

interface UpdaterDelegate {
    /// @param newFiles list of UploadItems which will be newly placed on device, some of them could be removed by the user
    /// @param candidatesToRemove list of contents on the device, which could be removed to free up space (excludeing those which will be updated)
    /// @returns a Promise of an object with the following properties:
    ///          - solved: if the free space problem could be solved
    //           - removedFiles: if the problem could be solved by removing this items from the files (this have to be from newFiles list)
    async freeSpaceNeeded(neededSpace, newFiles, candidatesToRemove) {}
    /// @returns retry: true if the upload should be tried again. Maybe @cancel could mean to stop the whole upload?
    async uploadFailed(reason, item, destPath, retryAttempts) {}
    /// Notify delegate about successful upload 
    uploadSuccess(item, destPath) { }
    /// @returns force: true if an already uploaded file have to upload again
    async alreadyUploaded(uploadItem) {}
    /// @returns targetPath:
    mapFileToPath(filename) {}
}

interface UploadItem {
    fileName;  // fileName of the item, like Germany.fbl
    path;      // full path to the item on yellowbox side
    targetPath?; // optional path where to place the file on yellowtool side
    contentTypeCode?; // content type code get from the server
    size?;       // file size (may be filled by ContentUpdater) 
    md5?;        // md5 checksum of file
    mtimeMs?;    // modification timestamp
}

interface ToolInfo {
    fileDB;     // an object with ContentCacheHU interface. gives access to the file db of the device, 
                // can refresh md5 hashs etc.
    freeSpace; // freeSpace
}

progressLogger(progress, messenger) {
    onChange(()=> { progress.total ? int(progress.value*100L/progress.total) : -1 }).subscribe(
        percent => { if (percent >= 0) queryInfo(messenger, (@log, `[synctool]P${percent}`)); });
}

export class ContentUpdater {
    @disposeNull #delegate;
    @disposeNull #messenger;
    @disposeNull #files;
    #toolInfo;
    progress = odict {
        value = 0; // value is in range [0, total]
        total = 0; // total bytes to transfer
        text = "";      // status text to display 
    }
    @dispose progressLogger;

    #needToDelete;
    #cToken;

    set toolInfo( info ){ this.#toolInfo = info }
    
    /// @param {UploadItem[]} files 
    constructor(delegate, messenger, toolInfo, ctoken) {
        this.#delegate = delegate;
        this.#messenger = messenger;
        this.#toolInfo = toolInfo;
        this.#needToDelete = false;
        this.#cToken = ctoken;
    }

    // Updates a parameter of the toolInfo, used for updating the freeSpace
    continueUpdate( toolInfo, messenger, cToken ) {
        for ( let k,v in entries( toolInfo ) )
            if ( this.#toolInfo?.[k] )
                 this.#toolInfo[ k ] = v;

        if (this.progressLogger) {
            dispose(this.progressLogger);
            this.progressLogger = progressLogger(this.progress, messenger);
        }

        this.#messenger = messenger;
        this.#cToken = cToken;
    }

    /// Compare files on YellowBox and Yellowtool, and don't upload matching files again. (except force update)
    /// Keep file order, remove duplicates and remove already uploaded files
    async filterNewFiles(files, progress) {
        if (progress) {
            progress.total = progress.value = 0;
            progress.text = i18n`Computing update...`;
        }
        const contents = this.getToolContent();

        const uniqueSet = new Set;
        const uniqueFiles = [];
        for (const file in files) {
            if (uniqueSet.has(file.fileName)) continue;
            uniqueSet.add(file.fileName);
            uniqueFiles.push({file, toUpload: false});
        }

        const tasks = iter.map(uniqueFiles, async data => {
            const item = data.file;
            const filePath = targetPath(this.#delegate, item);
            const content = contents.get(filePath) ?? undef;
            if (!content) {
                data.toUpload = true;
            } else {
                if (progress) ++progress.total;
                
                const cRes = contents.compare(filePath, item);
                let match = cRes == CompareResult.Same;
                if (cRes == CompareResult.NotSure) {
                    if (progress) progress.text = fmt(i18n`Checking {0}`, item.fileName);
                    // Note: side effect of compareChecksum: item.md5 and item.mtimeMs are updated
                    match = await compareChecksum(this.#messenger, item, filePath);
                    if (match) contents.set( filePath, { size: item.size, md5: item.md5, mtimeMs: item.mtimeMs });
                }
                let forceUpdate = false;
                if (match) forceUpdate = await this.#delegate.alreadyUploaded(item);
                if (!match || forceUpdate) {
                    data.toUpload = true;
                }
                if (progress) ++progress.value;
            }
        });
        await Promise.all(tasks);
        this.#files = [];
        for (const data in uniqueFiles) {
            if (data.toUpload)
                this.#files.push(data.file);
        }
        return this.#files;
    }

    async update(files, options) {
        const updateChecker = new ContentUpdateChecker(this.#delegate, this.#toolInfo);
        const result = await updateChecker.checkUpdate(files, undef, options);
        if (!result.updatePossible)
            return;
        this.#files = result.files;
        this.#needToDelete = result.needToDelete;
        dispose(this.progressLogger);
        this.progressLogger = undef;
        let total = 0L;
        await this.filterNewFiles(this.#files, this.progress);
        if (!this.#files.length) // nothing to do
            return; 

        this.progressLogger = progressLogger(this.progress, this.#messenger);

        for (const item in this.#files) {
            total += item.size;
        }
        const progress = this.progress;
        progress.value = 0L;
        progress.total = total;
        progress.text = i18n`Starting...`;
        const messenger = this.#messenger;
        await messenger.sendSimpleMessage(Message.PrepareForTransfer);
        
        const haveToCancel = ()=> {
            if (!this.#cToken?.canceled) return false;
            progress.total = 0L;
            progress.text = "";
            messenger.sendSimpleMessage(Message.TransferFinished);
            return true;
        };
        
        for (const item in this.#files) {
            if (haveToCancel()) return @canceled;
            const originalDestPath = targetPath(this.#delegate, item);
            if (!originalDestPath) { // skip upload if it can't be placed, error will be reported by xs automatically
                progress.value += item?.size ?? statSync(item.path).size;
                continue;
            }
            const destPath = `${originalDestPath}.new`;

            if (this.#needToDelete) {
                const contents = this.getToolContent();
                const filePath = targetPath(this.#delegate, item);
                if (contents.get(filePath) ?? undef) {
                    let res = await this.writeFsReq(Message.DeleteFile, originalDestPath, w=>w.u8(1)); // @recursive
                    if (res != undef) {
                        // todo: retry again?
                        console.warn(`Removing ${filePath} failed`);
                        continue;
                    }
                }
            }

            const uploadStartOffset = progress.value;
            let retry;
            let retryAttempts = 0;
            do {
                retry = false;
                progress.value = uploadStartOffset;
                let res = ?? await this.uploadFile(item, destPath, this.#cToken);
                if (haveToCancel()) return @canceled;
                let err = typeof( res ) == @failure ? getFailObject( res ) : res;
                if ( err != undef ) {
                    console.log(`Xfer of ${item.fileName} failed: ${res}`);
                    progress.text = ``;
                    retry = await this.#delegate.uploadFailed(@transfer, item, destPath, retryAttempts);
                } else {
                    const match = await compareChecksum(this.#messenger, item, destPath);
                    if (match) {
                        res = await this.writeFsReq(Message.RenameFile, destPath, w=>w.string(originalDestPath));
                        if (res == undef) {
                            console.log(`Uploading ${item.fileName}: succeded`);
                            this.#delegate.uploadSuccess(item, originalDestPath);
                            // refresh md5 checksum for the uploaded file
                            const fileInfo = await queryFilesFlat(this.#messenger, originalDestPath, {fields: (@name, @size, @isFile, @mtimeMs)});
                            if (fileInfo?.[0]) { // should have only this entry
                                this.#toolInfo.fileDB.set( originalDestPath, { md5: item.md5, size: fileInfo[0].size, mtimeMs: fileInfo[0].mtimeMs })
                            }
                        } else {
                            console.log(`Renaming ${item.fileName}: failed with ${res}`);
                            retry = await this.#delegate.uploadFailed(@rename, item, destPath, retryAttempts);
                        }
                    } else {
                        retry = await this.#delegate.uploadFailed(@checksum, item, destPath, retryAttempts);
                    }
                }
                if (haveToCancel()) return @canceled;
                ++retryAttempts;
            } while (retry)
        }
        ?? await messenger.sendSimpleMessage(Message.TransferFinished);
        // todo: check whether dispose is really needed, in this form this breaks progress display in yellowtool, after resume
        dispose(this.progressLogger);
        this.progressLogger = undef;
        progress.text = "";
    }

    async comparePartChecksum(item, destItem, destPath) {
        // check md5 checksum of transferred file
        const localHash = this.#messenger.conn.md5(item.path,0, destItem.size).then(res => res.hexstr());
        const targetHash = destItem.md5 ?? queryChecksum(this.#messenger, destPath, ChecksumMethod.MD5).then(res => res.hexstr()??res);
        const sums = await Promise.allSettled((localHash, targetHash));
        if (sums[0].status != @fulfilled || sums[1].status != @fulfilled)
            return false;
        return sums[0].value == sums[1].value;
    }

    getToolContent() {
        this.#toolInfo.fileDB;
    }
    setToolContent(contents) {
        // todo: this shouldn't be needed, check usages
        //       instead fileDB should be refreshed
    }
    setFreeSpace(freeSpace) {
        this.#toolInfo.freeSpace = freeSpace;
    }

    writeFsReq(type, fileName, rest) { // async
        this.#messenger.sendRequest(w => {
            w.u8(type).string(fileName);
            rest?.(w)
        }, responseFailString);
    }

    async uploadFile(item, destPath, ctoken) {
        const progress = this.progress;
        const messenger = this.#messenger;
        const conn = messenger.conn;
        if (!conn)
            return "not connected";
        let fromOffset = 0;
        if (const p = ??this.#toolInfo.fileDB.get(`${destPath}.part`)) {
            if (await this.comparePartChecksum(item, p, `${destPath}.part`)) {
                fromOffset = p.size;
                progress.value += fromOffset;
            }
        }

        const w = DataWriter();
        w.u8(Message.PushFile);      // message type
        // todo: yellowtool should start to process <destPath>.part and when successfull
        w.string(destPath);
        w.u8(0); // length of additional data, nothing yet
        if (fromOffset) {
            const xstart = w.pos;
            w.vlu(PushOptions.UsePartFile);
            w.vlu(fromOffset);
            w.u8At(xstart-1, w.pos - xstart);
        }

        // todo: we could map filename based on extension, like: `Map of Germany`, or `Places in Germany`
        progress.text = fmt(i18n`Uploading {0}`, item.fileName);
        const uploadStartOffset = progress.value;
        
        const requestId = conn.nextRequestId();
        const tokenSubs = ctoken.subscribe(()=> conn.cancelSend(requestId));
        let res = messenger.asyncResponse(requestId, responseFailString);
        let sendRes = conn.sendWithFile(
            #{
                type:@request, 
                requestId, 
                data:w.subarray(0, w.pos)
            }, 
            item.path,
            fromOffset,
            sent => {
                progress.value = uploadStartOffset + sent;
            } 
        );
        //messenger.conn.enableSend(requestId, false); await Chrono.delay(10s);  messenger.conn.enableSend(requestId, true);
        sendRes = ?? await sendRes;
        if (!sendRes) 
            console.log`Failed to send ${item.fileName}: ${getFailObject(sendRes).message ?? "Unknown error"}`;
            
        return ??res;
    }
    
    /// fileNames is a list of file names to remove (like "germany.fbl"). Location on the device will be computed based on extension (and file name in rare cases)
    async removeFromDevice(contents) {
        const messenger = this.#messenger;
        await messenger.sendSimpleMessage(Message.PrepareForTransfer);
        let success = true;
        for (const c in contents) {
            let res = await this.writeFsReq(Message.DeleteFile, c.path);
            if (res != undef) {
                console.error(`Deleting ${c.path} failed: ${res}`);
                success = false;
            } else 
                console.log(`Removing ${c.path}: succeded`);
        }
        await messenger.sendSimpleMessage(Message.TransferFinished);
        return success;
    }
}

/// Compute the target path (relative to navi folder) for an upload item, when it's not given
/// based on it's extension
targetPath(delegate, uploadItem) {
    if (uploadItem?.targetPath)
        return uploadItem.targetPath;
    // TODO: add mapContentToPath to delegate
    const cPath = mapTypeCodeToPath(uploadItem);
    if (cPath)
        return cPath;
    const fpath = delegate.mapFileToPath( uploadItem.fileName );
    if (!fpath) 
        return failure(`Cannot devise target path for ${uploadItem.fileName}`);
    return fpath;
}

export class ContentUpdateChecker {
    @disposeNull #delegate;
    #toolInfo;

    constructor(delegate, toolInfo) {
        this.#delegate = delegate;
        this.#toolInfo = toolInfo;
    }

    setFreeSpace(freeSpace) {
        this.#toolInfo.freeSpace = freeSpace;
    }

    /// Checks is the update is possible
    /// When not possible it can ask delegate what to do...
    async checkUpdate(toUpload, toRemove, options) {
        let spaceFromDelete = 0L;
        const removeSet = new Set;
        for (const item in toRemove ?? []) {
            if (removeSet.has(item.path)) continue;
            removeSet.add(item.path);
            spaceFromDelete += item.size;
        }

        const uploadSet = new Set;
        let files = [];
        for (const item in toUpload ?? []) {
            if (uploadSet.has(item.fileName)) continue;
            uploadSet.add(item.fileName);
            if (!hasProp(item, @size))
                item.size = statSync(item.path).size;
            files.push(item);
        }

        const contents = this.#toolInfo.fileDB;
        let spaceNeededForUpdate = 0L; // the size of largest item which will be updated (so much extra space is needed on the device)
        let spaceDiffAfterUpdate = 0L; // the difference in space occupied by files after they are updated (ex. updated maps are slighly larger)
        let spaceNeededForNewContent = 0L;
        const newFiles = []; // list of new files to be uploaded
        for (const item in files) {
            const filePath = targetPath(this.#delegate, item);
            const content = contents.get(filePath) ?? undef;
            if (!content || removeSet.has(filePath)) {
                // no content or will be deleted
                spaceNeededForNewContent += item.size;
                newFiles.push(item);
            } else { 
                if (spaceNeededForUpdate < item.size) {
                    spaceNeededForUpdate = int64(item.size);
                }
                spaceDiffAfterUpdate += item.size - content.size;
            }
        }
        
        const freeSpace = this.#toolInfo.freeSpace;
        const MINIMUM_SPACE = 512 * 1024; // keep 512kb free on the device 
        const freeSpaceAfterUpdate = freeSpace - spaceDiffAfterUpdate - spaceNeededForNewContent + spaceFromDelete;
        
        let updatePossible = true;
        let needToDelete = false;
        if (freeSpaceAfterUpdate < MINIMUM_SPACE) {
            // todo: compute list of contents which won't be updated
            const candidatesToRemove = [];
            const response = await this.#delegate.freeSpaceNeeded(MINIMUM_SPACE - freeSpaceAfterUpdate, newFiles, candidatesToRemove);
            updatePossible = response.solved;
            if (response?.removedFiles) {
                files = iter.filter(files, item => response.removedFiles.find(rf => rf.fileName == item.fileName)).toArray()
            }
        } else if (freeSpace - spaceNeededForUpdate < MINIMUM_SPACE) {
            // files can't be updated without backing them up on the phone
            // todo: at least one file can't be updated this way, so backup should be turned on in settings
            if (options.deleteOld) {
                needToDelete = true;
            } else {
                const candidatesToRemove = [];
                const response = await this.#delegate.freeSpaceNeeded(MINIMUM_SPACE - (freeSpace - spaceNeededForUpdate), newFiles, candidatesToRemove);
                updatePossible = response.solved;
            }
        }
        return {files, updatePossible, needToDelete}
    }
}
