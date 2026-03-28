import {Map, Set} from "system://core.types"
import {buildFileTransfer, FileUploadProgress, getNonCompatibleFiles, syncAfterTransfer, TransferChecker} from "../contentManagament.xs"
import { map as funcMap } from "system://functional"
import {contentDb, mimesForSupplierDetection} from "./packageAndContent.xs"
import {packageManager} from "./packageModel.xs"
import {trackEvent} from "analytics/analytics.xs"
import {filter, unique, forEach, any, filterFalse} from "system://itertools"
import { Messagebox, Button } from "../../components/messageboxes.xs"
import {dispose} from "system://core"
import {deviceProgressDialog} from "~/src/toolbox/device.xs"
import {i18n} from "system://i18n"
import {gaEntries, gaSelectedEntries} from "~/src/service/googleAnalytics.xs"

class TransferSelection {
	packages = new Map;				// {name, packageCode, entries}
	showTransferElements = false;
	size = 0L;
	contentType = @none;	// @osm, @here, @none
	@dispose uploadProgress;
	_outdatedFunc = { removeFunc: undef, continueFunc: undef }; //TODO, SORRY, for testing
	#checker = new TransferChecker;

	get isUpdatePossible() {
		this.#checker.isUpdatePossible;
	}

	// #{freeSpace}: updated free space on HeadUnit
	refreshUpdateChecker(options) {
		this.#checker.refresh(this, options);
	}

	#calculateSize(){
		let size = 0L;
		const contentSet = new Set;
		for (const package in this.packages.values) {
			for ( const entry in package.entries ) {
				for ( const c in entry.contents ) {
					const md5 = c.md5;
					if (!contentSet.has(md5)) {
						contentSet.add(md5);
						size += c.size;
					}
				}
			}
		}
		this.refreshUpdateChecker();
		return size;
	}

	/// Update entries' selected&queued status based on transferSelection. And replace entries in the transferSelection.
	syncEntries(purchasedPackage, transferView) {
		const entries = transferView.entries;
		const packageCode = purchasedPackage.packageCode;
		const item = this.packages.get(packageCode) ?? undef;
		if (!item) return;

		const updatedEntries = [];
		const removedEntryNames = [];
		const prevSize = this.size;
		for (const e in item.entries) {
			const entry = entries.find(i => i.name==e.name);
			if (entry) {
				entry.queued = true;
				entry.selected = false;
				updatedEntries.push(entry);
			} else {
				removedEntryNames.push(e.name);
			}
		}
		this.packages.set(packageCode, {name: purchasedPackage.name, packageCode, entries: updatedEntries, supplierNames: purchasedPackage.snapshot.supplierNames});
		if (prevSize != this.size) console.log("[Maps] Sync transfer in package:", packageCode, "removed entries:", removedEntryNames.join(", ") );
		if (updatedEntries.length == 0) {
			this.removePackage(purchasedPackage);
		}
	}

	addEntries(package, entries) {
		if (!this.isCompatible( package )){
			if ( this.contentType == @osm )
				console.warn("[transfer] Warning! Trying to add non-osm package to an osm transfer! snapshotCode: ", package.right.snapshotCode );
			else
				console.warn("[transfer] Warning! Trying to add an osm package to a non-osm transfer! snapshotCode: ", package.right.snapshotCode );
			return;
		}
		let elementsAdded = false;
		trackEvent("add_to_transfer", #{packageCode: package.packageCode, entries: gaSelectedEntries(entries) });
		for (const e in entries) {
			if (e.selected) {		
				e.queued = true;
				e.selected = false;
				transferSelection.#addEntry(package, e);
				elementsAdded = true;
				console.log("[Maps] Add entry to transfer:", package.packageCode, "/", e?.name );
			}
		}
		this.size = this.#calculateSize();
		if (elementsAdded)
			this.#checkContentType();
	}

	#checkContentType(){
		let contentType = @none;
		for (const package in this.packages.values) {
			if ( package.supplierNames.includes( "openstreetmap.org" )) {
				contentType = @osm;
				break;
			}
			else if ( package.supplierNames.includes("here") ) {
				contentType = @here;
				break;
			}
		}
		this.contentType = contentType;			
	}
	
	isCompatible(package){ 
		return
            !this.contentType 
			|| this.contentType == @none
            || this.contentType==@osm && (package.snapshot.isOSM || package.snapshot.supplierNames.includes("openstreetmap.org") || !package.snapshot.supplierNames.includes("here")) 
            || this.contentType==@here && (!package.snapshot.isOSM || !package.snapshot.supplierNames.includes( "openstreetmap.org" )) 
    }

	/// Add a PackageEntry to the selection (entries contain the list of contents to upload)
	#addEntry(package, entry) {
		const packageCode = package.packageCode;
		this.packages.emplace(
			packageCode,
			(key) => {
				return {name: package.name, packageCode, entries: [entry], supplierNames: package.snapshot.supplierNames};
			}, 
			(item,key) => {
				item.entries.push(entry);
			},
		);
	}

	removePackage(pack, md5s) {
		const item = this.packages.getAndRemove(pack.packageCode) ?? undef;
		let md5ToRemove = Set.from( md5s ?? [] );

		if (item) {
			trackEvent("remove_from_transfer", #{packageCode: pack.packageCode, entries: gaEntries(item.entries)});
			console.log("[Maps] Remove package from transfer: ", pack.packageCode );
			for (const entry in item.entries) {
				entry.queued = false;
				entry.selected = true;
			}
		}
		
		for ( const package in this.packages.values ) {
			const removableEntries = filter( package.entries, e => any( e.contents, c => md5ToRemove.has( c.md5 ) ) );
			for( const entry in removableEntries ){
				entry.queued = false;
				entry.selected = true;
			}

			package.entries = filterFalse( package.entries, e => any( e.contents, c => md5ToRemove.has( c.md5 ) ) ).toArray();
		}
		this.packages.removeIf((key, value)=>{ !value.entries.length });
		this.size = this.#calculateSize();

		if (this.packages.size == 0) {
			this.showTransferElements = false;
			this.contentType = undef;
		}
		else 
			this.#checkContentType();
	}

	clear( reason ) {
		console.log("[Maps] Clear transfer selection");
		if (!this.size) return;
		for ( const pack in this.packages.values ) {
			for (const entry in pack.entries) {
				entry.queued = false;
				entry.selected = true;				
			}
		}
		this.packages.clear();
		this.size = 0;
		this.showTransferElements = false;
		this.contentType = undef;
		if ( reason == @deviceChanged )
			this.showDeviceChangedNoti();
	}

	showDeviceChangedNoti(){
		let noti = new Messagebox;
		noti.addLine(i18n`Your transfer selection was cleared because you connected to another device.`)
		.setOverlay()
		.addIcon( "msgbox_warning.svg" )
		.addButton( new Button({ text : i18n`Ok`}) );
		noti.show();		
	}

	getUploadFiles() {
		const toUpload = [];	
		for (const package in this.packages.values) {
			for ( const entry in package.entries ) {
				for ( const c in entry.contents ) {
					toUpload.push({
						fileName: c.fileName, 
						path: contentDb.getFilePath(c), 
						size: c.size, 
						md5: c.md5, 
						contentTypeCode: c.contentTypeCode,
					});
				}
			}
		}
		return toUpload;
	}

	getNonCompatibleFiles() {
		return getNonCompatibleFiles( this.contentType );
	}	

	hasContent( content ){
		for ( const p in this.packages.values ){
			for ( const entry in p.entries ) {
				if ( entry.contents.find( e=>e.md5==content.md5 ))
					return true;
			}
		}
		return false;
	}

	outdatedFilesFound( contents, removeFunc, continueFunc ){
		this._outdatedFunc.removeFunc = removeFunc;
		this._outdatedFunc.continueFunc = continueFunc;
		let clearOutdatedFunc = _ => {
			this._outdatedFunc.removeFunc = undef;
			this._outdatedFunc.continueFunc = undef;
		};
		let noti = new Messagebox;
		// todo display outdated contents
		noti.addLine(i18n`Your transfer selection contains outdated files! Do you want to remove these?`)
		.setOverlay()
		.addIcon( "msgbox_warning.svg" )
		.addButton( new Button({ text : i18n`Remove files`, action: _ => { removeFunc(); clearOutdatedFunc() }}) )
		.addButton( new Button({ text: i18n`Continue transfer`, action: _ => { continueFunc(); clearOutdatedFunc() }}) );
		noti.show();		
	}

	async startTransfer( toDelete = [] ) {
		const toUpload = this.getUploadFiles();
		const suppliersToCheck = new Set;
		for (const package in this.packages.values) {
			console.log("[Maps] Starting transfer: packageCode:", package.packageCode, "entries:", funcMap(e=>e.name, package.entries).join(", ") );
			trackEvent("start_transfer", #{packageCode: package.packageCode, entries: gaEntries(package.entries)});
			for ( const entry in package.entries ) {
				for ( const c in entry.contents ) {
					if ( mimesForSupplierDetection.includes( c.contentTypeCode ))
						suppliersToCheck.add( c.supplierName );
				}
			}
		}
		
		if ( toUpload.length == 0 )
			return;

		// double check the supplier compatibility
		if ( suppliersToCheck.has( "here") && suppliersToCheck.has( "openstreetmap.org") ){
			// transfer contains incompatible files
			console.log("[transfer] Error! Transfer selection contains incompatible files!");
			let noti = new Messagebox;
			noti.addLine(i18n`Your transfer selection contains incompatible files!`)
			.setOverlay()
			.addIcon( "msgbox_warning.svg" )
			.addButton( new Button({ text : i18n`Ok`}) );
			noti.show();	
			return;
		}
		
		const packageCodes = Iter.map(this.packages.values, i=>i.packageCode).toArray();
		const transferSession =  await buildFileTransfer( toUpload, toDelete );
		this.uploadProgress = new FileUploadProgress(transferSession,
			async () => {
				if (transferSession.result == transferSession.results.success) {
					for (const packageCode in packageCodes)
						trackEvent("transfer_finished", #{packageCode});
				}
				console.log("[Maps] Transfer finished" );
				// if the transfer result is lostConnection (or notEnoughSpace or something like that), the most likely scenario is that the user will try the transfer again, so we musn't remove the part files after a failed transfer.
				// But in case the user does not proceed with the transfer, the part files might remain on HU. To avoid this, we remove the part files after the next successful (or canceled) transfer
				await syncAfterTransfer(#{ deletePartFiles: transferSession.result == transferSession.results.success || transferSession.result == transferSession.results.cancel  });
				// Don't show sync progress if it is already finished, and another progress is still exists
				if (this.uploadProgress.hasProgressDialog)
					deviceProgressDialog.hide();

				dispose(this.uploadProgress);
				this.uploadProgress = undef;
			}
		);
		this.uploadProgress.startTransfer();

		// drop selected entries
		for (const package in this.packages.values)
			for (const e in package.entries) {
				e.queued = false;
			}

		this.size = 0L;
		this.packages.clear();
		this.contentType = @none;
	}
}

export TransferSelection transferSelection;
