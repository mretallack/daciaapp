import {resolveFileUri} from "system://fs"
import {checksum} from "core/ioUtils.xs"
import * as downloadManager from "app://downloadManager"
import {Storage, list, Event, Map} from "system://core.types"
import {bundleChanges} from "core://observe"
import {yellowStorage} from "~/src/app.xs"
import * as os from "system://os"

class Downloads {
	list = list[];   // list of running/pending downloads
	@dispose
	#timer;
	
	#currentDownloads = new Storage("downloadList");
	#downloadManager; // download manager instance used by this instance
	
	constructor(manager) {
		this.#downloadManager = manager ?? downloadManager;
	}

	/// @param options may contain the following
	/// - expectedMd5: an expected md5 checksum, which downloader will check after the download is complete
	add(url, destinationSubPath, options) {
		const id = this.#downloadManager.enqueue(url, destinationSubPath, {allowMetered: !yellowStorage.wifiOnly});
		
		const download = new DownloadItem(id, url, destinationSubPath);
		download.expectedMd5 = options?.expectedMd5;
		this.list.push(download);
		// save this pending download
		this.#currentDownloads.setItem(string(id), { url, destinationSubPath, expectedMd5: download.expectedMd5});
		this.#currentDownloads.save();
		
		if (!this.#timer)
			this.#startObservingProgress();
		return download;
	}

	cancel(download) {
		if ( download.isFinished ){
			return;
		}
		let res = this.#downloadManager.remove(download.id);
		if (!res) {
			console.warn(`[Download][${string(download.id)}] can't remove ${download.fileName}`);
		}
		download.status = DownloadStatus.Canceled;
		// remove from the current download list if needed (including the persisted state)
		const idx = this.list.indexOf(download);
		if (idx >= 0) 
			this.#downloadComplete(download, idx);	
		else {
			console.log(`[Download][${string(download.id)}][missing] ${download.fileName}`);
			download.onComplete.trigger(download);
		}
	}
	
	/// Resume ongoing persisted downloads (they may have completed)
	/// will return with the contents of list (after any persisted downloads are resumed)
	resumeDownloads() {
		const pendingTasks = new Map;
		for (const idStr, downloadData in this.#currentDownloads) {
			const id = int64(idStr);
			const stat = this.#downloadManager.query(id);
			// TBA-557: workaround for Android DownloadManager stuck after phone restart
			if (os.platform == "android" && stat?.status != DownloadStatus.Success) {
				pendingTasks.set(idStr, downloadData);
				continue;
			}
			const download = new DownloadItem(id, downloadData.url, downloadData?.destinationSubPath);
			download.expectedMd5 = downloadData?.expectedMd5;
			this.list.push(download);
		}
		for (const idStr, downloadData in pendingTasks) {
			this.#currentDownloads.removeItem(idStr);
			this.#downloadManager.remove(int64(idStr));
			if (downloadData?.destinationSubPath) {
				const download = this.add(downloadData.url, downloadData.destinationSubPath, {expectedMd5: downloadData?.expectedMd5});
			}
		}
		if (!this.#timer && this.list.length > 0) 
			this.#startObservingProgress(); // NOTE: this won't call updateDownloads until the next event loop, so it's safe to process
											//       list until then
		return this.list	
	}
	
	#startObservingProgress() {
		this.#timer = Chrono.schedule(0, 1000,  ()=> bundleChanges( this.#updateDownloads(?) ));
	}
	
	#updateDownloads() {
		// periodically updates downloads in progress
		// drop completed downloads...
		for (let idx = this.list.length - 1; idx >= 0; --idx) {
			const download = this.list[idx];
			if (download.status == DownloadStatus.Checking)
				continue; // skip downloads which are already complete and md5 check is performed
			const stat = this.#downloadManager.query(download.id);
			if (!stat) {
				download.status = DownloadStatus.Failed;
				this.#downloadComplete(download, idx);
				continue;
			}
			download.status = stat.status;	
			download.totalSize = stat.totalSize;
			download.progress = stat.progress;
			let fileName = stat.fileName;
			if ( fileName && !download.fileName)
				download.fileName = resolveFileUri(fileName);
			// detect failure/completion
			if (download.expectedMd5 && download.status == DownloadStatus.Success) {
				this.#checkMd5ForDownload(download);
			} else if (download.status == DownloadStatus.Failed || download.status == DownloadStatus.Success) {
				this.#downloadComplete(download, idx);
			}
		}
	}
	
	async #checkMd5ForDownload(download) {
		download.status = DownloadStatus.Checking;
		const localMD5 = (await checksum(download.fileName, @md5))?.hexstr();
		download.localMd5 = localMD5;
		if (download.status == DownloadStatus.Canceled)
			return;
		if (localMD5 == download.expectedMd5)
			download.status = DownloadStatus.Success;
		else download.status = DownloadStatus.Failed;
		
		this.#downloadComplete(download, this.list.indexOf(download));
	}
	
	async #downloadComplete(download, idx) {
		if ( download.status == DownloadStatus.Success && !download.localMd5 ){
			const localMD5 = (await checksum(download.fileName, @md5))?.hexstr();
			download.localMd5 = localMD5;			
		}
		this.list.splice(idx, 1);
		console.log(`[Download][${string(download.id)}][${download.status}] ${download.fileName}`);
		// update db.
		this.#currentDownloads.removeItem(string(download.id));
		// trigger onComplete listeners
		const finalDownload = this.list.length == 0;
		download.onComplete.trigger(download, finalDownload);
		
		// stop timer when done
		if (finalDownload && this.#timer) {
			this.#timer.stop();
			this.#timer = undef;
		}
	}
}

@dispose
export Downloads downloads;

export enum DownloadStatus {
	Unknown = "unknown",
	Failed = "failed",
	Paused = "paused",
	Pending = "pending",
	Running = "running",
	Checking = "checking", // checking checksum 
	Success = "success",
	Canceled = "canceled",
}

/// class representing one download
export class DownloadItem {
	id;                 // unique id of the download
	url;                // the url we're downloading from
	destinationSubPath;
	status; 
	totalSize = -1;     // total size of the download, -1 means it is unknown 
	progress  = -1;     // downloaded size, -1 is unknown, otherwise it moves between 0 and totalSize
	fileName;           // absolute path, where the file is saved
	expectedMd5;        // optional: when set contains the expected checksum for this download
						//           in this case downloads will check the file after download finishes, and mark as success only when checksum is ok
	localMd5;			// will be set after the download is complete
	#downloads;         // the downloads instance managing this download
	
	onComplete = Event{};
	
	get isFinished(){
		return [DownloadStatus.Failed, DownloadStatus.Success, DownloadStatus.Canceled].includes( this.status );
	}
	
	constructor(id, url, destinationSubPath) {
		// todo: set #downloads!
		this.id = id;
		this.url = url;
		this.destinationSubPath = destinationSubPath;
		this.status = DownloadStatus.Unknown;
	}
	
	cancel() {
		if (this.id >= 0)
			this.#downloads.cancel(this)
	}
}
