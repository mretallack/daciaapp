import {stripExt, contentGrouping} from "~/src/utils/util.xs"
import {Map, Set, list} from "system://core.types"
import * as iter from "system://itertools";
import {checkContentsTransferred, isContentTransferred} from "~/src/toolbox/headUnitContentCache.xs"
import { i18n, translate } from "system://i18n"
import {bundleChanges} from "core://observe"
import {countryGroupingPrio} from "./packageModel.xs"
import {mapArgs, prop, pipe, reverseArgs} from "core://functional"
import {languages} from "~/src/utils/languages.xs"

export const otherFilesStr = i18n`Other files`;

export enum PackageSort {
    sizeAsc,
    sizeDesc,
    nameAsc,
    nameDesc,
    dateAsc,
    dateDesc,
    hasUpdateFirstThenDate
}

translatedCmpBy(accessor) {
    pipe(mapArgs(pipe(accessor, translate),?), languages.collator)
}
cmpByTranslatedName() { translatedCmpBy(prop(@name))}
export const packageSorters = object x {
    [PackageSort.sizeAsc]= (a,b) => a.size <=> b.size;
    [PackageSort.sizeDesc]= (a,b) => b.size <=> a.size;
    accessor [PackageSort.nameAsc] { get() { cmpByTranslatedName() } }
    accessor [PackageSort.nameDesc] {get() { (cmpByTranslatedName(), @desc) } }
    // TODO: milyen datumok alapjan?
    [PackageSort.dateAsc] = (a,b) => { 
        let aR = a.package.snapshot.contentRelease ?? 0;
        let bR = b.package.snapshot.contentRelease ?? 0;
        return aR <=> bR;
    };
    [PackageSort.dateDesc] = (a,b) => { 
        let aR = a.package.snapshot.contentRelease ?? 0;
        let bR = b.package.snapshot.contentRelease ?? 0;
        return bR <=> aR;
    };
    [PackageSort.hasUpdateFirstThenDate] = (a,b) => {
        let aDate = a.package.snapshot.contentRelease ?? 0;
        let bDate = b.package.snapshot.contentRelease ?? 0;
        let aHasUpdate = a.package.updated ?? 0;
        let bHasUpdate = b.package.updated ?? 0;
        return bHasUpdate <=> aHasUpdate || aDate <=> bDate;
    };
};

// creates a selection view based on a package
// when needed and data is available it can mark selection of parts
// whether they are uploaded or downloaded already

export class PackageEntry {
    name;
    contents = [];  // list of contents associated with this entry (like map, poi and speedcam files)
    downloaded = true;
    failed = false; // only set by TransferView
    transferred = true;
    selected = false;
    mandatory = false;
    downloading = false;
    queued = false; // can be used to mark the entry as queued (like the transfer selection)
    size = 0L; // cumulated size of all the contents
    downloadedSize = 0L;
    downloadingStatus = new list(); // downloading status for contents, while downloads are in progress

    constructor(name = "", isMandatory=false) {
        this.name = name;
        this.mandatory = isMandatory;
    }

    refresh() {
        bundleChanges(()=> {
            this.downloading = iter.any(this.downloadingStatus, s => s==@started);
            this.downloaded  = iter.all(this.downloadingStatus, s => s==@success);
            this.downloadedSize = 0L;
            for (let idx = 0; idx < this.contents.length; idx++) {
                if (this.downloadingStatus[idx] == @success) {
                    this.downloadedSize += this.contents[idx].size;
                }
            }
        });
    }

    /// Note: have to do refresh manually
    addContent(content, contentDb, deviceFiles) {
        this.contents.push(content);
        this.downloadingStatus.push(@unknown);
        this.size += content.size;
        const downloadedPath = contentDb.getFilePath(content);
        if (downloadedPath)
            this.downloadingStatus[-1] = @success;

        this.transferred &&= isContentTransferred(deviceFiles, content);
        return this;
    }

    /// status may be one of: @started, @success, @failed, @canceled
    /// @return true when this entry has handled the change (other entries don't have to examined) 
    onDownloadStatusChanged(contentMd5, status) {
        const idx = this.contents.findIndex(content => contentMd5 == content.md5);
        if (idx < 0)
            return false;

        this.downloadingStatus[idx] = status;
        this.refresh();
        this.selected = !(this.downloading || this.downloaded); // will always deselect downloading/downloaded items
        return true;
    }
    
    updateTransferStatus(deviceFiles) {
        this.transferred = checkContentsTransferred(deviceFiles, this.contents);
        // select when not transferred, and deselect when already transferred   
        this.selected = !this.transferred && !this.failed && !this.queued;
    }

    updateDownloadStatus(deviceFiles) {
        this.transferred = checkContentsTransferred(deviceFiles, this.contents);
    }
    
    onContentsRemoved(md5Set) {
        for (let idx = 0; idx < this.contents.length; idx++) {
            if (md5Set.has(this.contents[idx].md5)) {
                // mark as not downloaded and select it for download
                this.downloadingStatus[idx] = @unknown;
                this.selected = true; 
            }
        }
        this.refresh();
    }
}

export class PackageView {
    entries;
    expanded = false;
    enabled = true;
    constructor(entries = []) {
        this.entries = entries;
    }
    
    get transferred() {
        for (const e in this.entries)
            if (!e.transferred) return false;
        return true;
    }
    
    /// in options you may sepcify which entries to skip, while selecting
    /// options.skipTransferred
    /// options.skipDownloaded
    selectAll(options) {
        const skipTransferred = options?.skipTransferred ?? false;
        const skipDownloaded = options?.skipDownloaded ?? false;
        for (const e in this.entries) {
            if (e.transferred && skipTransferred) continue;
            if (e.downloaded && skipDownloaded) continue;
            if (e.queued) continue;
            if (e.failed) continue;
            e.selected = true;
        }
    }
    
    areAllEntriesSelected(options) {
        const skipTransferred = options?.skipTransferred ?? false;
        const skipDownloaded = options?.skipDownloaded ?? false;
        const skipMandatory = options?.skipMandatory ?? false;
        for (const e in this.entries) {
            if (e.transferred && skipTransferred) continue;
            if (e.downloaded && skipDownloaded) continue;
            if (e.mandatory && skipMandatory) continue;
            if (!e.selected)
                return false;
        }
        return true;
    }

    selectMandatory(value) {
        for (const e in this.entries) {
            if (e.mandatory) e.selected = value;
        }
    }
    
    deselectAll(options) {
        const deselectMandatory = options?.deselectMandatory ?? false;
        for (const e in this.entries) 
            if (!e.mandatory || deselectMandatory) e.selected = false;
    }
    
    get sizeOfSelection() {
        let size = 0L;
        for (const e in this.entries) 
            if (e.selected) size += e.size;
        return size;
    }

    get sizeOfSelectionToDownload() {
        let size = 0L;
        for (const e in this.entries) 
            if (e.selected) size += e.size - e.downloadedSize;
        return size;
    }

    /// When every item has been downloaded, this is the whole size of the package
    /// when there are non-downloaded elements, this is the same as sizeOfSelectionToDownload
    get downloadSizeForDisplay() {
        let size = 0L;
        let totalSize = 0L;
        let hasRemaining = false;
        for (const e in this.entries) { 
            if (e.selected) size += e.size - e.downloadedSize;
            totalSize += e.size;
            if (!e.downloaded)
                hasRemaining = true;
        }
        return hasRemaining ? size : totalSize;
    }
    
    /// status may be one of: @started, @success, @failed
    onDownloadStatusChanged(contentMd5, status) {
        for (const e in this.entries)
            if (e.onDownloadStatusChanged(contentMd5, status)) return e; // entry has handled the status change
    }
    
    onContentsRemoved(md5Set) {
        for (const e in this.entries)
            e.onContentsRemoved(md5Set)
    }
}

// It creates country entries based on the groupingTerm. The other files Entry are not created.
export createEntriesByCountry(contents, groupingTerm) {
    const entriesByCountry = new Map;
    for (const content in contents) {
        if (!content?.igoCountryCode || content?.contentTypeCode != groupingTerm)
            continue;
        const country = "_" + content.igoCountryCode;
        // Sometimes same country occuers multiple times
        // if (!entriesByCountry.has(country))
        entriesByCountry.insert(country, new PackageEntry(country));
    }
    return entriesByCountry;
}

createGroupingPackage( contents, groupingTerm, params, filter ){ //, eMap = entriesByCountry, params = {contentDb: contentDb, deviceFiles: deviceFiles, entriesMap: entriesByCountry}
	const entriesByCountry = createEntriesByCountry(contents, groupingTerm);
	for (const content in contents) {
		if (filter?.(content))
			continue;
		const countryCode = content?.igoCountryCode ? "_" + content.igoCountryCode : undef;
		const country = entriesByCountry.has(countryCode) ? countryCode : string(otherFilesStr);
		entriesByCountry.emplace(country, {
			insert: ()=> {
					const isMandatory = content?.igoCountryCode ? false : true;
					const entry = new PackageEntry(country, isMandatory);
					entry.addContent(content, params.contentDb, params.deviceFiles);
			},
			update: entry => entry.addContent(content, params.contentDb, params.deviceFiles)
		});

	}
	const toRemove = new Set;
	for (const country, entry in entriesByCountry) {
		if (entry.contents.length) {
			entry.refresh();
		} else {
			toRemove.add(country)
		}
	}
	entriesByCountry.remove(...toRemove);
	return entriesByCountry.values;
}

/// ctx contains the contentDb and deviceFile db for computing state of the items
/// filter function will can be used to filter out some contents from the view. all contents will be kept when no filter is used
createPackageView(packageVm, ctx, filter) {
	return contentGrouping( packageVm.package.contents, ctx.countryGroupingPrio ?? [], createGroupingPackage(?, ?, {contentDb: ctx.contentDb, deviceFiles: ctx.deviceFiles }, filter));
}

/// ctx contains the contentDb and deviceFile db for computing state of the items
export createPackageViewForDownload(packageVm, ctx) {
	// console.time("createPackageViewForDownload");
	const entries = createPackageView(packageVm, ctx);
	// console.timeEnd("createPackageViewForDownload");
	return entries;
}

/// will select only downloaded contents from the package
/// needs both contentDb and deviceFile db.
export createPackageViewForTransfer(packageVm, ctx) {
    // console.time("createPackageViewForTransfer");
    const groups = new Set();
    for (const c in packageVm.package.contents) {
        const downloaded = ctx.contentDb.getFilePath(c);
        if (downloaded) groups.add(c.igoCountryCode || @mandatory);
    }
    // filters out non downloaded  contents
    const entries = createPackageView(packageVm, ctx,
        c => {
            return !groups.has(c.igoCountryCode || @mandatory);
        }
    );
    for (const e in entries)  {
        if (!e.downloaded) {
            e.failed = true;
        } else if (!e.transferred) {
            e.selected = true;
        }
    }
    // console.timeEnd("createPackageViewForTransfer");
    return entries;
}

export createPackageViewForRemoval(packageVm, ctx) {
    // console.time("createPackageViewForRemoval");
    // filters out non downloaded contents
    const entries = createPackageView( packageVm, ctx, c => { ctx.contentDb.getFilePath(c) == undef } );
    // console.timeEnd("createPackageViewForRemoval");
    return entries;
}

export *contentsOfView(packageView) {
    for (const pe in packageView)
        for (const c in pe.contents)
            yield c;
}

/// options.skipDownloaded
export *selectedContentsOfView(packageView, options) {
    const skipDownloaded = options?.skipDownloaded ?? false;
    for (const pe in packageView) {
        if (!pe.selected) continue;
        for (let idx = 0; idx < pe.contents.length; idx++) {
            if (skipDownloaded && pe.downloadingStatus[idx]==@success) continue;
            yield pe.contents[idx];
        }
    }
}
