import { hasProp, typeof, lazyAsync } from "system://core"
import * as httpClient from "system://nng.networking.http.Client"
import { Storage, Map, Set, date } from "system://core.types"
import * as fs from "system://fs"
import {md5} from "system://digest"
import {length} from "system://itertools"
import {unobservedValue} from "core://observe"

const imgStorage = new Storage("images");
const cachedir = "nngfile://cache/imgs";
const acceptedMime = "image/png, image/jpeg, image/svg+xml, image/gif, image/bmp";

const refreshAge = 10*60; // time to refresh image if last retrievel happened earlier. ten minutes
const retryPeriod = 1*60; // max age of negative cache
const unusedAge = 24*60*60; // one day

epochTime() { int(date.now()/ 1000 )} // would be good for 137 years if would be unsigned, but since we use it as diff

async loadImage(url, oldImg) {
    var req = httpClient.createRequest(url);
    req.headers.set("Accept", acceptedMime);
	if (oldImg?.etag)
		req.headers.set("If-None-Match",oldImg.etag);
    var res = await req.fetch();
	if (res && oldImg && res.error != 0) 
		return oldImg;
	const now = epochTime();
	if (res && res.status == 304 && oldImg) {
		oldImg.retrieved = now;
		return oldImg;
	}
    if (??(res && res.body) && res.status == 200) {
		// TODO: check empty.png and use "dummy_location1.svg"
		const hash = md5(res.body).hexstr(); // todo use Content-MD5 header
		let mime = res.headers.get("Content-Type");
		let ext = "png";
		if (mime.startsWith("image/")) {
			ext = mime.substr("image/".length);
			if (ext == "svg+xml")
				ext = "svg";
			else if (ext == "jpeg");
				ext = "jpg";
		}

		const etag = res.headers.get('etag') || Symbol.NoProperty;
		const cachefile = `${cachedir}/${hash}.${ext}`;
		const wr = await fs.writeFile(cachefile, res.body);
		return { etag, img:cachefile, retrieved: now};
	}
    else {
		console.log(`get ${url} failed. errCode: ${res.status ?? "n/a"}`);
		return { retrieved: now};
	}
}

class ImageCache{
	data = new Map;
	fallbackImg;

	constructor(defaultImg ) {
		fs.mkdirSync(cachedir, @recursive);
		if (defaultImg) // only assign to defaultImg if it has not been set by the ImageCache { fallbackImg= ... } syntax
			this.fallbackImg = defaultImg;
		this.load();
	}

	load() {
		if ( let d = ??imgStorage.getItem("image_cache") ) {
			this.data = d;
		}
	}
	save() {
		imgStorage.setItem( "image_cache", this.data );
		imgStorage.markDirty();
	}

	async collectGarbage(maxAge = unusedAge) {
		const now = epochTime();
		const v = this.data.values;
		const toRemove = new Set;
		for(let i = this.data.size-1; i >= 0;--i) {
			if (now - ( v[i].lastUse ?? v[i].retrieved) > maxAge) {
				v[i]?.img ?|> toRemove.add(^);
				this.data.removeAt(i);
			}
		}
		if (!toRemove.size)
			return;
		// double check that resources are not shared by other keys (e.g.  two key maps to the same resource)
		for(const e in v)
			toRemove.delete(e?.img);
		// remove from fs
		for(const img in toRemove)
			await fs.remove(img);
		this.save();
	}

	getFromChache(id) {
		this.data?.[id]?.img;
	}

	retrieveSyncOrAsync(id, url) {
		if (!id) return;
		let entry = this.data?.[id];
		if (entry?.valid == 0) // used to set valid to 0 for invalid entries, remove obsolete entries
			entry = undef;
		if (entry?.img && !fs.statSync(entry?.img)) // check if file has not been removed awhile 
			entry = undef;
		const now = epochTime();
		if (entry && entry?.retrieved) { // check age of entry if it has to be refreshed. retrieved used to be missing in old cache data, force refresh in this case
			if (now - entry.retrieved < (entry?.img ? refreshAge : retryPeriod) ) {
				if (!entry?.img) // don't update negative entries
					return this.fallbackImg;
				entry.lastUse = now;
				this.save();
				return entry.img;
			}
		} else if (entry?.lastUse) // ensure that entry is not garbage collected by updateing lastUse, maybe should update retrieved but careful not to update if retrieve fails
			entry.lastUse = now; 
		// load or refrehs image
		this.#inProgress.emplace(id, async id => {
			var img = await loadImage(url, entry);
			if (img != entry)
				this.data.set(id,img);
			else if (img?.img)
				img.lastUse = epochTime();
			this.save();
			this.#inProgress.remove(id);
			return img.img ?? this.fallbackImg;
		})
	}

	#inProgress = new Map;
};

export class Image {
	constructor(id, url) { // todo: default img
		this.id = id;
		this.#img = lazyAsync(() => {
			if ( url && !url.startsWith("http") && ( url.substr(-3, 3) == "png" || url.substr(-3, 3) == "jpg" || url.substr(-3, 3) == "svg" ) ) //todo
				return url;
			imageCache.retrieveSyncOrAsync(id, url); // might return a promise that is going to be handled by lazyAsync
		});
	}

	get ready() { this.#img.initialized }
	get loading() { this.#img.intializing }
	get img() { this.#img.value }

	id;
	#img = undef;
}

export default object imageCache extends (new ImageCache( "placeholders/cardHeader.jpg")) {
	garbageSchedule = do { Chrono.createTimer( #{
		delay: 5min, 
		interval: 1hour,
		autoStart: true,
		on: () => imageCache.collectGarbage()
	})};
}
