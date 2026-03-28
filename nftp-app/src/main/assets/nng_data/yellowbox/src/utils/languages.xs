import {map, Set} from "system://core.types"
import * as androidLocale from "android://locale"?
import {walkSync} from "core/ioUtils.xs"
import JSON from "system://web.JSON"
import {readFileSync} from "system://fs"
import * as i18nMod from "system://i18n"
import {onLangChanged} from "system://i18n"
import {yellowStorage} from "~/src/app.xs"
import * as objc from "system://objc"?
import {collator, stdCollator} from "system://string.normalize"
import re from "system://regexp"

const dateFormatRe = re`([./-]+)`;

class Languages{
	langCode <=> yellowStorage.langCode;
	dateFormat;
	serverLangCode <=> yellowStorage.serverLangCode;
	languagesMapping = new map;
	collator :=  collator(this.langCode ?? "en") ?? stdCollator(this.langCode ?? "en");

	#initSystemLang() {
		//if the sysConfig( default of yellowStorage.langCode ) is invalid.
		if (!languages.languagesMapping.has( this.langCode )){
			for (const deviceLangCode in preferredLanguages()) {
				if (this.languagesMapping.has( deviceLangCode ) ) {
					this.langCode = deviceLangCode;
					return;
				}
			}
			// no lang found from the preferred languages list	
			this.langCode = "en"
		}
	}

	convertDateFormat(data) {
		let dateFormat = Iter.map(data.dateFormat.split(dateFormatRe), i => {
			if (i == "YY") return "%yyyy";
			if (i == "MM" || i == "DD") return `%${i}`;
			return i;
		}).toArray().join("");
		data.dateFormat = dateFormat;
	}

	initLanguages() {
		const path = "nngfile://app//yellowbox/lang";
		let code = "und";
		for (const item in walkSync(path)) {
			if (item.isDirectory) {
				code = item?.name || "und";
			} else {
				if (item.name.startsWith("data.json")) {
					const content = readFileSync(item.path);
					const data = JSON.parse(content);
					this.convertDateFormat(data);
					this.languagesMapping.set(code, data);
				}
			}
		}
		this.#initSystemLang();
		this.dateFormat = this.languagesMapping[this.langCode].dateFormat;
		i18nMod.setLangFromFile(`yellowbox/lang/${this.langCode}/Dictionary.ini`);
	}

	subscribeLangChange( func ){
		return onLangChanged.subscribe( func );
	}

	changeLanguage(newLangCode, oldLangCode){
		this.langCode = newLangCode;
		this.dateFormat = this.languagesMapping[this.langCode].dateFormat;
		i18nMod.setLangFromFile(`yellowbox/lang/${newLangCode}/Dictionary.ini`);
	}
}

export Languages languages;

// Use this function to obtain the current user's ordered list of languages (as an iterator over lang strings (2 char ISO 639-1 code))
*preferredLanguages() {
	// on Mac/iOS we can use NSLocale to get the list of preferred languages
	const macLangs = objc?.class.NSLocale.preferredLanguages;
	if (macLangs) {
		for (const langCode in macLangs)
			yield langCode.substr(0, 2);
	} else if (androidLocale) { // on android we use the android://locale module
		yield androidLocale?.getLanguageCode();
	} else yield "en"; // fallback to english
}
