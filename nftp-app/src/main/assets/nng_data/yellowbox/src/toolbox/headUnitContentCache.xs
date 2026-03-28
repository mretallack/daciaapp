import { Storage, Map, Set } from "system://core.types"
import {mapContentToPath} from "./fileMapping.xs"
import {and} from "system://bitwise"
import {all} from "system://itertools"

export const contentCacheStorage = new Storage("contentCache");

export enum CompareResult {
	Same,
	Different,
	NotSure,
}

export class ContentCacheHU {
	/// Stored item:
	//	( filePath: { size, md5, mtimeMs, contentInfo } )
	storage;
	#swid;
	#mapList = new Map;

	constructor( swid, storage ){
		this.#swid = swid;
		this.storage = storage ?? contentCacheStorage;
		let lst = ??this.storage.getItem( swid );
		if (?? lst )
			this.#mapList = lst;
	}

	get keys() { this.#mapList.keys; }

	save(){
		this.storage.setItem( this.#swid, this.#mapList );
		this.storage.markDirty();
	}

	//modify the content item
	set( filePath, signature ){
		if (!signature || !signature?.size || !signature?.mtimeMs) {
			console.warn(`Missing signature for ${filePath}`);
			return;
		}
		let local = this.#mapList?.[filePath];
		const valid = signature.size == local?.size && signature.mtimeMs == local?.mtimeMs;
		let info = {
			size: signature.size ?? local.size ?? 0, 
			mtimeMs: signature.mtimeMs ?? local.mtimeMs ?? undef,
			md5: signature.md5 ?? (valid ? local?.md5 : undef), 
			contentInfo: signature.contentInfo ?? (valid ? local?.contentInfo : undef), 
		};
		this.#mapList.set( filePath, info );
		this.save();
	}

	get( filePath ){
		return ??this.#mapList.get( filePath );
	}

	compare( filePath, signature ){
		const content = ??this.#mapList.get( filePath );
		if (!content) return CompareResult.Different;
		
		if (content.size != signature.size)
			return CompareResult.Different;

		if (content?.md5 == undef || signature?.md5 == undef)
			return CompareResult.NotSure;

		if (content.md5 == signature.md5) {
			return CompareResult.Same;
		} else {
			return CompareResult.Different;
		}
	}

	getForContent( purchasedContent, mapper ){
		if( purchasedContent ){
			let filePath = mapper?.( purchasedContent.fileName ) ?? mapContentToPath(purchasedContent);
			return ??this.get( filePath );
		} else {
			console.warn("[Content cache] No purchasedContent given for getForContent: ", purchasedContent.fileName );
		}
	}

	update( fileList, options={removeMissing:true}){
		let delList = new Set(this.#mapList.keys);
		for( let item in fileList ){
			if (item==undef || !item.name || !item.isFile)
				continue;
			let filePath = item.path;
			
			let localInfo = ??this.#mapList[ filePath ];
			if (!localInfo) {
				this.#mapList.set( filePath, 
					{
						md5: item?.md5,
						contentInfo: item?.contentInfo, 
						size: item.size,
						mtimeMs: item.mtimeMs,
					})
			}
			else if (item.size != localInfo.size || item.mtimeMs != localInfo.mtimeMs){
				localInfo.md5 = item?.md5;
				localInfo.contentInfo = item?.contentInfo;
				localInfo.size = item.size;
				localInfo.mtimeMs = item.mtimeMs;
			} else {
				// same as local, just update missing fields
				if (item?.contentInfo) localInfo.contentInfo = item.contentInfo;
				if (item?.md5) localInfo.md5 = item.md5;
			}
			delList.delete( filePath );
		}
		if (options.removeMissing) {
			for( let item in delList ){
				this.remove( item, false );
				console.log("Remove missing files from fileDB cache.", item );
			}
		}
		console.log("[Content cache] fileDB updated.");
		this.save();
	}

	getPartFiles(){
		const res = [];
		for( let path in this.#mapList.keys ){
			if ( path.endsWith(".new.part") )
				res.push( { path } );
		}
		return res;
	}

	remove( filePath, save = true ){
 		this.#mapList.remove( filePath );
		if ( save )
			this.save();
	}

}

const CID_TYPE_FBL = 0x00000000;
const CID_TYPE_MASK = 0xC0000000;
const CID_VERSION_MASK_FBL = 0x000001FF;
const CID_VERSION_MASK_OTHER = 0x003FFFFF;
areFbls(...cids) { all(cids, cid=> and(cid, CID_TYPE_MASK) == CID_TYPE_FBL) }

export isContentNew(deviceFileDb, content) {
	const fileProps = ??deviceFileDb.getForContent(content);
	if (fileProps && fileProps?.contentInfo && content.contentIds) {
		// todo: miert van mindig 1db cid a szerveren
		const contentCid = content.contentIds[0];
		const huCid = fileProps.contentInfo.contentId || fileProps.contentInfo.contentIds[0];
		const mask = areFbls(contentCid, huCid) ? CID_VERSION_MASK_FBL : CID_VERSION_MASK_OTHER;
		const contentVersion = and(contentCid, mask);
		const headunitVersion = and(huCid, mask);
		if (contentVersion <= headunitVersion)
			return false;

		if (content.buildTimestamp / 1000 <= fileProps.contentInfo.timeStamp)
			return false;
	}
	return true;
}

export isContentTransferred(deviceFileDb, content) {
	const fileProps = ??deviceFileDb.getForContent(content);
	if (fileProps && fileProps.md5 == content.md5)
		return true;
	return !isContentNew(deviceFileDb, content);
}

/// Checks if a list of contents are all transferred to the HU
/// @param deviceFileDb a ContentCacheHU instance
/// @param contents list of contents to check
export checkContentsTransferred(deviceFileDb, contents) {
	for (const c in contents) {
		if (!isContentTransferred(deviceFileDb, c))
			return false;
	}
	return true;
}