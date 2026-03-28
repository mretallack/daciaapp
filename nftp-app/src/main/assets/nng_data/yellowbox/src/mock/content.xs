import { Package, Snapshot, SalesPackage, Description, Price, Content } from "../service/datamodel.xs"
import imageCache from "~/src/utils/imageCache.xs"
import { values } from "system://core"
import { filter } from "system://itertools"
import {PurchasedContent} from "~/src/toolbox/packages/packageAndContent.xs"

const DealTypes = {
	oneTime: { code: 9837728667L, text: "Töltse le a legfrissebb térképet" },
	oneYear: { code: 9837728812L, text:"Töltse le a legfrissebb térképet + további 1 frissítést a következő egy évben" },
	threeYears: { code: 9837728822L, text: "Töltse le a legfrissebb térképet + további 5 frissítést a következő három évben" }
};

const SalesPackages = {
	Africa1: { actualPrice: {currency:"USD", net:113.11, vat:0}, basePrice: {currency:"USD", net:113.11, vat:0}, contType: "Térképek", dealTypeCode: DealTypes.oneTime.code, dealTypeLocale: { title: DealTypes.oneTime.text, timestamp: 0, descriptionId: 0}, salesPackageCode: 170578 },
	Africa2: { actualPrice: {currency:"USD", net:149, vat:0}, basePrice: {currency:"USD", net:149, vat:0}, contType: "Térképek", dealTypeCode: DealTypes.oneYear.code, dealTypeLocale: { title: DealTypes.oneYear.text, timestamp: 0, descriptionId: 0}, salesPackageCode: 669793 },
	WEU1: { actualPrice: {currency:"USD", net:200, vat:0}, basePrice: {currency:"USD", net:200, vat:0}, contType: "Térképek", dealTypeCode: DealTypes.oneTime.code, dealTypeLocale: { title: DealTypes.oneTime.text, timestamp: 0, descriptionId: 0}, salesPackageCode: 99999 },
	WEU2: { actualPrice: {currency:"USD", net:300, vat:0}, basePrice: {currency:"USD", net:300, vat:0}, contType: "Térképek", dealTypeCode: DealTypes.oneYear.code, dealTypeLocale: { title: DealTypes.oneYear.text, timestamp: 0, descriptionId: 0}, salesPackageCode: 9999911 },
	WEU3: { actualPrice: {currency:"USD", net:400, vat:0}, basePrice: {currency:"USD", net:400, vat:0}, contType: "Térképek", dealTypeCode: DealTypes.threeYears.code, dealTypeLocale: { title: DealTypes.threeYears.text, timestamp: 0, descriptionId: 0}, salesPackageCode: 9999922 },
	Iberia1: { actualPrice: {currency:"USD", net:120, vat:0}, basePrice: {currency:"USD", net:120, vat:0}, contType: "Térképek", dealTypeCode: DealTypes.oneTime.code, dealTypeLocale: { title: DealTypes.oneTime.text, timestamp: 0, descriptionId: 0}, salesPackageCode: 99998 },
	Iberia2: { actualPrice: {currency:"USD", net:0, vat:0}, basePrice: {currency:"USD", net:0, vat:0}, contType: "Térképek", dealTypeCode: DealTypes.oneYear.code, dealTypeLocale: { title: DealTypes.oneYear.text, timestamp: 0, descriptionId: 0}, salesPackageCode: 9999811 },
	Benelux1: { actualPrice: {currency:"USD", net:140, vat:0}, basePrice: {currency:"USD", net:140, vat:0}, contType: "Térképek", dealTypeCode: DealTypes.oneTime.code, dealTypeLocale: { title: DealTypes.oneTime.text, timestamp: 0, descriptionId: 0}, salesPackageCode: 99997 },
	Benelux2: { actualPrice: {currency:"USD", net:160, vat:0}, basePrice: {currency:"USD", net:160, vat:0}, contType: "Térképek", dealTypeCode: DealTypes.oneYear.code, dealTypeLocale: { title: DealTypes.oneYear.text, timestamp: 0, descriptionId: 0}, salesPackageCode: 9999711 },
	Apennine1: { actualPrice: {currency:"USD", net:0, vat:0}, basePrice: {currency:"USD", net:0, vat:0}, contType: "Térképek", dealTypeCode: DealTypes.oneTime.code, dealTypeLocale: { title: DealTypes.oneTime.text, timestamp: 0, descriptionId: 0}, salesPackageCode: 99996 },
	Apennine2: { actualPrice: {currency:"USD", net:150, vat:0}, basePrice: {currency:"USD", net:150, vat:0}, contType: "Térképek", dealTypeCode: DealTypes.oneYear.code, dealTypeLocale: { title: DealTypes.oneYear.text, timestamp: 0, descriptionId: 0}, salesPackageCode: 9999611 },
	Italy: { actualPrice: {currency:"USD", net:90.22, vat:0}, basePrice: {currency:"USD", net:90.22, vat:0}, contType: "Térképek", dealTypeCode: DealTypes.oneTime.code, dealTypeLocale: { title: DealTypes.oneTime.text, timestamp: 0, descriptionId: 0}, salesPackageCode: 99995 },
	Italy_osm: { actualPrice: {currency:"USD", net:70.22, vat:0}, basePrice: {currency:"USD", net:70.22, vat:0}, contType: "Térképek", dealTypeCode: DealTypes.oneTime.code, dealTypeLocale: { title: DealTypes.oneTime.text, timestamp: 0, descriptionId: 0}, salesPackageCode: 99900 },
	Spain: { actualPrice: {currency:"USD", net:90, vat:0}, basePrice: {currency:"USD", net:90, vat:0}, contType: "Térképek", dealTypeCode: DealTypes.oneTime.code, dealTypeLocale: { title: DealTypes.oneTime.text, timestamp: 0, descriptionId: 0}, salesPackageCode: 99994 },
	Germany: { actualPrice: {currency:"USD", net:90, vat:0}, basePrice: {currency:"USD", net:90, vat:0}, contType: "Térképek", dealTypeCode: DealTypes.oneTime.code, dealTypeLocale: { title: DealTypes.oneTime.text, timestamp: 0, descriptionId: 0}, salesPackageCode: 99993 },
	France: { actualPrice: {currency:"USD", net:90, vat:0}, basePrice: {currency:"USD", net:90, vat:0}, contType: "Térképek", dealTypeCode: DealTypes.oneTime.code, dealTypeLocale: { title: DealTypes.oneTime.text, timestamp: 0, descriptionId: 0}, salesPackageCode: 99992 },
	Kamu: { actualPrice: {currency:"USD", net:90, vat:0}, basePrice: {currency:"USD", net:90, vat:0}, contType: "Kamu dolgok", dealTypeCode: DealTypes.oneTime.code, dealTypeLocale: { title: DealTypes.oneTime.text, timestamp: 0, descriptionId: 0}, salesPackageCode: 97179 },
	Update: { actualPrice: {currency:"USD", net:90, vat:0}, basePrice: {currency:"USD", net:90, vat:0}, contType: "Update", dealTypeCode: DealTypes.oneTime.code, dealTypeLocale: { title: DealTypes.oneTime.text, timestamp: 0, descriptionId: 0}, salesPackageCode: 9715179 },
};

const Snapshots = {
	Africa: { image:"africa.jpg", snapshotCode: 1190170, buildTimestamp: 2662233208272L, contentRelease: "2021 Q4", supplierNames: ["nng", "here"] },
	WEU: { image:"Austria.jpg", snapshotCode: 999991, buildTimestamp: 1637943578000L, contentRelease: "2021 Q4", supplierNames: ["nng", "here"] },
	WEU_OSM: { image:"Belgium.jpg", snapshotCode: 999998, buildTimestamp: 1637943578000L, contentRelease: "2025 Q6", supplierNames: ["nng", "openstreetmap.org"] },
	Iberia: { image:"Spain.jpg", snapshotCode: 999981, buildTimestamp: 1637943578000L, contentRelease: "2021 Q4", supplierNames: ["nng", "here"] },
	Benelux: { image:"Netherlands.jpg", snapshotCode: 999971, buildTimestamp: 1637943578000L, contentRelease: "2021 Q4", supplierNames: ["nng", "here"] },
	Apennine: { image:"Italy.png", snapshotCode: 999961, buildTimestamp: 2662233208272L, contentRelease: "2021 Q4", supplierNames: ["nng", "here"] },
	Italy: { image:"Italy.png", snapshotCode: 999951, buildTimestamp: 1637943578000L, contentRelease: "2021 Q4", supplierNames: ["nng", "here"] },
	Italy_osm: { image:"Italy.png", snapshotCode: 999000, buildTimestamp: 1637943578000L, contentRelease: "2021 Q4", supplierNames: ["nng", "openstreetmap.org"] },
	Spain: { image:"Spain.jpg", snapshotCode: 999941, buildTimestamp: 1637943578000L, contentRelease: "2021 Q4", supplierNames: ["nng", "here"] },
	Germany: { image:"Germany.jpg", snapshotCode: 999931, buildTimestamp: 1637943578000L, contentRelease: "2021 Q4", supplierNames: ["nng", "here"] },
	France: { image:"France.png", snapshotCode: 999921, buildTimestamp: 2662233208272L, contentRelease: "2021 Q4", supplierNames: ["nng", "here"] },
	Kamu: { image:"Iceland.jpg", snapshotCode: 97179, buildTimestamp: 2662333208272L, contentRelease: "2025 Q4", supplierNames: ["nng", "here"] },
	Update: { image:"SanMarino.jpg", snapshotCode: 9715179, buildTimestamp: 2662333208272L, contentRelease: "2025 Q4", supplierNames: ["nng", "here"] },
};

export getImageBySnapshotCode( code ){
	let element = ...filter( values(Snapshots), i=>i.snapshotCode==code );
	return element.image ?? "";
}

getMockSalesPackage( packageName, pType ) {
	let data = SalesPackages[packageName];
	let retval = new SalesPackage( data );
	if ( pType == @scratch ){
		retval.actualPrice.net = -1;
		retval.actualPrice.vat = -1;
		retval.basePrice.net = -1;
		retval.basePrice.vat = -1;		
		retval.usedScratchCode = "abc123";
	}
	else if ( pType == @voucher ){
		retval.actualPrice.net *= 0.7;
		retval.actualPrice.vat *= 0.7;
		retval.usedVoucherCode = "cba321";
	}	
	return retval;
}

const Contents = {
	//Szupeeerrr Kamu Mega package.
	97179: [
		{ size: 10315343, version: 13, fileName: "Belgium.poi", contentIds:[1082173846], md5: "a97404675729a061b8dcf22ce3a5fe00", country:"BEL", filePath: "/poi/HERE/ALL/2021_Q4/2021_12_03__08_43_00", buildTimestamp: 1672754314000L, contentTypeMime: "x-poi", packageCode: 172, supplierName: "here", releaseReasonTitle: "NEW_VERSION", contentTypeCode: 4, downloadLocation: "https://download.naviextras.com/content/poi/HERE/ALL/2022_Q4/2023_02_22__18_41_12/Belgium.poi" },
		{ size: 2208, version: 1, fileName: "Belgium-BeMobile-light.tmc", contentIds:[1077936207], md5: "493a32105e356a65c440700496e33257", country:"BEL", filePath: "/tmc/BeMobile/ALL/2.0/2011_06_02__16_20_00", buildTimestamp: 1307024408000L, contentTypeMime: "x-tmc/tmc", packageCode: 61940, supplierName: "bemobile", releaseReasonTitle: "NEW_VERSION", contentTypeCode: 12, downloadLocation: "https://download.naviextras.com/content/tmc/BeMobile/ALL/2.0/2011_06_02__16_20_00/Belgium-BeMobile-light.tmc" },
		{ size: 21219840, version: 1001, fileName: "Belgium.fbl", contentIds:[2106541], md5: "5f498c0ff473c286d234b65e921a8ec7", country:"BEL", filePath: "testdata", buildTimestamp: 1637943578000L, contentTypeMime: "x-map", packageCode: 993,supplierName: "here",  releaseReasonTitle: "NEW_VERSION", contentTypeCode: 1, downloadLocation: "https://cdns.distrib.naviextras.com/content/map/HERE/ALL/2021_Q2/2021_07_18__13_46_40/Belgium.fbl" },

		{ size: 3530, version: 100, fileName: "Bulgaria.spc", contentIds:[1124077232], md5: "1809588a4cecfa19def5025ecf9f07ea", country:"BGR", filePath: "/speedcam/HERE/ALL/2022_Q4/2023_02_22__19_13_00", buildTimestamp: 1671370804000L, contentTypeMime: "x-speedcam/spc", packageCode: 61119, supplierName: "here", releaseReasonTitle: "NEW_VERSION", contentTypeCode: 30, downloadLocation: "https://download.naviextras.com/content/speedcam/HERE/ALL/2022_Q4/2023_02_22__19_13_00/Bulgaria.spc" },
		{ size: 5970617, version: 100, fileName: "Bulgaria.poi", contentIds:[1082173766], md5: "0ea48f33ed758cbd40cf5603a9d10888", country:"BGR", filePath: "/poi/HERE/ALL/2022_Q4/2023_02_22__18_41_12", buildTimestamp: 1673634357000L, contentTypeMime: "x-poi", packageCode: 61119, supplierName: "here", releaseReasonTitle: "NEW_VERSION", contentTypeCode: 4, downloadLocation: "https://download.naviextras.com/content/poi/HERE/ALL/2022_Q4/2023_02_22__18_41_12/Bulgaria.poi" },
		{ size: 21009408, version: 100, fileName: "Bulgaria.fbl", contentIds:[3671231], md5: "55fca88e8d1876823c3b0c27cf23d8e5", country:"BGR", filePath: "/map/HERE/ALL/2022_Q4/2022_12_13__17_20_02", buildTimestamp: 1670952002000L, contentTypeMime: "x-map", packageCode: 61119, supplierName: "here", releaseReasonTitle: "NEW_VERSION", contentTypeCode: 1, downloadLocation: "https://download.naviextras.com/content/map/HERE/ALL/2022_Q4/2022_12_13__17_20_02/Bulgaria.fbl" },

		{ size: 61942, version: 537331225, fileName: "Voice_Deu-m4-lua.zip", contentIds:[1086328492], md5: "9d58ebc1786aebb354c1279b7e8d6cec", country:"DEU", filePath: "/voice/NNG/Standard/v1/2018_10_04__15_23_44/Deu_m4_lua/content/voice", buildTimestamp: 1538659424000L, contentTypeMime: "x-guidance-voice/guidance-voice", packageCode: 61942, supplierName: "navngo", releaseReasonTitle: "NEW_VERSION", contentTypeCode: 3, downloadLocation: "https://download.naviextras.com/content/voice/NNG/Standard/v1/2018_10_04__15_23_44/Deu_m4_lua/content/voice/Voice_Deu-m4-lua.zip" },
		{ size: 129946, version: 537331225, fileName: "Lang_German.zip", contentIds:[1090520536], md5: "9d58ebc1786aebb354c1279b7e8d6cec", country:"DEU", filePath: "/lang/NNG/LGE-Renault/v1/2023_02_24__15_02_24", buildTimestamp: 1538659424000L, contentTypeMime: "x-gui-language", packageCode: 121508, supplierName: "lge renault", releaseReasonTitle: "NEW_VERSION", contentTypeCode: 10, downloadLocation: "https://download.naviextras.com/content/lang/NNG/LGE-Renault/v1/2023_02_24__15_02_24/Lang_German.zip" },
		{ size: 187601920, version: 1001, fileName: "Germany.fbl", contentIds:[8438957], md5: "03374dfac7c9a2a53d11cc8f3bff2603", country:"DEU", filePath: "testdata", buildTimestamp: 1637943578000L, contentTypeMime: "x-map", packageCode: 9911, supplierName: "here",  releaseReasonTitle: "NEW_VERSION", contentTypeCode: 1, downloadLocation: "https://cdns.distrib.naviextras.com/content/map/HERE/ALL/2021_Q2/2021_07_18__13_46_40/Germany.fbl" },

		{ size: 2360072, version: 537331225, fileName: "Voice_Eng-uk-f3-lua.zip", contentIds:[1086328505], md5: "128bd96a1ce79b9a390595e1ae7021b4", country:"GBR", filePath: "/voice/NNG/Standard/v1/2018_10_04__15_23_44/Eng_uk_f3_lua/content/voice", buildTimestamp: 1538659424000L, contentTypeMime: "x-guidance-voice/guidance-voice", packageCode: 681085, supplierName: "navngo", releaseReasonTitle: "NEW_VERSION", contentTypeCode: 3, downloadLocation: "https://download.naviextras.com/content/voice/NNG/Standard/v1/2018_10_04__15_23_44/Eng_uk_f3_lua/content/voice/Voice_Eng-uk-f3-lua.zip" },
		{ size: 1212, version: 1, fileName: "UnitedKingdom-TrafficMaster.tmc", contentIds:[1077936130], md5: "90bd4eef2da6281fcb029147171edd2f", country:"GBR", filePath: "/tmc/TrafficMaster/ALL/1.0/2011_06_02__17_20_00", buildTimestamp: 1307027811000L, contentTypeMime: "x-tmc/tmc", packageCode: 1003, supplierName: "trafficmaster", releaseReasonTitle: "NEW_VERSION", contentTypeCode: 12, downloadLocation: "https://download.naviextras.com/content/tmc/TrafficMaster/ALL/1.0/2011_06_02__17_20_00/UnitedKingdom-TrafficMaster.tmc" },
		{ size: 111571968, version: 1, fileName: "UnitedKingdom.fbl", contentIds:[7341247], md5: "8d4e8c9821921af193feee7785dc8487", country:"GBR", filePath: "/map/HERE/ALL/2022_Q4/2022_12_13__17_20_02", buildTimestamp: 1675339594000L, contentTypeMime: "x-tmc/tmc", packageCode: 1003, supplierName: "here", releaseReasonTitle: "NEW_VERSION", contentTypeCode: 1, downloadLocation: "https://download.naviextras.com/content/map/HERE/ALL/2022_Q4/2022_12_13__17_20_02/UnitedKingdom.fbl" },
	],
	//Update base package
	9715179: [
		{ size: 10315343, version: 13, fileName: "Belgium.poi", contentIds:[1082173846], md5: "a97404675729a061b8dcf22ce3a5fe00", country:"BEL", filePath: "/poi/HERE/ALL/2021_Q4/2021_12_03__08_43_00", buildTimestamp: 1672754314000L, contentTypeMime: "x-poi", packageCode: 172, supplierName: "here", releaseReasonTitle: "NEW_VERSION", contentTypeCode: 4, downloadLocation: "https://download.naviextras.com/content/poi/HERE/ALL/2022_Q4/2023_02_22__18_41_12/Belgium.poi" },
		{ size: 2208, version: 1, fileName: "Belgium-BeMobile-light.tmc", contentIds:[1077936207], md5: "493a32105e356a65c440700496e33257", country:"BEL", filePath: "/tmc/BeMobile/ALL/2.0/2011_06_02__16_20_00", buildTimestamp: 1307024408000L, contentTypeMime: "x-tmc/tmc", packageCode: 61940, supplierName: "bemobile", releaseReasonTitle: "NEW_VERSION", contentTypeCode: 12, downloadLocation: "https://download.naviextras.com/content/tmc/BeMobile/ALL/2.0/2011_06_02__16_20_00/Belgium-BeMobile-light.tmc" },
		{ size: 21219840, version: 1001, fileName: "Belgium.fbl", contentIds:[2106541], md5: "5f498c0ff473c286d234b65e921a8ec7", country:"BEL", filePath: "testdata", buildTimestamp: 1637943578000L, contentTypeMime: "x-map", packageCode: 993,supplierName: "here",  releaseReasonTitle: "NEW_VERSION", contentTypeCode: 1, downloadLocation: "https://cdns.distrib.naviextras.com/content/map/HERE/ALL/2021_Q2/2021_07_18__13_46_40/Belgium.fbl" },

		{ size: 3530, version: 100, fileName: "Bulgaria.spc", contentIds:[1124077232], md5: "1809588a4cecfa19def5025ecf9f07ea", country:"BGR", filePath: "/speedcam/HERE/ALL/2022_Q4/2023_02_22__19_13_00", buildTimestamp: 1671370804000L, contentTypeMime: "x-speedcam/spc", packageCode: 61119, supplierName: "here", releaseReasonTitle: "NEW_VERSION", contentTypeCode: 30, downloadLocation: "https://download.naviextras.com/content/speedcam/HERE/ALL/2022_Q4/2023_02_22__19_13_00/Bulgaria.spc" },
		{ size: 5970617, version: 100, fileName: "Bulgaria.poi", contentIds:[1082173766], md5: "0ea48f33ed758cbd40cf5603a9d10888", country:"BGR", filePath: "/poi/HERE/ALL/2022_Q4/2023_02_22__18_41_12", buildTimestamp: 1673634357000L, contentTypeMime: "x-poi", packageCode: 61119, supplierName: "here", releaseReasonTitle: "NEW_VERSION", contentTypeCode: 4, downloadLocation: "https://download.naviextras.com/content/poi/HERE/ALL/2022_Q4/2023_02_22__18_41_12/Bulgaria.poi" },
		{ size: 21009408, version: 100, fileName: "Bulgaria.fbl", contentIds:[3671231], md5: "55fca88e8d1876823c3b0c27cf23d8e5", country:"BGR", filePath: "/map/HERE/ALL/2022_Q4/2022_12_13__17_20_02", buildTimestamp: 1670952002000L, contentTypeMime: "x-map", packageCode: 61119, supplierName: "here", releaseReasonTitle: "NEW_VERSION", contentTypeCode: 1, downloadLocation: "https://download.naviextras.com/content/map/HERE/ALL/2022_Q4/2022_12_13__17_20_02/Bulgaria.fbl" },

		{ size: 61942, version: 537331225, fileName: "Voice_Deu-m4-lua.zip", contentIds:[1086328492], md5: "9d58ebc1786aebb354c1279b7e8d6cec", country:"DEU", filePath: "/voice/NNG/Standard/v1/2018_10_04__15_23_44/Deu_m4_lua/content/voice", buildTimestamp: 1538659424000L, contentTypeMime: "x-guidance-voice/guidance-voice", packageCode: 61942, supplierName: "navngo", releaseReasonTitle: "NEW_VERSION", contentTypeCode: 3, downloadLocation: "https://download.naviextras.com/content/voice/NNG/Standard/v1/2018_10_04__15_23_44/Deu_m4_lua/content/voice/Voice_Deu-m4-lua.zip" },
		{ size: 187601920, version: 1001, fileName: "Germany.fbl", contentIds:[8438957], md5: "03374dfac7c9a2a53d11cc8f3bff2603", country:"DEU", filePath: "testdata", buildTimestamp: 1637943578000L, contentTypeMime: "x-map", packageCode: 9911, supplierName: "here",  releaseReasonTitle: "NEW_VERSION", contentTypeCode: 1, downloadLocation: "https://cdns.distrib.naviextras.com/content/map/HERE/ALL/2021_Q2/2021_07_18__13_46_40/Germany.fbl" },

		{ size: 2360072, version: 537331225, fileName: "Voice_Eng-uk-f3-lua.zip", contentIds:[1086328505], md5: "128bd96a1ce79b9a390595e1ae7021b4", country:"GBR", filePath: "/voice/NNG/Standard/v1/2018_10_04__15_23_44/Eng_uk_f3_lua/content/voice", buildTimestamp: 1538659424000L, contentTypeMime: "x-guidance-voice/guidance-voice", packageCode: 681085, supplierName: "navngo", releaseReasonTitle: "NEW_VERSION", contentTypeCode: 3, downloadLocation: "https://download.naviextras.com/content/voice/NNG/Standard/v1/2018_10_04__15_23_44/Eng_uk_f3_lua/content/voice/Voice_Eng-uk-f3-lua.zip" },
		{ size: 1212, version: 1, fileName: "UnitedKingdom-TrafficMaster.tmc", contentIds:[1077936130], md5: "90bd4eef2da6281fcb029147171edd2f", country:"GBR", filePath: "/tmc/TrafficMaster/ALL/1.0/2011_06_02__17_20_00", buildTimestamp: 1307027811000L, contentTypeMime: "x-tmc/tmc", packageCode: 1003, supplierName: "trafficmaster", releaseReasonTitle: "NEW_VERSION", contentTypeCode: 12, downloadLocation: "https://download.naviextras.com/content/tmc/TrafficMaster/ALL/1.0/2011_06_02__17_20_00/UnitedKingdom-TrafficMaster.tmc" },
		{ size: 111571968, version: 1, fileName: "UnitedKingdom.fbl", contentIds:[7341247], md5: "8d4e8c9821921af193feee7785dc8487", country:"GBR", filePath: "/map/HERE/ALL/2022_Q4/2022_12_13__17_20_02", buildTimestamp: 1675339594000L, contentTypeMime: "x-tmc/tmc", packageCode: 1003, supplierName: "here", releaseReasonTitle: "NEW_VERSION", contentTypeCode: 1, downloadLocation: "https://download.naviextras.com/content/map/HERE/ALL/2022_Q4/2022_12_13__17_20_02/UnitedKingdom.fbl" },
	],
	//Update package
	9714179: [
		{ size: 10315343, version: 13, fileName: "Belgium.poi", contentIds:[1082173846], md5: "a97404675729a061b8dcf22ce3a5fe00", country:"BEL", filePath: "/poi/HERE/ALL/2021_Q4/2021_12_03__08_43_00", buildTimestamp: 1672754314000L, contentTypeMime: "x-poi", packageCode: 172, supplierName: "here", releaseReasonTitle: "NEW_VERSION", contentTypeCode: 4, downloadLocation: "https://download.naviextras.com/content/poi/HERE/ALL/2022_Q4/2023_02_22__18_41_12/Belgium.poi" },
		{ size: 2208, version: 1, fileName: "Belgium-BeMobile-light.tmc", contentIds:[1077936207], md5: "493a32105e356a65c440700496e33257", country:"BEL", filePath: "/tmc/BeMobile/ALL/2.0/2011_06_02__16_20_00", buildTimestamp: 1307024408000L, contentTypeMime: "x-tmc/tmc", packageCode: 61940, supplierName: "bemobile", releaseReasonTitle: "NEW_VERSION", contentTypeCode: 12, downloadLocation: "https://download.naviextras.com/content/tmc/BeMobile/ALL/2.0/2011_06_02__16_20_00/Belgium-BeMobile-light.tmc" },
		{ size: 21219840, version: 1001, fileName: "Belgium.fbl", contentIds:[2106541], md5: "5f498c0ff473c286d234b65e921a8ec7", country:"BEL", filePath: "testdata", buildTimestamp: 1637943578000L, contentTypeMime: "x-map", packageCode: 993,supplierName: "here",  releaseReasonTitle: "NEW_VERSION", contentTypeCode: 1, downloadLocation: "https://cdns.distrib.naviextras.com/content/map/HERE/ALL/2021_Q2/2021_07_18__13_46_40/Belgium.fbl" },

		{ size: 3530, version: 100, fileName: "Bulgaria.spc", contentIds:[1124077232], md5: "1809588a4cecfa19def5025ecf9f07ea", country:"BGR", filePath: "/speedcam/HERE/ALL/2022_Q4/2023_02_22__19_13_00", buildTimestamp: 1671370804000L, contentTypeMime: "x-speedcam/spc", packageCode: 61119, supplierName: "here", releaseReasonTitle: "NEW_VERSION", contentTypeCode: 30, downloadLocation: "https://download.naviextras.com/content/speedcam/HERE/ALL/2022_Q4/2023_02_22__19_13_00/Bulgaria.spc" },
		{ size: 5970617, version: 100, fileName: "Bulgaria.poi", contentIds:[1082173766], md5: "0ea48f33ed758cbd40cf5603a9d10888", country:"BGR", filePath: "/poi/HERE/ALL/2022_Q4/2023_02_22__18_41_12", buildTimestamp: 1673634357000L, contentTypeMime: "x-poi", packageCode: 61119, supplierName: "here", releaseReasonTitle: "NEW_VERSION", contentTypeCode: 4, downloadLocation: "https://download.naviextras.com/content/poi/HERE/ALL/2022_Q4/2023_02_22__18_41_12/Bulgaria.poi" },
		{ size: 21009408, version: 100, fileName: "Bulgaria.fbl", contentIds:[3671231], md5: "55fca88e8d1876823c3b0c27cf23d8e5", country:"BGR", filePath: "/map/HERE/ALL/2022_Q4/2022_12_13__17_20_02", buildTimestamp: 1670952002000L, contentTypeMime: "x-map", packageCode: 61119, supplierName: "here", releaseReasonTitle: "NEW_VERSION", contentTypeCode: 1, downloadLocation: "https://download.naviextras.com/content/map/HERE/ALL/2022_Q4/2022_12_13__17_20_02/Bulgaria.fbl" },
/*
		{ size: 61942, version: 537331225, fileName: "Voice_Deu-m4-lua.zip", contentIds:[1086328492], md5: "9d58ebc1786aebb354c1279b7e8d6cec", country:"DEU", filePath: "/voice/NNG/Standard/v1/2018_10_04__15_23_44/Deu_m4_lua/content/voice", buildTimestamp: 1538659424000L, contentTypeMime: "x-guidance-voice/guidance-voice", packageCode: 61942, supplierName: "navngo", releaseReasonTitle: "NEW_VERSION", contentTypeCode: 3, downloadLocation: "https://download.naviextras.com/content/voice/NNG/Standard/v1/2018_10_04__15_23_44/Deu_m4_lua/content/voice/Voice_Deu-m4-lua.zip" },
		{ size: 129946, version: 537331225, fileName: "Lang_German.zip", contentIds:[1090520536], md5: "9d58ebc1786aebb354c1279b7e8d6cec", country:"DEU", filePath: "/lang/NNG/LGE-Renault/v1/2023_02_24__15_02_24", buildTimestamp: 1538659424000L, contentTypeMime: "x-gui-language", packageCode: 121508, supplierName: "lge renault", releaseReasonTitle: "NEW_VERSION", contentTypeCode: 10, downloadLocation: "https://download.naviextras.com/content/lang/NNG/LGE-Renault/v1/2023_02_24__15_02_24/Lang_German.zip" },
		{ size: 187601920, version: 1001, fileName: "Germany.fbl", contentIds:[8438957], md5: "03374dfac7c9a2a53d11cc8f3bff2603", country:"DEU", filePath: "testdata", buildTimestamp: 1637943578000L, contentTypeMime: "x-map", packageCode: 9911, supplierName: "here",  releaseReasonTitle: "NEW_VERSION", contentTypeCode: 1, downloadLocation: "https://cdns.distrib.naviextras.com/content/map/HERE/ALL/2021_Q2/2021_07_18__13_46_40/Germany.fbl" },
*/
		{ size: 2360072, version: 537331225, fileName: "Voice_Eng-uk-f3-lua.zip", contentIds:[1086328505], md5: "128bd96a1ce79b9a390595e1ae7021b4", country:"GBR", filePath: "/voice/NNG/Standard/v1/2018_10_04__15_23_44/Eng_uk_f3_lua/content/voice", buildTimestamp: 1538659424000L, contentTypeMime: "x-guidance-voice/guidance-voice", packageCode: 681085, supplierName: "navngo", releaseReasonTitle: "NEW_VERSION", contentTypeCode: 3, downloadLocation: "https://download.naviextras.com/content/voice/NNG/Standard/v1/2018_10_04__15_23_44/Eng_uk_f3_lua/content/voice/Voice_Eng-uk-f3-lua.zip" },
		{ size: 1212, version: 1, fileName: "UnitedKingdom-TrafficMaster.tmc", contentIds:[1077936130], md5: "90bd4eef2da6281fcb029147171edd2f", country:"GBR", filePath: "/tmc/TrafficMaster/ALL/1.0/2011_06_02__17_20_00", buildTimestamp: 1307027811000L, contentTypeMime: "x-tmc/tmc", packageCode: 1003, supplierName: "trafficmaster", releaseReasonTitle: "NEW_VERSION", contentTypeCode: 12, downloadLocation: "https://download.naviextras.com/content/tmc/TrafficMaster/ALL/1.0/2011_06_02__17_20_00/UnitedKingdom-TrafficMaster.tmc" },
		{ size: 111571968, version: 1, fileName: "UnitedKingdom.fbl", contentIds:[7341247], md5: "8d4e8c9821921af193feee7785dc8487", country:"GBR", filePath: "/map/HERE/ALL/2022_Q4/2022_12_13__17_20_02", buildTimestamp: 1675339594000L, contentTypeMime: "x-tmc/tmc", packageCode: 1003, supplierName: "here", releaseReasonTitle: "NEW_VERSION", contentTypeCode: 1, downloadLocation: "https://download.naviextras.com/content/map/HERE/ALL/2022_Q4/2022_12_13__17_20_02/UnitedKingdom.fbl" },
	],
	//Africa
	1190170: [
		{ size: 4312064, version: 755, fileName: "Lesotho.fbl", contentIds:[106448051], md5: "bd751f7a82a9bf7fe75a4fad7968f7d2", country:"LSO", filePath: "/map/HERE/ALL/2021_Q4/2021_12_03__08_43_00", buildTimestamp: 1637943578000L, contentTypeMime: "x-map", packageCode: 172, supplierName: "here", releaseReasonTitle: "NEW_VERSION", contentTypeCode: 1, downloadLocation: "https://download.naviextras.com/content/map/HERE/ALL/2021_Q4/2021_12_03__08_43_00/Lesotho.fbl" },
		{ size: 10953216, version: 755, fileName: "Mozambique.fbl", contentIds:[106972339], md5: "69d919ede565c89e41c5b9cbb3a03c31", country:"MOZ", filePath: "/map/HERE/ALL/2021_Q4/2021_12_03__08_43_00", buildTimestamp: 1637943578000L, contentTypeMime: "x-map", packageCode: 174, supplierName: "here", releaseReasonTitle: "NEW_VERSION", contentTypeCode: 1, downloadLocation: "https://download.naviextras.com/content/map/HERE/ALL/2021_Q4/2021_12_03__08_43_00/Mozambique.fbl" },
		{ size: 5501440, version: 755, fileName: "Namibia.fbl", contentIds:[107496627], md5: "5fd80ef02a4f47957781ac2eff870f47", country:"NAM", filePath: "/map/HERE/ALL/2021_Q4/2021_12_03__08_43_00", buildTimestamp: 1637943578000L, contentTypeMime: "x-map", packageCode: 175, supplierName: "here", releaseReasonTitle: "NEW_VERSION", contentTypeCode: 1, downloadLocation: "https://download.naviextras.com/content/map/HERE/ALL/2021_Q4/2021_12_03__08_43_00/Namibia.fbl" },
	],
	//WEU
	999991: [
		{ size: 184832, version: 1001, fileName: "Andorra.fbl", contentIds:[1066157], md5: "a7e77ab74514283053275c2c92faf14f", country:"AND", filePath: "testdata", buildTimestamp: 1637943578000L, contentTypeMime: "x-map", packageCode: 991, supplierName: "here", releaseReasonTitle: "NEW_VERSION", contentTypeCode: 1, downloadLocation: "https://cdns.distrib.naviextras.com/content/map/HERE/ALL/2021_Q2/2021_07_18__13_46_40/Andorra.fbl" },
		{ size: 38376960, version: 1001, fileName: "Austria.fbl", contentIds:[1582253], md5: "86a735ef93faefd8777d573067abf3d6", country:"AUT", filePath: "testdata", buildTimestamp: 1637943578000L, contentTypeMime: "x-map", packageCode: 992, supplierName: "here", releaseReasonTitle: "NEW_VERSION", contentTypeCode: 1, downloadLocation: "https://cdns.distrib.naviextras.com/content/map/HERE/ALL/2021_Q2/2021_07_18__13_46_40/Austria.fbl" },
		{ size: 21219840, version: 1001, fileName: "Belgium.fbl", contentIds:[2106541], md5: "5f498c0ff473c286d234b65e921a8ec7", country:"BEL", filePath: "testdata", buildTimestamp: 1637943578000L, contentTypeMime: "x-map", packageCode: 993,supplierName: "here",  releaseReasonTitle: "NEW_VERSION", contentTypeCode: 1, downloadLocation: "https://cdns.distrib.naviextras.com/content/map/HERE/ALL/2021_Q2/2021_07_18__13_46_40/Belgium.fbl" },
		{ size: 27392000, version: 1001, fileName: "Switzerland.fbl", contentIds:[20464813], md5: "2fe90dbae11fadec6638edb9ee790ad8", country:"CHE", filePath: "testdata", buildTimestamp: 1637943578000L, contentTypeMime: "x-map", packageCode: 994, supplierName: "here", releaseReasonTitle: "NEW_VERSION", contentTypeCode: 1, downloadLocation: "https://cdns.distrib.naviextras.com/content/map/HERE/ALL/2021_Q2/2021_07_18__13_46_40/Switzerland.fbl" },
		{ size: 148044288, version: 1001, fileName: "Italy.fbl", contentIds:[10511533], md5: "13afa5bb0e9bcbb8171a02dc73eb9ea6", country:"ITA", filePath: "testdata", buildTimestamp: 1637943578000L, contentTypeMime: "x-map", packageCode: 998, supplierName: "here", releaseReasonTitle: "NEW_VERSION", contentTypeCode: 1, downloadLocation: "https://cdns.distrib.naviextras.com/content/map/HERE/ALL/2021_Q2/2021_07_18__13_46_40/Italy.fbl" },
		{ size: 187601920, version: 1001, fileName: "Germany.fbl", contentIds:[8438957], md5: "03374dfac7c9a2a53d11cc8f3bff2603", country:"DEU", filePath: "testdata", buildTimestamp: 1637943578000L, contentTypeMime: "x-map", packageCode: 9911, supplierName: "here",  releaseReasonTitle: "NEW_VERSION", contentTypeCode: 1, downloadLocation: "https://cdns.distrib.naviextras.com/content/map/HERE/ALL/2021_Q2/2021_07_18__13_46_40/Germany.fbl" },
		{ size: 235854336, version: 1001, fileName: "France.fbl", contentIds:[6849709], md5: "7f104c96c7e1d6f7a74b14536beeb000", country:"FRA", filePath: "testdata", buildTimestamp: 1637943578000L, contentTypeMime: "x-map", packageCode: 9912, supplierName: "here", releaseReasonTitle: "NEW_VERSION", contentTypeCode: 1, downloadLocation: "https://cdns.distrib.naviextras.com/content/map/HERE/ALL/2021_Q2/2021_07_18__13_46_40/France.fbl" },		
		{ size: 38594048, version: 1001, fileName: "Netherlands.fbl", contentIds:[14189741], md5: "4922c4f0533ca7b37972db324ef8c304", country:"NLD", filePath: "testdata", buildTimestamp: 1637943578000L, contentTypeMime: "x-map", packageCode: 997, supplierName: "here", releaseReasonTitle: "NEW_VERSION", contentTypeCode: 1, downloadLocation: "https://cdns.distrib.naviextras.com/content/map/HERE/ALL/2021_Q2/2021_07_18__13_46_40/Netherlands.fbl" },
		{ size: 2013184, version: 1001, fileName: "Luxembourg.fbl", contentIds:[12076205], md5: "4bb9767767b1ed4a1042ca05ba708264", country:"LUX", filePath: "testdata", buildTimestamp: 1637943578000L, contentTypeMime: "x-map", packageCode: 993, supplierName: "here", releaseReasonTitle: "NEW_VERSION", contentTypeCode: 1, downloadLocation: "https://cdns.distrib.naviextras.com/content/map/HERE/ALL/2021_Q2/2021_07_18__13_46_40/Luxembourg.fbl" },
		{ size: 53860352, version: 1001, fileName: "Portugal.fbl", contentIds:[15754413], md5: "2776989dd6b2d7354fa4d49d24d4771b", country:"PRT", filePath: "testdata", buildTimestamp: 1637943578000L, contentTypeMime: "x-map", packageCode: 996, supplierName: "here", releaseReasonTitle: "NEW_VERSION", contentTypeCode: 1, downloadLocation: "https://cdns.distrib.naviextras.com/content/map/HERE/ALL/2021_Q2/2021_07_18__13_46_40/Portugal.fbl" },
		{ size: 155912704, version: 1001, fileName: "Spain.fbl", contentIds:[19432621], md5: "4be5437d764d75dfa29f06cc44484d38", country:"ESP", filePath: "testdata", buildTimestamp: 1637943578000L, contentTypeMime: "x-map", packageCode: 995, supplierName: "here", releaseReasonTitle: "NEW_VERSION", contentTypeCode: 1, downloadLocation: "https://cdns.distrib.naviextras.com/content/map/HERE/ALL/2021_Q2/2021_07_18__13_46_40/Spain.fbl" },
	],
	//WEU OSM
	999998: [
		{ size: 243200, version: 755, fileName: "Andorra_osm.fbl", md5: "22291b8bcd7c3bfa2af49640e34c9a9a", country: "AND", filePath: "testdata", packageCode: 1177875, buildTimestamp: 1677589818000L, contentTypeMime: "x-map", releaseReasonTitle: "NEW_VERSION", contentTypeCode: 1, downloadLocation: "https://download.naviextras.com/content/map/OSMPlus/ALL/2022_02/2023_05_15__13_56_02/Andorra_osm.fbl", supplierCode: 3904417328557441L, supplierName: "openstreetmap.org", contentIds: [1052342]},
		{ size: 63683072, version: 3, fileName: "Austria_osm.fbl", md5: "b999b18994cd5ca57ba1f0344a05ca0b", country: "AUT", filePath: "testdata", packageCode: 1177835, buildTimestamp: 1683716557000L, contentTypeMime: "x-map", releaseReasonTitle: "NEW_VERSION", contentTypeCode: 1, downloadLocation: "https://download.naviextras.com/content/map/OSMPlus/ALL/2022_02/2023_05_15__13_56_02/Austria_osm.fbl", supplierCode: 3904417328557441L, supplierName: "openstreetmap.org", contentIds: [1576630]},
		{ size: 34173952, version: 3, fileName: "Belgium_osm.fbl", md5: "b373b41360f48c3b7badf35f5e12f92f", country: "BEL", filePath: "testdata", packageCode: 1178245, buildTimestamp: 1683716557000L, contentTypeMime: "x-map", releaseReasonTitle: "NEW_VERSION", contentTypeCode: 1, downloadLocation: "https://download.naviextras.com/content/map/OSMPlus/ALL/2022_02/2023_05_15__13_56_02/Belgium_osm.fbl", supplierCode: 3904417328557441L, supplierName: "openstreetmap.org", contentIds: [2100918]},
		{ size: 28667392, version: 13, fileName: "Denmark_osm.fbl", md5: "f69fd2a2c3fd43c0d9feec445d150157", country: "DNK", filePath: "testdata", packageCode: 1179155, buildTimestamp: 1683735679000L, contentTypeMime: "x-map", releaseReasonTitle: "NEW_VERSION", contentTypeCode: 1, downloadLocation: "https://download.naviextras.com/content/map/OSMPlus/ALL/2022_02/2023_05_15__13_56_02/Denmark_osm.fbl", supplierCode: 3904417328557441L, supplierName: "openstreetmap.org", contentIds: [5246646]},
		{ size: 895488, version: 755, fileName: "FaroeIslands_osm.fbl", md5: "500ea641951264acfc128d4ef6788336", country: "FRO", filePath: "testdata", packageCode: 1179215, buildTimestamp: 1681906727000L, contentTypeMime: "x-map", releaseReasonTitle: "NEW_VERSION", contentTypeCode: 1, downloadLocation: "https://download.naviextras.com/content/map/OSMPlus/ALL/2022_02/2023_05_15__13_56_02/FaroeIslands_osm.fbl", supplierCode: 3904417328557441L, supplierName: "openstreetmap.org", contentIds: [27266230]},
		{ size: 83691008, version: 3, fileName: "Finland_osm.fbl", md5: "e0a1aace600881d9d4461e0208f84e9e", country: "FIN", filePath: "testdata", packageCode: 1179245, buildTimestamp: 1683735679000L, contentTypeMime: "x-map", releaseReasonTitle: "NEW_VERSION", contentTypeCode: 1, downloadLocation: "https://download.naviextras.com/content/map/OSMPlus/ALL/2022_02/2023_05_15__13_56_02/Finland_osm.fbl", supplierCode: 3904417328557441L, supplierName: "openstreetmap.org", contentIds: [6295222]  },
		{ size: 338631680, version: 12, fileName: "France_osm.fbl", md5: "c224f5c3cb0d39823260a6dfa8538099", country: "FRA", filePath: "testdata", packageCode: 1174215, buildTimestamp: 1683716557000L, contentTypeMime: "x-map", releaseReasonTitle: "NEW_VERSION", contentTypeCode: 1, downloadLocation: "https://download.naviextras.com/content/map/OSMPlus/ALL/2022_02/2023_05_15__13_56_02/France_osm.fbl", supplierCode: 3904417328557441L, supplierName: "openstreetmap.org", contentIds: [6819510]  },
		{ size: 1672192, version: 755, fileName: "FrenchGuiana_osm.fbl", md5: "b91629e213db7d1fdaf7485442efe43f", country: "GUF", filePath: "testdata", packageCode: 1179285, buildTimestamp: 1681483877000L, contentTypeMime: "x-map", releaseReasonTitle: "NEW_VERSION", contentTypeCode: 1, downloadLocation: "https://download.naviextras.com/content/map/OSMPlus/ALL/2022_02/2023_05_15__13_56_02/FrenchGuiana_osm.fbl", supplierCode: 3904417328557441L, supplierName: "openstreetmap.org", contentIds: [263720118]  },
		{ size: 308281856, version: 20, fileName: "Germany_osm.fbl", md5: "dfe0867032b1da5fe24b62254c0bb688", country: "DEU", filePath: "testdata", packageCode: 1177635, buildTimestamp: 1683716557000L, contentTypeMime: "x-map", releaseReasonTitle: "NEW_VERSION", contentTypeCode: 1, downloadLocation: "https://download.naviextras.com/content/map/OSMPlus/ALL/2022_02/2023_05_15__13_56_02/Germany_osm.fbl", supplierCode: 3904417328557441L, supplierName: "openstreetmap.org", contentIds: [8392886]  },
		{ size: 103424, version: 755, fileName: "Gibraltar_osm.fbl", md5: "bdef84062bb17a70b52b7ae6f4266c1b", country: "GIB", filePath: "testdata", packageCode: 1179355, buildTimestamp: 1677748396000L, contentTypeMime: "x-map", releaseReasonTitle: "NEW_VERSION", contentTypeCode: 1, downloadLocation: "https://download.naviextras.com/content/map/OSMPlus/ALL/2022_02/2023_05_15__13_56_02/Gibraltar_osm.fbl", supplierCode: 3904417328557441L, supplierName: "openstreetmap.org", contentIds: [22023862]  },
		{ size: 49067008, version: 755, fileName: "Greece_osm.fbl", md5: "6945fcf6ea201b603deae29a5616bb07", country: "GRC", filePath: "testdata", packageCode: 1179375, buildTimestamp: 1682509871000L, contentTypeMime: "x-map", releaseReasonTitle: "NEW_VERSION", contentTypeCode: 1, downloadLocation: "https://download.naviextras.com/content/map/OSMPlus/ALL/2022_02/2023_05_15__13_56_02/Greece_osm.fbl", supplierCode: 3904417328557441L, supplierName: "openstreetmap.org", contentIds: [8916150]  },
		{ size: 1466368, version: 755, fileName: "Guadeloupe_osm.fbl", md5: "833679cd304071cc25980a1b44c73354", country: "GLP", filePath: "testdata", packageCode: 1179405, buildTimestamp: 1681761934000L, contentTypeMime: "x-map", releaseReasonTitle: "NEW_VERSION", contentTypeCode: 1, downloadLocation: "https://download.naviextras.com/content/map/OSMPlus/ALL/2022_02/2023_05_15__13_56_02/Guadeloupe_osm.fbl", supplierCode: 3904417328557441L, supplierName: "openstreetmap.org", contentIds: [264244406]  },
		{ size: 9865728, version: 755, fileName: "Iceland_osm.fbl", md5: "c31a489f2f6f379429f78dc4215118ba", country: "ISL", filePath: "testdata", packageCode: 1179425, buildTimestamp: 1681906727000L, contentTypeMime: "x-map", releaseReasonTitle: "NEW_VERSION", contentTypeCode: 1, downloadLocation: "https://download.naviextras.com/content/map/OSMPlus/ALL/2022_02/2023_05_15__13_56_02/Iceland_osm.fbl", supplierCode: 3904417328557441L, supplierName: "openstreetmap.org", contentIds: [28839094]  },
		{ size: 39095808, version: 755, fileName: "Ireland_osm.fbl", md5: "2727c15c401e3d38f7a7080cfa9c031f", country: "IRL", filePath: "testdata", packageCode: 1179455, buildTimestamp: 1684151782000L, contentTypeMime: "x-map", releaseReasonTitle: "NEW_VERSION", contentTypeCode: 1, downloadLocation: "https://download.naviextras.com/content/map/OSMPlus/ALL/2022_02/2023_05_15__13_56_02/Ireland_osm.fbl", supplierCode: 3904417328557441L, supplierName: "openstreetmap.org", contentIds: [9964726]  },
		{ size: 181418496, version: 4, fileName: "Italy_osm.fbl", md5: "4cea637b91a8a5019f6959d12fb2f9cc", country: "ITA", filePath: "testdata", packageCode: 1177715, buildTimestamp: 1683737693000L, contentTypeMime: "x-map", releaseReasonTitle: "NEW_VERSION", contentTypeCode: 1, downloadLocation: "https://download.naviextras.com/content/map/OSMPlus/ALL/2022_02/2023_05_15__13_56_02/Italy_osm.fbl", supplierCode: 3904417328557441L, supplierName: "openstreetmap.org", contentIds: [10489526]  },
		{ size: 188928, version: 755, fileName: "Liechtenstein_osm.fbl", md5: "dabb305f0b5dc67e0dea899371820599", country: "LIE", filePath: "testdata", packageCode: 1179575, buildTimestamp: 1677264798000L, contentTypeMime: "x-map", releaseReasonTitle: "NEW_VERSION", contentTypeCode: 1, downloadLocation: "https://download.naviextras.com/content/map/OSMPlus/ALL/2022_02/2023_05_15__13_56_02/Liechtenstein_osm.fbl", supplierCode: 3904417328557441L, supplierName: "openstreetmap.org", contentIds: [22548150]  },
		{ size: 3676160, version: 3, fileName: "Luxembourg_osm.fbl", md5: "0ad941efdcad563515968234488f4b56", country: "LUX", filePath: "testdata", packageCode: 1178285, buildTimestamp: 1683046951000L, contentTypeMime: "x-map", releaseReasonTitle: "NEW_VERSION", contentTypeCode: 1, downloadLocation: "https://download.naviextras.com/content/map/OSMPlus/ALL/2022_02/2023_05_15__13_56_02/Luxembourg_osm.fbl", supplierCode: 3904417328557441L, supplierName: "openstreetmap.org", contentIds: [12062390]  },
		{ size: 817664, version: 755, fileName: "Malta_osm.fbl", md5: "f02ea9f1530aae8b51795464511a2227", country: "MLT", filePath: "testdata", packageCode: 1179635, buildTimestamp: 1683037030000L, contentTypeMime: "x-map", releaseReasonTitle: "NEW_VERSION", contentTypeCode: 1, downloadLocation: "https://download.naviextras.com/content/map/OSMPlus/ALL/2022_02/2023_05_15__13_56_02/Malta_osm.fbl", supplierCode: 3904417328557441L, supplierName: "openstreetmap.org", contentIds: [26741942]  },
		{ size: 1234944, version: 755, fileName: "Martinique_osm.fbl", md5: "f62cbbedd1e200bb340ea9e0d90b19d8", country: "MTQ", filePath: "testdata", packageCode: 1179665, buildTimestamp: 1681761934000L, contentTypeMime: "x-map", releaseReasonTitle: "NEW_VERSION", contentTypeCode: 1, downloadLocation: "https://download.naviextras.com/content/map/OSMPlus/ALL/2022_02/2023_05_15__13_56_02/Martinique_osm.fbl", supplierCode: 3904417328557441L, supplierName: "openstreetmap.org", contentIds: [264768694]  },
		{ size: 367616, version: 755, fileName: "Mayotte_osm.fbl", md5: "aa3521b9d8f65747a1492af11c4591a2", country: "MYT", filePath: "testdata", packageCode: 1179685, buildTimestamp: 1682363620000L, contentTypeMime: "x-map", releaseReasonTitle: "NEW_VERSION", contentTypeCode: 1, downloadLocation: "https://download.naviextras.com/content/map/OSMPlus/ALL/2022_02/2023_05_15__13_56_02/Mayotte_osm.fbl", supplierCode: 3904417328557441L, supplierName: "openstreetmap.org", contentIds: [265292982]  },
		{ size: 49152, version: 755, fileName: "Monaco_osm.fbl", md5: "a74176644290ba78848e2e31fadd70d6", country: "MCO", filePath: "testdata", packageCode: 1179735, buildTimestamp: 1681900266000L, contentTypeMime: "x-map", releaseReasonTitle: "NEW_VERSION", contentTypeCode: 1, downloadLocation: "https://download.naviextras.com/content/map/OSMPlus/ALL/2022_02/2023_05_15__13_56_02/Monaco_osm.fbl", supplierCode: 3904417328557441L, supplierName: "openstreetmap.org", contentIds: [23072438]  },
		{ size: 33656320, version: 755, fileName: "Morocco_osm.fbl", md5: "cb03499a51ee95d5a4e60fbf2ff883cf", country: "MAR", filePath: "testdata", packageCode: 1179795, buildTimestamp: 1682091634000L, contentTypeMime: "x-map", releaseReasonTitle: "NEW_VERSION", contentTypeCode: 1, downloadLocation: "https://download.naviextras.com/content/map/OSMPlus/ALL/2022_02/2023_05_15__13_56_02/Morocco_osm.fbl", supplierCode: 3904417328557441L, supplierName: "openstreetmap.org", contentIds: [110628534]  },
		{ size: 57641984, version: 9, fileName: "Netherlands_osm.fbl", md5: "038d60c403d5eb71231ffd773a7176dd", country: "NLD", filePath: "testdata", packageCode: 1178325, buildTimestamp: 1684142418000L, contentTypeMime: "x-map", releaseReasonTitle: "NEW_VERSION", contentTypeCode: 1, downloadLocation: "https://download.naviextras.com/content/map/OSMPlus/ALL/2022_02/2023_05_15__13_56_02/Netherlands_osm.fbl", supplierCode: 3904417328557441L, supplierName: "openstreetmap.org", contentIds: [14159542]  },
		{ size: 132906496, version: 6, fileName: "Norway_osm.fbl", md5: "ce115ee40f53139a441ac62302e3321c", country: "NOR", filePath: "testdata", packageCode: 1179835, buildTimestamp: 1683735679000L, contentTypeMime: "x-map", releaseReasonTitle: "NEW_VERSION", contentTypeCode: 1, downloadLocation: "https://download.naviextras.com/content/map/OSMPlus/ALL/2022_02/2023_05_15__13_56_02/Norway_osm.fbl", supplierCode: 3904417328557441L, supplierName: "openstreetmap.org", contentIds: [14683830]  },
		{ size: 50918400, version: 755, fileName: "Portugal_osm.fbl", md5: "1df7fc21f0d17da128862159f7ce2734", country: "PRT", filePath: "testdata", packageCode: 1179895, buildTimestamp: 1681941922000L, contentTypeMime: "x-map", releaseReasonTitle: "NEW_VERSION", contentTypeCode: 1, downloadLocation: "https://download.naviextras.com/content/map/OSMPlus/ALL/2022_02/2023_05_15__13_56_02/Portugal_osm.fbl", supplierCode: 3904417328557441L, supplierName: "openstreetmap.org", contentIds: [15732406]  },
		{ size: 1984512, version: 755, fileName: "Reunion_osm.fbl", md5: "4cfa14473508dc4fea917644be3894ff", country: "REU", filePath: "testdata", packageCode: 1179925, buildTimestamp: 1680200347000L, contentTypeMime: "x-map", releaseReasonTitle: "NEW_VERSION", contentTypeCode: 1, downloadLocation: "https://download.naviextras.com/content/map/OSMPlus/ALL/2022_02/2023_05_15__13_56_02/Reunion_osm.fbl", supplierCode: 3904417328557441L, supplierName: "openstreetmap.org", contentIds: [127405238]  },
		{ size: 116736, version: 755, fileName: "SaintPierreandMiquelon_osm.fbl", md5: "2c06f423cf4d7948279bf0bfab8d6a1b", country: "SPM", filePath: "testdata", packageCode: 1179955, buildTimestamp: 1681762052000L, contentTypeMime: "x-map", releaseReasonTitle: "NEW_VERSION", contentTypeCode: 1, downloadLocation: "https://download.naviextras.com/content/map/OSMPlus/ALL/2022_02/2023_05_15__13_56_02/SaintPierreandMiquelon_osm.fbl", supplierCode: 3904417328557441L, supplierName: "openstreetmap.org", contentIds: [291505334]  },
		{ size: 164665856, version: 4, fileName: "Spain_osm.fbl", md5: "84a13561eb519c19ccf70a6ef0a6b617", country: "ESP", filePath: "testdata", packageCode: 1180055, buildTimestamp: 1683896999000L, contentTypeMime: "x-map", releaseReasonTitle: "NEW_VERSION", contentTypeCode: 1, downloadLocation: "https://download.naviextras.com/content/map/OSMPlus/ALL/2022_02/2023_05_15__13_56_02/Spain_osm.fbl", supplierCode: 3904417328557441L, supplierName: "openstreetmap.org", contentIds: [19402422]  },
		{ size: 79637504, version: 755, fileName: "Sweden_osm.fbl", md5: "6c2791f09ba759cf205c203a0e6c5d26", country: "SWE", filePath: "testdata", packageCode: 1180085, buildTimestamp: 1681906727000L, contentTypeMime: "x-map", releaseReasonTitle: "NEW_VERSION", contentTypeCode: 1, downloadLocation: "https://download.naviextras.com/content/map/OSMPlus/ALL/2022_02/2023_05_15__13_56_02/Sweden_osm.fbl", supplierCode: 3904417328557441L, supplierName: "openstreetmap.org", contentIds: [19926710]  },
		{ size: 36263424, version: 7, fileName: "Switzerland_osm.fbl", md5: "5fd27541558554aa123e6c8dce53718e", country: "CHE", filePath: "testdata", packageCode: 1177795, buildTimestamp: 1683716557000L, contentTypeMime: "x-map", releaseReasonTitle: "NEW_VERSION", contentTypeCode: 1, downloadLocation: "https://download.naviextras.com/content/map/OSMPlus/ALL/2022_02/2023_05_15__13_56_02/Switzerland_osm.fbl", supplierCode: 3904417328557441L, supplierName: "openstreetmap.org", contentIds: [20450998]  },
		{ size: 13508096, version: 755, fileName: "Tunisia_osm.fbl", md5: "c2ae60e2045a4e2e620f16a9cc112421", country: "TUN", filePath: "testdata", packageCode: 1180115, buildTimestamp: 1682091634000L, contentTypeMime: "x-map", releaseReasonTitle: "NEW_VERSION", contentTypeCode: 1, downloadLocation: "https://download.naviextras.com/content/map/OSMPlus/ALL/2022_02/2023_05_15__13_56_02/Tunisia_osm.fbl", supplierCode: 3904417328557441L, supplierName: "openstreetmap.org", contentIds: [133172918]  },
		{ size: 226957824, version: 6, fileName: "UnitedKingdom_osm.fbl", md5: "131c15a0d9c4f82befa569d0f0783aec", country: "GBR", filePath: "testdata", packageCode: 1180225, buildTimestamp: 1683795609000L, contentTypeMime: "x-map", releaseReasonTitle: "NEW_VERSION", contentTypeCode: 1, downloadLocation: "https://download.naviextras.com/content/map/OSMPlus/ALL/2022_02/2023_05_15__13_56_02/UnitedKingdom_osm.fbl", supplierCode: 3904417328557441L, supplierName: "openstreetmap.org", contentIds: [7343286]  },
		{ size: 13312, version: 755, fileName: "Vatican_osm.fbl", md5: "4af00b5c57cfb468e375eeea0934299c", country: "VAT", filePath: "testdata", packageCode: 1180255, buildTimestamp: 1676366189000L, contentTypeMime: "x-map", releaseReasonTitle: "NEW_VERSION", contentTypeCode: 1, downloadLocation: "https://download.naviextras.com/content/map/OSMPlus/ALL/2022_02/2023_05_15__13_56_02/Vatican_osm.fbl", supplierCode: 3904417328557441L, supplierName: "openstreetmap.org", contentIds: [23596726]  },
		{ size: 166912, version: 755, fileName: "SanMarino_osm.fbl", md5: "45ae63187ff74867f4c029d302d4cdde", country: "SMR", filePath: "testdata", packageCode: 1181205, buildTimestamp: 1676976985000L, contentTypeMime: "x-map", releaseReasonTitle: "NEW_VERSION", contentTypeCode: 1, downloadLocation: "https://download.naviextras.com/content/map/OSMPlus/ALL/2022_02/2023_05_15__13_56_02/SanMarino_osm.fbl", supplierCode: 3904417328557441, supplierName: "openstreetmap.org", contentIds: [17305270]  }
	],

	// Italy OSM
	999000: [
		{ size: 181418496, version: 4, fileName: "Italy_osm.fbl", md5: "4cea637b91a8a5019f6959d12fb2f9cc", country: "ITA", filePath: "testdata", packageCode: 1177715, buildTimestamp: 1683737693000L, contentTypeMime: "x-map", releaseReasonTitle: "NEW_VERSION", contentTypeCode: 1, downloadLocation: "https://download.naviextras.com/content/map/OSMPlus/ALL/2022_02/2023_05_15__13_56_02/Italy_osm.fbl", supplierCode: 3904417328557441L, supplierName: "openstreetmap.org", contentIds: [10489526]  },
	],

	//Iberia
	999981: [
		{ size: 155912704, version: 1001, fileName: "Spain.fbl", contentIds:[19432621], md5: "4be5437d764d75dfa29f06cc44484d38", country:"ESP", filePath: "testdata", buildTimestamp: 1637943578000L, contentTypeMime: "x-map", packageCode: 995, supplierName: "here", releaseReasonTitle: "NEW_VERSION", contentTypeCode: 1, downloadLocation: "https://cdns.distrib.naviextras.com/content/map/HERE/ALL/2021_Q2/2021_07_18__13_46_40/Spain.fbl" },
		{ size: 184832, version: 1001, fileName: "Andorra.fbl", contentIds:[1066157], md5: "a7e77ab74514283053275c2c92faf14f", country:"AND", filePath: "testdata", buildTimestamp: 1637943578000L, contentTypeMime: "x-map", packageCode: 991, supplierName: "here", releaseReasonTitle: "NEW_VERSION", contentTypeCode: 1, downloadLocation: "https://cdns.distrib.naviextras.com/content/map/HERE/ALL/2021_Q2/2021_07_18__13_46_40/Andorra.fbl" },
		{ size: 53860352, version: 1001, fileName: "Portugal.fbl", contentIds:[15754413], md5: "2776989dd6b2d7354fa4d49d24d4771b", country:"PRT", filePath: "testdata", buildTimestamp: 1637943578000L, contentTypeMime: "x-map", packageCode: 996, supplierName: "here", releaseReasonTitle: "NEW_VERSION", contentTypeCode: 1, downloadLocation: "https://cdns.distrib.naviextras.com/content/map/HERE/ALL/2021_Q2/2021_07_18__13_46_40/Portugal.fbl" },
	],
	//Benelux
	999971: [
		{ size: 21219840, version: 1001, fileName: "Belgium.fbl", contentIds:[2106541], md5: "5f498c0ff473c286d234b65e921a8ec7", country:"BEL", filePath: "testdata", buildTimestamp: 1637943578000L, contentTypeMime: "x-map", packageCode: 993, supplierName: "here", releaseReasonTitle: "NEW_VERSION", contentTypeCode: 1, downloadLocation: "https://cdns.distrib.naviextras.com/content/map/HERE/ALL/2021_Q2/2021_07_18__13_46_40/Belgium.fbl" },
		{ size: 38594048, version: 1001, fileName: "Netherlands.fbl", contentIds:[14189741], md5: "4922c4f0533ca7b37972db324ef8c304", country:"NL", filePath: "testdata", buildTimestamp: 1637943578000L, contentTypeMime: "x-map", packageCode: 997, supplierName: "here", releaseReasonTitle: "NEW_VERSION", contentTypeCode: 1, downloadLocation: "https://cdns.distrib.naviextras.com/content/map/HERE/ALL/2021_Q2/2021_07_18__13_46_40/Netherlands.fbl" },
		{ size: 2013184, version: 1001, fileName: "Luxembourg.fbl", contentIds:[12076205], md5: "4bb9767767b1ed4a1042ca05ba708264", country:"LUX", filePath: "testdata", buildTimestamp: 1637943578000L, contentTypeMime: "x-map", packageCode: 993, supplierName: "here", releaseReasonTitle: "NEW_VERSION", contentTypeCode: 1, downloadLocation: "https://cdns.distrib.naviextras.com/content/map/HERE/ALL/2021_Q2/2021_07_18__13_46_40/Luxembourg.fbl" },
	],
	//Apennine
	999961: [
		{ size: 148044288, version: 1001, fileName: "Italy.fbl", contentIds:[10511533], md5: "13afa5bb0e9bcbb8171a02dc73eb9ea6", country:"ITA", filePath: "testdata", buildTimestamp: 1637943578000L, contentTypeMime: "x-map", packageCode: 998, supplierName: "here", releaseReasonTitle: "NEW_VERSION", contentTypeCode: 1, downloadLocation: "https://cdns.distrib.naviextras.com/content/map/HERE/ALL/2021_Q2/2021_07_18__13_46_40/Italy.fbl" },
		{ size: 108544, version: 1001, fileName: "SanMarino.fbl", contentIds:[17319085], md5: "3039c7839b4c200d9a282d69eb3b0987", country:"SMR", filePath: "testdata", buildTimestamp: 1637943578000L, contentTypeMime: "x-map", packageCode: 999, supplierName: "here", releaseReasonTitle: "NEW_VERSION", contentTypeCode: 1, downloadLocation: "https://cdns.distrib.naviextras.com/content/map/HERE/ALL/2021_Q2/2021_07_18__13_46_40/SanMarino.fbl" },
		{ size: 13824, version: 1001, fileName: "Vatican.fbl", contentIds:[23610541], md5: "a745aceb6acaecda5c10486c15359441", country:"VAT", filePath: "testdata", buildTimestamp: 1637943578000L, contentTypeMime: "x-map", packageCode: 9991, supplierName: "here",  releaseReasonTitle: "NEW_VERSION", contentTypeCode: 1, downloadLocation: "https://cdns.distrib.naviextras.com/content/map/HERE/ALL/2021_Q2/2021_07_18__13_46_40/Vatican.fbl" },
	],
	//Italy
	999951: [
		{ size: 148044288, version: 1001, fileName: "Italy.fbl", contentIds:[10511533], md5: "13afa5bb0e9bcbb8171a02dc73eb9ea6", country:"ITA", filePath: "testdata", buildTimestamp: 1637943578000L, contentTypeMime: "x-map", packageCode: 998, supplierName: "here", releaseReasonTitle: "NEW_VERSION", contentTypeCode: 1, downloadLocation: "https://cdns.distrib.naviextras.com/content/map/HERE/ALL/2021_Q2/2021_07_18__13_46_40/Italy.fbl" },
	],
	//Spain
	999941: [
		{ size: 155912704, version: 1001, fileName: "Spain.fbl", contentIds:[19432621], md5: "4be5437d764d75dfa29f06cc44484d38", country:"ESP", filePath: "testdata", buildTimestamp: 1637943578000L, contentTypeMime: "x-map", packageCode: 995, supplierName: "here", releaseReasonTitle: "NEW_VERSION", contentTypeCode: 1, downloadLocation: "https://cdns.distrib.naviextras.com/content/map/HERE/ALL/2021_Q2/2021_07_18__13_46_40/Spain.fbl" },
	],	
	//Germany
	999931: [
		{ size: 187601920, version: 1001, fileName: "Germany.fbl", contentIds:[8438957], md5: "03374dfac7c9a2a53d11cc8f3bff2603", country:"DEU", filePath: "testdata", buildTimestamp: 1637943578000L, contentTypeMime: "x-map", packageCode: 9911, supplierName: "here",  releaseReasonTitle: "NEW_VERSION", contentTypeCode: 1, downloadLocation: "https://cdns.distrib.naviextras.com/content/map/HERE/ALL/2021_Q2/2021_07_18__13_46_40/Germany.fbl" },
	],
	//France
	999921: [
		{ size: 235854336, version: 1001, fileName: "France.fbl", contentIds:[6849709], md5: "7f104c96c7e1d6f7a74b14536beeb000", country:"FRA", filePath: "testdata", buildTimestamp: 1637943578000L, contentTypeMime: "x-map", packageCode: 9912, supplierName: "here", releaseReasonTitle: "NEW_VERSION", contentTypeCode: 1, downloadLocation: "https://cdns.distrib.naviextras.com/content/map/HERE/ALL/2021_Q2/2021_07_18__13_46_40/France.fbl" },		
	],
};

export getMockContents( package, purchase ) {
	let code = package.snapshot.snapshotCode;
	return getMockContentsBySnapshot( code, purchase );
}

export getMockContentsBySnapshot( code, purchase ){
	let res = [];
	let mock = Contents[code];
	for (let item in mock)
		res.push( purchase ? new PurchasedContent( item ) : new Content(item)  );
	return res;	
}

export list CommonPackages [
	Package{	salesPackage=[ (getMockSalesPackage( @Africa1 )), (getMockSalesPackage( @Africa2 )) ]; 
				locale = (new Description({ title: "Map of South Africa long-long-long title", shortDescription: "Maps of Mauritius, South Africa, Swaziland, Lesotho, Namibia, Botswana, Zimbabwe, Mozambique for Renault/Dacia. Long description test so repeat it twice: Maps of Mauritius, South Africa, Swaziland, Lesotho, Namibia, Botswana, Zimbabwe, Mozambique for Renault/Dacia. Maps of Mauritius, South Africa, Swaziland, Lesotho, Namibia, Botswana, Zimbabwe, Mozambique for Renault/Dacia. Maps of Mauritius, South Africa, Swaziland, Lesotho, Namibia, Botswana, Zimbabwe, Mozambique for Renault/Dacia.", descriptionId: 0L, timestamp: 0 })); 
				packageCode = 131266; 
				snapshot = ( new Snapshot( Snapshots.Africa ) );
			},
	Package{	salesPackage=[ (getMockSalesPackage( @WEU1 )), (getMockSalesPackage( @WEU2 )), (getMockSalesPackage( @WEU3 )) ]; 
				locale = (new Description({ title: "Western Europe", shortDescription: "Map of Western Europe. Contains: Andorra, Austria, Belgium, Switzerland, Italy, Germany, France, Spain, Portugal, Luxembourg.", descriptionId: 0L, timestamp: 0L })); 
				packageCode = 9999; 
				snapshot = ( new Snapshot( Snapshots.WEU ) );
			},
	Package{	salesPackage=[ (getMockSalesPackage( @WEU1 )), (getMockSalesPackage( @WEU3 )) ]; 
				locale = (new Description({ title: "Western Europe - NNG Maps (OSM)", shortDescription: "Map of Western Europe. Contains: Andorra, Austria, Belgium, Switzerland, Italy, Germany, France, Spain, Portugal, Luxembourg.", descriptionId: 0L, timestamp: 0L })); 
				packageCode = 8899; 
				snapshot = ( new Snapshot( Snapshots.WEU_OSM ) );
			},
	Package{	salesPackage=[ (getMockSalesPackage( @Iberia1 )), (getMockSalesPackage( @Iberia2 )) ]; 
				locale = (new Description({ title: "Iberia", shortDescription: "Map of Iberian Peninsula. Contains: Map of Spain, Portugal and Andorra.", descriptionId: 0L, timestamp: 0L })); 
				packageCode = 9998; 
				snapshot = ( new Snapshot( Snapshots.Iberia ) );
			},		
	Package{	salesPackage=[ (getMockSalesPackage( @Apennine1 )), (getMockSalesPackage( @Apennine2 )) ]; 
				locale = (new Description({ title: "Apennine", shortDescription: "Map of Italy including San Marino and Vatican for Renault/Dacia.", descriptionId: 0L, timestamp: 0L })); 
				packageCode = 9996; 
				snapshot = ( new Snapshot( Snapshots.Apennine ) );
		},
	Package{	salesPackage=[ (getMockSalesPackage( @Kamu )) ]; 
				locale = (new Description({ title: "Szupeeerrr Kamu Mega package.", shortDescription: "Szupeeerrr Kamu Mega package. - TMC, Lang, POI, speedcam and every kind of fake stuff.", descriptionId: 0L, timestamp: 0L })); 
				packageCode = 97179; 
				snapshot = ( new Snapshot( Snapshots.Kamu ) );
		},
]

export list PackagesWithoutVoucher [
	Package{	salesPackage=[ (getMockSalesPackage( @Benelux1 )), (getMockSalesPackage( @Benelux2 )) ]; 
				locale = (new Description({ title: "BeNeLux Countries", shortDescription: "Maps of Belgium, Netherlands and Luxembourg for Renault/Dacia.", descriptionId: 0L, timestamp: 0L })); 
				packageCode = 9997; 
				snapshot = ( new Snapshot( Snapshots.Benelux ) );
		},
	Package{	salesPackage=[ (getMockSalesPackage( @Italy )) ]; 
				locale = (new Description({ title: "Italy", shortDescription: "Map of Italy (excluding San Marino and Vatican).", descriptionId: 0L, timestamp: 0L })); 
				packageCode = 9995; 
				snapshot = ( new Snapshot( Snapshots.Italy ) );
		},		
	Package{	salesPackage=[ (getMockSalesPackage( @France )) ]; 
				locale = (new Description({ title: "France", shortDescription: "Map of France for Renault/Dacia.", descriptionId: 0L, timestamp: 0L })); 
				packageCode = 9992; 
				snapshot = ( new Snapshot( Snapshots.France ) );
		},	
];

export list PackagesWithoutScratch [
	Package{	salesPackage=[ (getMockSalesPackage( @Spain )) ]; 
				locale = (new Description({ title: "Spain", shortDescription: "Map of Spain for Renault/Dacia.", descriptionId: 0L, timestamp: 0L })); 
				packageCode = 9994;
				snapshot = ( new Snapshot( Snapshots.Spain ) ); 
		},	
	Package{	salesPackage=[ (getMockSalesPackage( @Germany )) ]; 
				locale = (new Description({ title: "Germany", shortDescription: "Map of Germany for Renault/Dacia.", descriptionId: 0L, timestamp: 0L })); 
				packageCode = 9993; 
				snapshot = ( new Snapshot( Snapshots.Germany ) );
		},	
];

export list PackagesWithVoucher [
	Package{	salesPackage=[ (getMockSalesPackage( @Benelux1 )), (getMockSalesPackage( @Benelux2, @voucher )) ]; 
				locale = (new Description({ title: "BeNeLux Countries", shortDescription: "Maps of Belgium, Netherlands and Luxembourg for Renault/Dacia.", descriptionId: 0L, timestamp: 0L })); 
				packageCode = 9997; 
				snapshot = ( new Snapshot( Snapshots.Benelux ) );
			},
	Package{	salesPackage=[ (getMockSalesPackage( @Italy, @voucher )) ]; 
				locale = (new Description({ title: "Italy", shortDescription: "Map of Italy (excluding San Marino and Vatican).", descriptionId: 0L, timestamp: 0L })); 
				packageCode = 9995; 
				snapshot = ( new Snapshot( Snapshots.Italy ) );
		},		
	Package{	salesPackage=[ (getMockSalesPackage( @France, @voucher )) ]; 
				locale = (new Description({ title: "France", shortDescription: "Map of France for Renault/Dacia.", descriptionId: 0L, timestamp: 0L })); 
				packageCode = 9992; 
				snapshot = ( new Snapshot( Snapshots.France ) );
		},			
];

export list PackagesWithScratch [
	Package{	salesPackage=[ (getMockSalesPackage( @Spain, @scratch )) ]; 
				locale = (new Description({ title: "Spain", shortDescription: "Map of Spain for Renault/Dacia.", descriptionId: 0L, timestamp: 0L })); 
				packageCode = 9994;
				snapshot = ( new Snapshot( Snapshots.Spain ) ); 
		},	
	Package{	salesPackage=[ (getMockSalesPackage( @Germany, @scratch )) ]; 
				locale = (new Description({ title: "Germany", shortDescription: "Map of Germany for Renault/Dacia.", descriptionId: 0L, timestamp: 0L })); 
				packageCode = 9993; 
				snapshot = ( new Snapshot( Snapshots.Germany ) );
		},										
];

export list PackagesOSMWithScratch [
	Package{	salesPackage=[ (getMockSalesPackage( @Italy_osm, @scratch )) ]; 
				locale = (new Description({ title: "Italy", shortDescription: "Map of Italy OSM for Renault/Dacia.", descriptionId: 0L, timestamp: 0L })); 
				packageCode = 99900;
				snapshot = ( new Snapshot( Snapshots.Italy_osm ) ); 
		},	
]