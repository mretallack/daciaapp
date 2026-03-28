import {headUnit, saveFile} from "./connections.xs"
import {ContentUpdater, ContentUpdateChecker} from "./updater.xs"
import {app} from "../app.xs"
import { @disposeNull } from "core/dispose.xs"
import { dispose } from "system://core"
import {state, Map, Set} from "system://core.types"
import { onChange } from "system://core.observe"
import {getLicensesFromBox, backupFolder, compareChecksum} from "../utils/box.xs"
import {queryInfo, queryFilesFlat} from "core/nftp.xs"
import CancellationTokenSource from "core/CancellationTokenSource.xs"
import {formatSize} from "../utils/util.xs"
import { Messagebox, Button} from "../components/messageboxes.xs"
import * as path from "system://fs.path"
import {remove, writeFile, statSync, readFileSync} from "system://fs"
import {Stream, Reader} from "system://serialization"
import {mapFileToPath} from "./fileMapping.xs"
import {packageManager} from "./packages/packageModel.xs"
import { i18n } from "system://i18n"
import {fmt} from "fmt/formatProvider.xs"
import { isOSMContent, getProviderByComment } from "./db/contentId.xs"
import {transferSelection} from "./packages/transferSelection.xs"
import {platform} from "system://os"

class FileTransferBase /* implement UpdaterDelegate */{
    @dispose updater;
    uploading = new CancellationTokenSource;
    onHUConnectionLost = event{};
    onHUConnectionRestored = event{};

    // DI only for tests
    @disposeNull headUnit;
    @disposeNull updaterClass;

    states = {
        prepare: "Preparing for upload",
        working: "Working...",
        finished: "Finished",
        suspended: "Suspended",
        spaceNeeded: "Not enough space",
        cancel: "Transfer canceled",
    };

    results = {
        default: { text: "", failed: false },
        success: { text: i18n`Map transfering finished. Enjoy your ride!`, failed: false },
        spaceNeeded: { text: "", failed: true }, // text will be determined on the fly
        lostConnection: { text: i18n`Connection closed`, failed: true },
        cancel: { text: i18n`Transfer canceled`, failed: true },
    };

    state;
    result; 

    constructor( hUnit, updaterClass ) {
        this.headUnit = hUnit ?? headUnit;
        this.updaterClass = updaterClass;
        this.state = this.states.prepare;
        this.result = this.results.default;
    }

    // updater delegate interface
    async freeSpaceNeeded(neededSpace, newFiles, candidatesToRemove) {
        this.result = this.results.spaceNeeded;
        this.result.text = i18n`Not enough free space on car!`;
        return #{solved: false}
    }

    failedToUpload() {
        this.result = this.results.spaceNeeded;
        this.result.text = i18n`Failed to transfer some of the files`;
        return #{solved: false}
    }

    // updater delegate interface
    async uploadFailed(reason, item, destPath, retryAttempts) {
        // todo: show dialog about error
        console.warn(`Uploading ${item.fileName} failed with ${reason}.`);
        let retry = this.headUnit.connected; // only retry automatically when connected
        if (!this.headUnit.connected) {
            this.result = this.results.lostConnection;
        } else if (retryAttempts >=5) {
            this.failedToUpload();
            retry = false;
        }
        return retry;
    }
    
    async uploadSuccess(item, destPath) {
        // todo: handle successful upload
        this.headUnit.device.fileDB.set(destPath, {md5: item.md5, size: item.size, mtimeMs: item.mtimeMs});
    }
    async alreadyUploaded(uploadItem) {}
}

/// Upload options set by the user
object uploadOptions {
    backup = false;
    /// true, when old content can be deleted before upload to get extra space. 
    /// Only used when freeSpace is low.
    deleteOld = true;
    forceUpdate = false;
}

export class FileTransferSession extends FileTransferBase {
    files = [];
    toRemove;
    @dispose observeHeadUnitConnection;
    
 
    async init( toUpload, toRemove ) {
        const toolInfo = await this.#getToolInfo();
        this.updater = 
            this.updaterClass ? new this.updaterClass( this, this.headUnit.messenger, toolInfo, this.uploading.token )
            : new ContentUpdater(this, this.headUnit.messenger, toolInfo, this.uploading.token);
        // NOTE: use updater.progress on the ui
        const licenses = [];
        // todo should we keep this here (adding licenses?)
        for (const item in getLicensesFromBox(this.headUnit.device)) {
            licenses.push({fileName: item.name, path: item.path, size: item.size});
        }
        this.files = [...licenses, ...toUpload];
        this.toRemove = toRemove;
        this.initEvents();
    }

    async #getToolInfo(){
        let t = await queryInfo(this.headUnit.messenger, @freeSpace);
        const content = await queryFilesFlat(this.headUnit.messenger, "content", {fields: (@name, @size)} );
        return { freeSpace: t[0], content, fileMapping: this.headUnit.fileMapping, fileDB: this.headUnit.device.fileDB };      
    }

    initEvents() {
         if ( !this.observeHeadUnitConnection )
            // The messenger is being observed because headUnit.connected is not enough. The messenger and a conencted are set at the same time.
            this.observeHeadUnitConnection = onChange( _ => this.headUnit?.messenger?.setupCompleted ?? false).subscribe( completed => {
                if ( completed )
                    this.onHUConnectionRestored.trigger();
                else
                    this.onHUConnectionLost.trigger();
            });
    }
    
    async transfer() {
        this.state = this.states.working;
        this.result = this.results.default;
        if ( this.toRemove?.length ) {
            await this.updater.removeFromDevice( this.toRemove );
            const info = await this.#getToolInfo();
            this.updater.toolInfo = info;
        }
        await this.updater.update(this.files, uploadOptions);
        if (this.uploading.canceled) {
            this.result = this.results.cancel;
            this.state = this.states.cancel;
        }
        elsif ( this.result.failed && this.result == this.results.lostConnection ) this.state = this.states.suspended;
        elsif (this.result.failed && this.result == this.results.spaceNeeded ) this.state = this.states.spaceNeeded; 
        else {
            this.state = this.states.finished;
            this.result = this.results.success;
        }
        this.uploading = undef;
        return this.result
    }

    async continueTransfer() {
        if ( this.state == this.states.suspended ) {
            this.uploading = new CancellationTokenSource;
            let t = await queryInfo(this.headUnit.messenger, @freeSpace);
            this.updater.continueUpdate({ freeSpace: t[0] }, this.headUnit.messenger, this.uploading.token );
            await this.transfer();
        }
        else
            console.log(`Transfer can't be continued as it is ${this.state}` );
    }

    cancelTransfer() {
        if ( this.uploading )
            this.uploading.cancel();
        elsif ( this.state == this.states.suspended ) {
            this.result = this.results.cancel;
            this.state = this.states.cancel;
        }
    }
        
    async alreadyUploaded(uploadItem) {
        console.log(`${uploadItem.fileName} was already uploaded.`);
        return uploadOptions.forceUpdate;
    }

    mapFileToPath(fileName) {
        return mapFileToPath( fileName, this.headUnit.fileMapping );
    }
}

async getFilelistAndSize(dir, initSize=0L) {
    const content = await queryFilesFlat(headUnit.messenger, dir, {fields: (@name, @size,@isFile, @mtimeMs)} );
    return (content, Iter.reduce(content, (sum, item) => item.isFile ? sum + item.size : sum, initSize));
}

async backupDir(bpath, content, progress, finished) {
    for(const item in content) {
        if (!item.isFile)
            continue;
        let retry=0;
        while(retry < 3) {
            console.log(`backing up ${item.path}`);
            progress.text = item.name;
            const locPath = path.join(bpath, item.path);
            await saveFile(item.path, locPath,  {progressCb(len) {progress.value += len }});
            const checkItem = { path: locPath, mtimeMs: item.mtimeMs, size:item.size };
            if (await compareChecksum(headUnit.messenger, checkItem, item.path)) {
                checkItem.path = item.path;
                finished.push( checkItem);
                break;
            }
            ++retry;
            progress.text = `${item.name}(${retry})`;
            console.log("Md5 failed: retrying");
        }
    }
}
export async backupFiles(prog) {
    if(!headUnit.device || !headUnit.connected) {
        console.log("Error: not connected");
        return false;
    }

    if (!prog) {
      prog = odict {
        value = 0; // value is in range [0, total]
        total = 0; // total bytes to transfer
        text = "";      // status text to display 
      };
    }
    const bpath = `${backupFolder}/${headUnit.device.swid}`;
    const dirs = ["content", "license"];
    const contents = [];
    let sumSize = 0L;
    for(const dir in dirs) {
        const r = await getFilelistAndSize(dir, sumSize);
        contents.push(r[0]);
        sumSize=r[1];
    }
    prog.total += sumSize;
    const filelist=[];
    console.log(`Backing up ${sumSize/(1024.0*1024)} megabytes`);
    for( const content in contents) {
        await backupDir(bpath, content, prog, filelist);
    }
    prog.text="";
    const s = Stream(@compact);
    s.add(filelist);
    writeFile(path.join(bpath,"filelist"), s.transfer());
    true;
}

export removeBackup(dev) {
    dev ??= headUnit.device;
    if(!dev) {
        console.log("No device info");
        return
    }
    const bpath = `${backupFolder}/${dev.swid}`;
    remove(bpath, @recursive);
}
export hasBackupForDevice(dev) {
    return dev && (statSync(`${backupFolder}/${dev.swid}/filelist`) ?? undef) ?.isFile;
}
export async restoreBackup(progress) {
    if(!headUnit.device || !headUnit.connected) {
        console.log("Error: not connected");
        return false;
    }

    if (progress)
        progress.text = i18n`Getting file list`;
    const bpath = `${backupFolder}/${headUnit.device.swid}`;
    const fl = readFileSync(path.join(bpath,"filelist"));
    if (!fl)
        return failure("Failed to read filelist");
    const filelist = Reader(fl).next();
    const byName  = new Map;
    const bpathLen = bpath.length + 1;
    for(const f in filelist) {
        let tpath = f.path;
        if (tpath.startsWith(bpath))
            tpath = f.path.substr(bpathLen);
        else
            f.path = path.join(bpath, tpath);
        f.targetPath = tpath;
        f.fileName = tpath;
        byName.set(tpath, f);
    }
    const dirs = ["content", "license"];
    const toRemove = [];
    const tcont = new Map;
    for(const dir in dirs) {
        const content = await queryFilesFlat(headUnit.messenger, dir, {fields: (@name, @size,@isFile, @mtimeMs)} );
        for(const c in content) {
            if (!c.isFile)
                continue;
            const bkup = byName.get(c.path) ?? undef;
            if (!bkup)
                toRemove.push( #{targetPath:c.path});
            else { // if (bkup.mtimeMs != c.mtimeMs || bkup.size != c.size byName.get(c.path))
                tcont.set(c.path, c);
            }
        }
    }

    const handler = new FileTransferBase;
    const updater =  new ContentUpdater(handler, headUnit.messenger, { freeSpace: 0}, handler.uploading.token );
    if (progress)
        updater.progress = progress;

    if (toRemove.length) {
        updater.progress.text = i18n`Deleting files`;
        await updater.removeFromDevice(toRemove);
    }
    updater.progress.text = i18n`Checking upload`;
    updater.setToolContent(tcont);
    updater.setFreeSpace((await queryInfo(headUnit.messenger, @freeSpace))[0]);

    await updater.update(filelist, #{ backup : false, deleteOld: true, forceUpdate: false});
}

export async refreshFreeSpaceOnHeadUnit( hUnit ) {
    const headUnit = hUnit ?? headUnit;
    if (!headUnit.connected) return;
    const info = await queryInfo(headUnit.messenger, @diskInfo);
    headUnit.freeDiskSize = info[0].available;
    headUnit.diskSize = info[0].size;    
    transferSelection.refreshUpdateChecker(#{freeSpace: headUnit.freeDiskSize});
}

export async syncAfterTransfer( attrs ) {
    await headUnit.device?.getContentsFromHU();
    let freeSpaceIsUpdated = false;
    if ( attrs?.deletePartFiles )
        freeSpaceIsUpdated = await headUnit.device?.removePartFilesFromHU();
    if ( !freeSpaceIsUpdated )
        await refreshFreeSpaceOnHeadUnit();
    packageManager.refresh();
}

export async buildFileTransfer( toUpload, toRemove ){
    const transferSession = new FileTransferSession;
    // todo: should handle duplicate contents (like common contents from EEU/WEU pack)
    //       what about conflicting contents? (like the same target file but with different versions)
    await transferSession.init( toUpload, toRemove );
    return transferSession;
}

export async removeFilesFromDevice(files) {
    // NOTE: passing headUnit as delegate to perform mapFileToPath op.
    //       would be better if this was extracted from contentUpdater
    const updater = new ContentUpdater(headUnit, headUnit.messenger);
    await updater.removeFromDevice( files );
    await refreshFreeSpaceOnHeadUnit();
}

// currentTransferType can be @osm or @here, otherwise will return an empty array
export getNonCompatibleFiles( currentTransferType ){
    const result = [];
    if (!headUnit.device || !headUnit.connected) {
        console.log("Error: not connected");
        return result;
    }
    if ( ![@osm, @here].includes( currentTransferType )) {
        return result;        
    }
    const fileDB = headUnit.device.fileDB;
    //const cond = currentTransferType == @osm ? ( cInfo, name ) => { !isOSMContent( cInfo, name ) } : ( cInfo, name ) => { isOSMContent( cInfo, name ) }; 
	for (const filePath in fileDB.keys) {
		const cache = fileDB.get(filePath) ?? undef;
        const baseName = path.basename(filePath) ?? undef;
		if (cache?.contentInfo && baseName != "Basemap.fbl" && !contentIsCompatible(currentTransferType, cache.contentInfo, baseName))
            result.push( #{ path: filePath, size: cache.size, md5: cache.md5 /*cInfo: cache.contentInfo*/ });
	}  
    return result;  
}

enum ContentTypeExtensions {
	Map = ".fbl",
	Poi = ".poi",
	Tmc = ".tmc",
	Speedcam = ".spc",
	AddressPoint = ".fpa",
    HouseNumber = ".hnr",
}

const excludedExtensionsFromCompatibilityCheck = Set.of( ContentTypeExtensions.Tmc );
const osmExcluderProviders = Set _ ["here", "nomago", "coltrack", "mapmyindia", "rahnegar", "gps_and_more"];
contentIsCompatible( transferType, cInfo, name ){
    if (!cInfo?.comment || excludedExtensionsFromCompatibilityCheck.includes( name.substr(-4,4) ))
        return true;
    const provider = getProviderByComment( cInfo.comment );
    if ( (transferType == @osm && osmExcluderProviders.has(provider)) || ( transferType == @here && isOSMContent( cInfo, name )) )
        return false;
    return true;
}

export class FileUploadProgress {
    @dispose transferSession;
    onFinished;
    @dispose onConnectionLost;
    @dispose onConnectionRestored;
    progressDialog;
    hasProgressDialog = false;
    noti;
    areYouSureShown;

    constructor(transferSession, onFinished) {
        this.transferSession = transferSession;
        this.onFinished = onFinished;

        this.onConnectionLost = this.transferSession.onHUConnectionLost.subscribe( _ => {
            this.onDisconnect();
        });
        this.onConnectionRestored = this.transferSession.onHUConnectionRestored.subscribe( _ => {
            this.onReconnect();
        });
        this.#createProgress(this.transferSession.updater.progress);
    }

    async startTransfer() {
        this.showProgress();
        const result = await this.transferSession.transfer();
        if ( headUnit?.connected )
            this.onUploadFinished(result);
    }

    #createProgress(progress) {
        let secLineText = i18n`Transfer in progress.\nPlease stay connected to your car!`;
        if ( platform == "ios" )
            secLineText = i18n`Transfer in progress.\nPlease stay connected to your car and keep the application running.`;
        this.progressDialog = new Messagebox; this.progressDialog
        .addLine(i18n`Uploading Files`)
        .addLine(secLineText)
        .addIcon("transfer_to_car.svg")
        .addButton( new Button({ text:i18n`Cancel`, style:@info, action: ()=>{ this.cancelUpload() } }))
        .setOverlay();
        this.progressDialog.progress = progress;
    }

    showProgress() {
        this.hasProgressDialog = true;
        this.progressDialog.show().then(_ => this.hasProgressDialog = false);
    }

    onDisconnect() {
        this.progressDialog.hide();
        this.noti = new Messagebox;
        this.noti.addLine(i18n`Your device has been diconnected!`)
        .addLine(i18n`Please reconnect to continue!`)
        .setOverlay()
        .addIcon( "sadface.svg" )
        .addButton( new Button({text:i18n`Abort`, style:@info, action: _=>{ this.areYouSure() }}))
        .show();
    }

    async onReconnect() {
        this.noti.hide();
        this.showProgress();
        await this.resumeTransfer();
    }

    async resumeTransfer() {
        const result = await this.transferSession.continueTransfer();
        if ( headUnit?.connected )
            this.onUploadFinished( result );
    }

    onUploadFinished( result ) {
        console.log(`Upload finished: ${string(result.text)}`);
        // todo: handle result, ex. canceled, broken etc.
        //        only mark transferred items which were really transferred
        if ( this.areYouSureShown ) {
            // after canceling the transfer, this method will be called 
            this.transferSession.state = this.transferSession.states.suspended;
        } else {
            // Not enough free space
            if ( this.transferSession.result == this.transferSession.results.spaceNeeded ) {
                // todo: should present choice to delete or skip  
                const noti = new Messagebox;
                noti.addLine( result.text )
                .addIcon( "msgbox_warning.svg")
                .setId( @transferFinished )
                .addButton( new Button({text:i18n`Ok`}));
                noti.show();
            } else {
                this.progressDialog.lines = [result.text];
            }
            this.onFinished();
        }
    }

    areYouSure() {
        this.areYouSureShown = true;
        this.noti = new Messagebox;
        this.noti.addLine(i18n`This will abort file transfer!`)
        .addLine(i18n`Are you sure?`)
        .setOverlay()
        .addIcon( "msgbox_warning.svg" )
        .addButton( new Button({text:i18n`Yes`, style:@info, action: _=> { this.areYouSureYes() }}))
        .addButton( new Button({text:i18n`No`, style:@info, action: _=> { this.areYouSureNo()  }}))
        .show();
	}

    areYouSureYes() {
       this.areYouSureShown = false;
       this.cancelUpload();
       this.onUploadFinished({ text: i18n`File Transfer Aborted!` });
    }

    areYouSureNo() {
        this.areYouSureShown = false;
        if ( headUnit?.connected )
            this.resumeTransfer();
        else
            this.onDisconnect();
    }

    // TODO: currently nobody calls it
    goBack() {
        if ( headUnit?.connected ) {
            // areYouSure messagebox on back in case of ongoing upload
            if ( this.transferSession.state == this.transferSession.states.working ) {
                this.suspendUpload();
                this.areYouSure();
            } 
            // areYouSure messagebox is shown
            else {
                this.noti.hide();
                this.areYouSureNo();
            }
        } else {
            // Are you sure messagebox shown
            if ( this.areYouSureShown ) {
                this.noti.hide();
                this.areYouSureNo();
            }
            // Disconnected messagebox shown
            else {
                this.noti.hide();
                this.areYouSure();
            }
        }
    }

    cancelUpload() {
        if(this.transferSession){
            this.transferSession.cancelTransfer();
            console.log("Cancel transfer pressed");
        }
    }

    suspendUpload() {
        this.areYouSureShown = true;
        this.transferSession.cancelTransfer();
        console.log("Suspend transfer pressed");
    }
}

class UpdateCheckerDelegate {
    async freeSpaceNeeded(neededSpace, newFiles, candidatesToRemove) {
        return #{solved: false}
    }

    mapFileToPath(fileName) {
        return mapFileToPath( fileName, headUnit.fileMapping );
    }
}

export class TransferChecker {
    #checker;
    isUpdatePossible;

    async refresh(selection, options) {
        const freeSpace = options?.freeSpace;
        if (!this.#checker) this.#checker = this.#buildUpdateChecker(freeSpace);
        this.#checker = await this.#checker;    // only await here to prevent multiple creation
        if (!this.#checker) return;
        if (freeSpace) {
            this.#checker.setFreeSpace(freeSpace);
        }
        this.#checkUpdatePossible(selection);
    }

    async #buildUpdateChecker(freeSpace) {
        if (!headUnit.connected) return undef;
        const delegate = new UpdateCheckerDelegate;
        if (!freeSpace) {
            freeSpace = await this.#queryFreeSpace();
        }
        const toolInfo = { freeSpace, fileDB: headUnit.device.fileDB };
        const updateChecker = new ContentUpdateChecker(delegate, toolInfo);
        return updateChecker;
    }

    async #queryFreeSpace() {
        let t = await queryInfo(headUnit.messenger, @freeSpace);
        return t[0]
    }

    async #checkUpdatePossible(selection) {
        const toUpload = selection.getUploadFiles();
        const toDelete  = selection.getNonCompatibleFiles();
        const result = await this.#checker.checkUpdate(toUpload, toDelete, uploadOptions);
        this.isUpdatePossible = result.updatePossible;
    }
}
