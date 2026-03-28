import {ContentTypeCodes} from "~/src/service/datamodel.xs"
export const defaultFileMapping = {
    ".fbl":"content/map",
    ".hnr":"content/map",
    ".fda":"content/map", // driver alert
    ".fds":"content/map", // ?
    ".fpa":"content/map", // address point
    ".ftr":"content/map", // track info
    ".fjv":"content/map", // TODO: is fjv and fjw the same?
    ".fjw":"content/map", // junction view
    ".fsp":"content/map", // speed profile
    ".poi":"content/poi",
    ".spc":"content/speedcam",
    ".tmc":"content/tmc",
    ".lyc":"license", // lic, device.nng?
    "device.nng":"license",
    // version: dbver.pinfo -> 'content"
    // zips: voice -> content/voice, userdata -> content/userdata
    // save
    // update_only: nngnavi,data.zip,synctool_update -> ""
    // update_only: ux zip => "ux"
};

// Note: map with typeCode
// zips: lang-> content/lang, global_cfg.zip -> content/global_cfg
export const typeCodeMapping = {
	[ContentTypeCodes.Lang]: "content/lang",
	[ContentTypeCodes.GlobalCfg]: "content/global_cfg",
	[ContentTypeCodes.Voice]: "content/voice",
	[ContentTypeCodes.DealerPoi]: "content/userdata/POI",
};

export mapTypeCodeToPath(content) {
	const path = typeCodeMapping[content.contentTypeCode] || undef;
	if (path) return `${path}/${content.fileName}`;
	return undef;
}

export mapContentToPath(content) {
	return mapTypeCodeToPath(content) || mapFileToPath(content.fileName)
}

export mapFileToPath( filename, fileMapping ) {
	const ext = "." + filename.split(".")[-1];
	//todo ha nincs fileMapping
	let mapOrder = [ 
		(defaultFileMapping, filename),
		(defaultFileMapping, ext)
	];
	if( fileMapping ){
		mapOrder.unshift(
			(fileMapping, filename),
			(fileMapping, ext) 
		);
	}
	for (const store,key in mapOrder) {
		const path = store[key] ?? undef;
		if (path) 
			return `${path}/${filename}`;
	}
	return undef;
}