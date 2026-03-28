import {formatSize} from "~/src/utils/util.xs"
import {packageDb, contentDb, createPackageFromRight} from "./packageAndContent.xs"
import {createPackageViewForDownload, createPackageViewForTransfer, createPackageViewForRemoval, PackageView} from "./packageView.xs"
import {downloads, DownloadStatus} from "~/src/toolbox/download.xs"
import {list, Set, Map} from "system://core.types"
import {bundleChanges} from "core://observe"
import {getContentsforPackage} from "app://yellowbox.updateApi"
import {checkContentsTransferred} from "~/src/toolbox/headUnitContentCache.xs"
import * as iter from "system://itertools"
import { map } from "system://functional"
import {downloadLicenses} from "~/src/utils/box.xs"
import {languages} from "~/src/utils/languages.xs"
import {headUnit} from "~/src/toolbox/connections.xs"
import * as networkStatus from "~/src/toolbox/networkStatus.xs"
import {transferSelection} from "./transferSelection.xs"
import {values, getOrElse} from "system://core"
import {ContentTypeCodes} from "~/src/service/datamodel.xs"
import { @disposeNull} from "core/dispose.xs"
import {packageList} from "~/src/service/packages.xs"

// Remaining tasks
// ==============
// - update fileDb in filterNewFiles in updater.xs (see todo at line 116)

/// Keeps a list of purchased package viewModels for the current device
/// This list will refresh:
/// - when a new package is purchased
/// - when a new device is connected
export class PackageManager {
    #packageDb;
    #contentDb;
    #downloads;
    #device; // the current device used by the package manager, it is not necessarily connected to the phone (via USB for ex.)
    packages = list[];
    updateRightsInProgress = false;
    packagesAreOutdated;
    packagesChanged = 0;
    transferType := transferSelection.contentType; 
    @dispose #langChangeSubs;
    @dispose #netChangeSubs;
    #countryGroupingPrio;
    @disposeNull #languages;
    hasUpdate = false;

    constructor(packageDatabase, contentDatabase, downloadsInstance, groupingPrio, diagParams = { languages: languages }) {
        this.#packageDb = packageDatabase ?? packageDb;
        this.#contentDb = contentDatabase ?? contentDb;
        this.#downloads = downloadsInstance ?? downloads;
        this.#countryGroupingPrio = groupingPrio ?? countryGroupingPrio;
        this.#languages = diagParams.languages;
        // resume downloads, and and update packageDb on download success
        const resumedDownloads = this.#downloads.resumeDownloads();
        for (const dl in resumedDownloads ?? []) {
            let subs;
            subs = dl.onComplete.subscribe((download, finalDownload) => {
                subs.cancel();
                this.onContentDownloadFinished(download);
            });
        }
        this.#langChangeSubs = this.#languages.subscribeLangChange( ( lang ) => { this.#onLangChange( { lastDevice: this.#device } ) });
        this.#netChangeSubs = networkStatus.subscribe((status) => {
            if (status?.internet) 
                if ( this.packagesAreOutdated )
                    this.updatePackagesFromRights( { refreshRights: true });
                if( this.#languages.langCode != this.#languages.serverLangCode )
                    this.#onLangChange( { lastDevice: this.#device } );
        });
        console.log("[PackageManager] PackageManager is ready." );
    }
    
    async setDevice(device) {
        const deviceChanged = this.#device.swid != device.swid;
        this.#device = device;
        this.packagesAreOutdated = this.#packageDb.isOutdated( this.#device.uuid ?? undef ) ?? true;
        // will refresh each time, as device may be reconnected
        this.refresh({ deviceChanged: deviceChanged });
        if (device) {
            await this.updatePackagesFromRights({ refreshRights: true, mockDevice: device?.mockDevice ? device : undef });
            this.#syncDownloadProgress();
            console.log("[PackageManager] set device for PackageManager. Swid: ", device?.swid );
        }
    }
    
    refresh(options) {
        if (options?.deviceChanged) {
            this.packages.clear();
            transferSelection.clear( @deviceChanged );
        }
        if (!this.#device)
            return;
        if (options?.deviceChanged) {
            const packagesForDevice = this.#packageDb.packagesByDevice.get(this.#device.uuid) ?? [];
            for (const pack in packagesForDevice) {
                this.#addPackage(pack);
            }
        }    
        
        for ( let packageVm in this.packages ) {
            this.createDownloadPackageView( packageVm, options?.forceRefreshPackages );
            if ( packageVm.downloadedByUser && packageVm.downloadedSize > 0)
                this.createTransferPackageView(packageVm);
            // todo: when device fileDb is ready, also double checks transfer status (it's fast, but not so good)
            packageVm.updateTransferStatus(this.#device.fileDB); 
        }
        this.packagesChanged++;
        console.log("[PackageManager] Refreshed." );
    }
    
    purchasePackage( package, forDevice ) {
        if (forDevice != this.#device) {
            console.warn("[PackageManager] Attempt to purchase a package for a different device");
            return;
        }
        const pack = this.#packageDb.purchasePackage(package, forDevice);
        if (!pack) return;
        this.#addPackage(pack);
    }

    createDownloadPackageView(packageVm, forceRefresh ) {
        if (!packageVm.downloadView || forceRefresh ) {
            packageVm.downloadView = new PackageView(createPackageViewForDownload(packageVm, #{ contentDb: this.#contentDb, deviceFiles:this.#device.fileDB, countryGroupingPrio: this.#countryGroupingPrio }));        
            // select all elements by default
            for (const e in packageVm.downloadView.entries) 
                if (!e.downloaded) e.selected = true;
            //console.log("[PackageManager] download package view created. PackageCode: ", packageVm.package.packageCode );
        }
        // probably should check whether the view has to be updated or not...
    }

    createTransferPackageView(packageVm, withSyncTS = true ) {
        if (!packageVm.transferView) {
            for (const c in packageVm.package.contents) {
                // Content without countryCode is grouped into `Other files`
                const isMandatory = c?.igoCountryCode ? false : true;
                if (isMandatory) {
                    const downloaded = this.#contentDb.getFilePath(c);
                    if (!downloaded) return;
                }
            }
            packageVm.transferView = new PackageView( createPackageViewForTransfer(packageVm, #{ contentDb: this.#contentDb, deviceFiles:this.#device.fileDB, countryGroupingPrio: this.#countryGroupingPrio }));
            //console.log("[PackageManager] transfer package view created. PackageCode: ", packageVm.package.packageCode );
            // Update transferView entries' queue status and refresh transferSelection 
            if ( withSyncTS )
                transferSelection.syncEntries(packageVm.package, packageVm.transferView);
            packageVm.transferView.enabled = transferSelection.isCompatible( packageVm.package );
        }
    }

    createRemovePackageView(packageVm) {
        if (!packageVm.removeView) {
            packageVm.removeView = new PackageView(createPackageViewForRemoval( packageVm, #{ contentDb: this.#contentDb, deviceFiles: this.#device.fileDB, countryGroupingPrio: this.#countryGroupingPrio }));
            packageVm.removeView.selectAll();
            //console.log("[PackageManager] remove package view created. PackageCode: ", packageVm.package.packageCode );
        }
    }
    
    /// Creates a new viewmodel for pack and adds it to the packages list
    #addPackage(pack) {
        const packageVm = new PackageVM(pack);
        packageVm.updateDownloadStatus(this.#contentDb);
        this.packages.push(packageVm);
        return packageVm;
    }

    /// will check the rights of the associated device, and add missing purchased packages to the packageDb if needed
    /// if the device has no rights downloaded yet, it will attempt to do so
    /// @param options optional named arguments
    ///   - refreshRights: refresh device rights (ex. after a purchase is completed)
    async updatePackagesFromRights(options) {
        if ( ?? !this.#device  )
            return;
        this.updateRightsInProgress = true;
        const device = this.#device;

        let getRightsSucces = false;
        if (!device.rights || options?.refreshRights) {
            getRightsSucces = await device.getRights(); 
        }
        if( !??device.rights.length ){
            console.log("[PackageManager] No rights available for the device: ", device?.swid );
            this.updateRightsInProgress = false;
            return;
        }

        const toRemove = [];
        for ( const package in this.packages ) {
            const haveRight = device.rights.find( e =>{ e.packageCode == package.package.packageCode } );
            if(!haveRight) toRemove.push(package);
        };
        for (const package in toRemove) {
            this.packages.remove( this.packages.indexOf(package) );
            this.#packageDb.removePackage( package, device );
            console.log("[PackageManager] Updating packages from rights. Package removed: ", package.package.packageCode );
        }

        let newPackagesAvailable = false;
        let forceRefreshPackages = false;
        const outdatedPackages = [];
        for ( const right in this.#getBestRights() ){
           const packIndex = this.packages.findIndex( e =>{ right.packageCode == e.package.packageCode } );
                let pack = createPackageFromRight( right, device, this.#packageDb );
                const justUpdated = packIndex >=0 && pack.snapshot.snapshotCode != this.packages[packIndex].package.snapshot.snapshotCode;
                if( packIndex == -1 || justUpdated || this.packagesAreOutdated || !this.packages[packIndex].package.contents || this.packages[packIndex].package.needRefresh()){
                    if ( options?.mockDevice )
                        ??await options?.mockDevice?._getContentsforPackage( pack, true );
                    else
                        ??await getContentsforPackage( pack, true );
                    if( packIndex != -1 ) {
                        pack.additionalInfo.downloadedByUser = this.packages[packIndex].downloadedByUser;
                        this.packages[packIndex].package = pack;
                    }
                    forceRefreshPackages ||= justUpdated;
                }
                else
                    pack = this.packages[packIndex].package;
                if (packIndex == -1) {
                    this.purchasePackage(pack, device);
                    newPackagesAvailable = true;
                } else {
                    let outdated = this.#packageDb.refreshPackageContentsAndGetOutdated(pack, device, this.#contentDb);
                    if ( justUpdated )
                        outdatedPackages.push( { vm: this.packages[packIndex], outdated });
                }
        }

        if ( getRightsSucces )
            this.#packageDb.updateVersion( this.#device.uuid );
            this.packagesAreOutdated = this.#packageDb.isOutdated( this.#device.uuid ?? undef ) ?? true;

        if( this.#languages.langCode != this.#languages.serverLangCode ){
            await this.#onLangChange({ getRights: !getRightsSucces });
        } else {
            // Description must be updated, because multiple rigths can point to the same snapshot
            // TODO: can the content list change with the more expensive rights?
            await this.refreshPackagesDescriptions({ getRights: !getRightsSucces });
        }

        if (newPackagesAvailable || outdatedPackages.length ) {
            console.log("[PackageManager] Updating packages from rights. New packages are available. Trying to download licenses." );
            await downloadLicenses(device);
        }
        
        this.handleOutdatedContents( outdatedPackages );
        this.refresh({forceRefreshPackages});
        this.updateRightsInProgress = false;
        this.hasUpdate = this.packages.findIndex( e=> e.package.updated) >=0;
        this.packagesChanged++;
        packageList.setPackageListProperties();
    }

    handleOutdatedContents( data ){
    	const cDb = this.#contentDb;
        const affectedInTS = [];
        const refreshFunc = (vm) => { 
            vm.updateDownloadStatus(this.#contentDb); 
            vm.transferView = undef; 
            if ( vm.downloadedByUser && vm.downloadedSize > 0 ) this.createTransferPackageView( vm, false );
            else vm.downloadedByUser = false; 
        };
        const removeFunc = ( vm, contents ) => { 
            if ( contents.length ) {
                const md5s = Set.from(iter.map( e=>e.md5, contents )); 
                this.deleteContents( false, vm, md5s );
            } else {
                refreshFunc( vm );
                if (vm.transferView?.entries?.length)
                    transferSelection.syncEntries(vm.package, vm.transferView);
                else
                    transferSelection.removePackage(vm.package);
            }	
        };
        for ( const d in data ){
            if ( !d.vm?.transferView ) continue;

            const inTS = transferSelection.packages.get( d.vm.package.packageCode ) ?? false;
            if ( !inTS && !d.outdated.length ) {
                refreshFunc( d.vm );
                continue;
            }
            const checkList = iter.map( d.outdated, e=> object extends e { 
                downloaded = cDb.getFilePath(e) ? true : false;
                inTransferSelection = transferSelection.hasContent(e);
            }).toArray();
          
            const onlyDownloaded =  iter.filter( checkList, e=> e.downloaded && !e.inTransferSelection ).toArray();
            if ( onlyDownloaded.length )
                removeFunc( d.vm, onlyDownloaded );

            const inTSContents = iter.filter( checkList,  e=> e.inTransferSelection ).toArray();
            if ( inTS ) {
                affectedInTS.push( { vm: d.vm, contents: inTSContents } );
            }
        }
        if ( affectedInTS.length )
            transferSelection.outdatedFilesFound( 
                affectedInTS, 
                _ => iter.forEach( e=>{ removeFunc( e.vm, e.contents )}, affectedInTS), 
                _ => iter.forEach( e=>{ refreshFunc( e.vm )}, affectedInTS) 
            )
     }

    // Filter the rights list by the latest expiration date
    #getBestRights( options ) {
        const normalizedRights = {};
        const device = this.#device ?? options?.lastDevice;
        iter.forEach( device.rights , right => {
            let r = normalizedRights?.[ right.packageCode ];
            normalizedRights[ right.packageCode ] = ( r.expire ?? -1 ) < (right.expire ?? 0) ? right : r;
        });

        return values( normalizedRights );
    }

	async #onLangChange( options ){
		let success = await this.refreshPackagesDescriptions( options );
		if(success) {
			this.#languages.serverLangCode = this.#languages.langCode;
            console.log("[PackageManager] packages are refreshed after language change");
        } else 
            console.warn("[PackageManager] Failed to refresh packages after language change");
	}

    //return true if the getRights() was successfuly.
    async refreshPackagesDescriptions( options ){
        const device = this.#device ?? options?.lastDevice;
        let getRightsSuccess = !options?.getRights;
        if ( ?? !device )
            return false;
        if( options?.getRights ?? true )
            getRightsSuccess = await device.getRights(); 
        if( getRightsSuccess ){
            this.updateRightsInProgress = true;
            for ( const right in this.#getBestRights()){
                let pack = createPackageFromRight( right, device, this.#packageDb );
                this.#packageDb.refreshPackageData( pack, device );
            }
            this.updateRightsInProgress = false;
            return true;
        } else 
            return false
    }

    /// Call this method after the package list is refreshed
    /// If there are any ongoing downloads this will update the corresponding packageModels with downloaders
    #syncDownloadProgress() {
        const ongoingDownloads = this.#downloads.list;
        if (ongoingDownloads.length == 0) 
            return;
        const downloadsByMd5 = new Map();
        for (const download in ongoingDownloads)    
            downloadsByMd5.set(download.expectedMd5, download);
        for (const pack in this.packages) {
            if (!pack.downloadView || !pack.downloadedByUser)
                continue;
            const packageDownloader = new PackageDownloader(pack, this.#contentDb, this.#downloads, this);
            packageDownloader.startFromDownloadList(downloadsByMd5); // it will attach itself to pack when needed
        }
    }

    onStartDownloadingPackage(packageVm, info=#{downloadedByUser: true}) {
        for (const pack in this.packages) {
            if (pack == packageVm) {
                pack.downloadedByUser = info?.downloadedByUser;
                pack.package.updated = false;   // update tag is only visible until the first download
                this.hasUpdate = this.packages.findIndex( e=> e.package.updated) >=0;
                this.#packageDb.refreshPackageData( pack.package, this.#device );
                this.#packageDb.save();
                return;
            }
        };
    }
    
    /// external important events download manager should be aware of
    /// We started downloading c
    onStartDownloadingContent(c) {
        for (const pack in this.packages) 
            pack.downloadView?.onDownloadStatusChanged(c.md5, @started);
    }
    
    /// Download is finished, either because it has been completed or it has failed
    onContentDownloadFinished(download) {
        // mark and save each time that the file for this download with the given md5 is downloaded
        this.#contentDb.contentWithMd5Downloaded(download);
        const state = (download.status == DownloadStatus.Success ? @success : ( download.status == DownloadStatus.Canceled ? @canceled : @failed ));
        const md5 = download.localMd5;
        for (const pack in this.packages) {
            const entry = pack.downloadView?.onDownloadStatusChanged(download.expectedMd5, state);
            // transferView has to be updated, when a content in this package has been downloaded
            if ( (state == @success || state == @canceled ) && pack.downloadedByUser && entry && !entry.downloading) {
                pack.transferView = undef;
                this.createTransferPackageView(pack);
                pack.removeView = undef;
                this.#packageDb.refreshPackageData( pack.package, this.#device );
            }
        }
        this.packagesChanged++;
    }

    checkOverlappingContentsForRemoval( packageToRemove, contentList ){
        const md5Set = Set.from( iter.map(c => c.md5, contentList));
        const toRemove, overlappingMd5s, overlappingMandatory, overlappingCountries, affectedPackages = new Set(), new Set(), new Set(), new Set(), new Set;
        for (const pack in this.packages) {
            if ( pack.package == packageToRemove.package || !pack.transferView ) continue;
            for (const entry in pack.transferView.entries) {
                for ( const c in entry.contents )
                    if (md5Set.has(c.md5)) {
                        console.log("overlapping content found: ", c.fileName, " in package ", pack.package.name);
                        if (entry.mandatory) {
                            console.log("skipping overlapping mandatory content: ", c.fileName);
                            overlappingMandatory.add(c.md5);
                        }
                        else { 
                            overlappingMd5s.add(c.md5);
                            overlappingCountries.add( entry.name );
                            affectedPackages.add( pack );
                        }
                    }                    
            }
        }
        for (const md5 in md5Set){
            if (!overlappingMd5s.has(md5) && !overlappingMandatory.has(md5))
                toRemove.add(md5);
        }
        return {toRemove, overlappingCountries, affectedPackages, overlappingMd5s};
    }

    deleteContents( allSelected, currentPack, md5s ) {
        for ( const c in md5s ) {
            this.#contentDb.removeContentByMd5(c);
        }
        if ( allSelected ){
            currentPack.downloadedByUser = false;    //because of overlapping mandatory files
        }
        this.#refreshPackagesAfterRemove(md5s); 
        if (currentPack.transferView?.entries?.length)
            transferSelection.syncEntries(currentPack.package, currentPack.transferView);
        else {
            transferSelection.removePackage(currentPack.package, md5s);
        }
    }

    #refreshPackagesAfterRemove( removedMd5s ){
        bundleChanges( ()=>{
            for ( const pack in this.packages ){    //we need to refresh all owned packages due to possible overlapping contents
                console.log( "[packages] Updating package after content deletion: ", pack.package.name );
                pack.updateDownloadStatus(this.#contentDb);
                pack.downloadView.onContentsRemoved(removedMd5s);
                pack.transferView = undef;
                pack.removeView = undef;
                if ( pack.downloadedByUser && pack.downloadedSize > 0) {
                    this.createTransferPackageView(pack);
                } else {
                    pack.downloadedByUser = false;
                }
                this.#packageDb.refreshPackageData( pack.package, this.#device );
            }
            this.packagesChanged++;
        })
    }

    onChange transferType(){
        if ( !this?.packages ) return;
        for ( let p in this.packages ){
            if (p.transferView)
                p.transferView.enabled = transferSelection.isCompatible( p.package );
        }
    }
        
}

export const countryGroupingPrio = [ ContentTypeCodes.Map, ContentTypeCodes.Poi , ContentTypeCodes.Tmc, ContentTypeCodes.Speedcam, ContentTypeCodes.Lang ];

@dispose
export PackageManager packageManager;

/// Package ViewModel for a given package
/// Some states aren't automatically updated (like downloadedSize and transferred)
/// This should be done when after initializeing, after refreshing contents on device etc.
export class PackageVM {
    package;
    downloadedSize = -1; // -1 means unknown
    
    transferred = false; // is it fully transferred to the associated device
    
    get fullyDownloaded() { this.downloadedSize == this.package.fullSize }
    get formattedSize() { formatSize(this.package.fullSize) }
    get name() { this.package.name }
    
    view; // associated transient packageView, use createPackageView family of functions to populate
    downloadView;
    transferView;
    removeView;
    downloader; // associated transient download

    get downloadedByUser() { this.package.additionalInfo.downloadedByUser ?? false }
    set downloadedByUser( val ) { this.package.additionalInfo.downloadedByUser = val }

    constructor(package) {
        this.package = package;
        if ( this.fullyDownloaded )
            this.downloadedByUser = true;
    }
    
    updateDownloadStatus(contentDb) {
        let downloaded = 0L;
        if (this.package.contents) {
            for (const c in this.package.contents) {
                const downloadedPath = contentDb.getFilePath(c);
                if (!downloadedPath) continue;
                downloaded += c.size;
            }
        }
        this.downloadedSize = downloaded;
        if ( this.fullyDownloaded )
            this.downloadedByUser = true;
    }
    
    updateTransferStatus(deviceFileDb) {
        this.transferred = checkContentsTransferred(deviceFileDb, this.package.contents);
        // if this vm has a transferView attached, refresh the state of entries here
        iter.forEach( this.transferView.entries ?? [], e => {
            e.updateTransferStatus(deviceFileDb);
        });

        iter.forEach( this.downloadView.entries ?? [], e => {
            e.updateDownloadStatus(deviceFileDb);
        });
    }
    
    downloadFinished(downloader) {
        this.updateDownloadStatus(downloader.contentDb);
        this.downloader = undef;
    }
}

export class PackageDownloader {
    packageVm; // downloader is attached to this viewModel
    contentDb; // will refresh contentDb after successfull download
    downloads; // can be changed for testing
    packageManager; // can be changed for testing
    #downloadItems;
    #finishedItemsCount;
    canceled;

    total = -1; // total download size
    get progress() { this.#computeDownloadProgress() }
    get downloadFinished() { this.#finishedItemsCount >= this.#downloadItems.length }
    get downloadedItems() { return iter.filter(this.#downloadItems, d=>{d.status == DownloadStatus.Success}) }

    constructor(packageVm, contentDatabase, downloadManager, packageManagerInstance) {
        this.packageVm = weak(packageVm);
        this.contentDb = contentDatabase ?? contentDb;
        this.downloads = downloadManager ?? downloads;
        this.packageManager = packageManagerInstance ?? packageManager;
    }

    /// @param contents iterable list of contents to download
    startDownloadingByUser(contents) {
    	console.log( "[packageDownloader] Start downloading contents.");
        this.#initDownload();
        return new Promise( ( resolve ) => {
            for (const c in contents) {
                const download = this.downloads.add(c.downloadLocation, c.localFileName, #{expectedMd5: c.md5});
                this.#queueDownload(download, c, ()=> {
                    if (this.downloadFinished) {
                        resolve();
                    }
                });
            }
            if (this.#downloadItems.length > 0) { // only attach when any download has started
                this.packageVm.downloader = this;
                this.packageManager.onStartDownloadingPackage(this.packageVm, #{downloadedByUser: true});
            }
        });
    }

    cancelDownloading() {
        this.canceled = true;
        bundleChanges( () => {
            // TODO: cancel many downloads at once
            // it is not efficient to do it one by one for every subscriptions
            for (const download in this.#downloadItems) {
                this.downloads.cancel(download);
            }
        });
    }

    #initDownload() {
        this.#downloadItems = list.of();
        this.total = 0L;
        this.#finishedItemsCount = 0;
        this.canceled = false;
    }

    /// queue this download for the given content in our list of downloads and update state (like total size of download and so on)
    #queueDownload(download, content, onComplete) {
        this.packageManager.onStartDownloadingContent(content);
        if ( this.canceled )
            return;
        console.log( `[packageDownloader][${string(download.id)}] Queue download: ${content.fileName}`);
        this.total += content.size;
        this.#downloadItems.push(download);
        
        let onCompleteSub;
        onCompleteSub = download.onComplete.subscribe(()=>{
            onCompleteSub.cancel();
            this.#finishedItemsCount++;
            if (download.status == DownloadStatus.Success) {
                this.contentDb.contentDownloaded(content, download);
            }
            else { // failed or canceled
                // todo: register download failure if any
            }
            this.packageManager.onContentDownloadFinished(download);
            
            if (this.downloadFinished) {
                this.packageVm.downloadFinished(this);
            }
            // call user's onComplete
            onComplete?.();
        });
    }
    
    /// If there are any ongoing downloads which affect the contents of the attached package (intersects with them)
    /// this downloader will track the state of these items and populate its own list of downloads.
    /// @param ongoingDownloadsByMd5 the list of ongoing downloads mapped by their expected md5 hash
    // todo: handle cancellation for resumed downloads (cannot be canceled now)
    startFromDownloadList(ongoingDownloadsByMd5) {
        this.#initDownload();
        const contents = this.packageVm.package.contents;
        for (const c in contents) {
            const download = ??ongoingDownloadsByMd5.get(c.md5);
            if (download)
                this.#queueDownload(download, c);
        }
        if (this.#downloadItems.length > 0) {// only attach when any download has started
            console.log("[packageDownloader] Resume pending downloads. (", this.#downloadItems.length, " items)");
            this.packageVm.downloader = this;  
        }  
    }
    
    #computeDownloadProgress() {
        let progress=0L;
        for (const download in this.#downloadItems) {
            if ( download.progress >= 0) progress += download.progress;
        }
        return progress;
    }
}
