import {Map} from "system://core.types"
import { i18n } from "system://i18n"

export translateCountry(isoCode) {
	return countryToTranslated[isoCode] ?? i18n`n/a`;
}

/// ordered list of countires
export getCountries() {
	return [...countryToTranslated.keys].toSorted((a,b) => string(translateCountry(a)) <=> string(translateCountry(b)));
}

export isValidCountry(isoCode) {
	countryToTranslated.has(isoCode)
}

const countryToTranslated = new Map([
	( "ALB", i18n`_ALB`),
	( "AND", i18n`_AND`),
	( "ARM", i18n`_ARM`),
	( "AUT", i18n`_AUT`),
	( "BLR", i18n`_BLR`),
	( "BEL", i18n`_BEL`),
	( "BIH", i18n`_BIH`),
	( "BGR", i18n`_BGR`),
	( "HRV", i18n`_HRV`),
	( "CYP", i18n`_CYP`),
	( "CZE", i18n`_CZE`),
	( "DNK", i18n`_DNK`),
	( "EST", i18n`_EST`),
	( "FRO", i18n`_FRO`),
	( "FIN", i18n`_FIN`),
	( "FRA", i18n`_FRA`),
	( "GEO", i18n`_GEO`),
	( "DEU", i18n`_DEU`),
	( "GIB", i18n`_GIB`),
	( "GRC", i18n`_GRC`),
	( "HUN", i18n`_HUN`),
	( "ISL", i18n`_ISL`),
	( "IRL", i18n`_IRL`),
	( "IMN", i18n`_IMN`),
	( "ITA", i18n`_ITA`),
	( "UNK", i18n`_KOS`),
	( "LVA", i18n`_LAT`),
	( "LIE", i18n`_LIE`),
	( "LTU", i18n`_LTU`),
	( "LUX", i18n`_LUX`),
	( "MKD", i18n`_MKD`),
	( "MLT", i18n`_MLT`),
	( "MDA", i18n`_MDA`),
	( "MCO", i18n`_MON`),
	( "MNE", i18n`_CRG`),
	( "NLD", i18n`_NED`),
	( "NOR", i18n`_NOR`),
	( "POL", i18n`_POL`),
	( "PRT", i18n`_POR`),
	( "ROU", i18n`_ROU`),
	( "RUS", i18n`_RUS`),
	( "SMR", i18n`_SMR`),
	( "SRB", i18n`_SER`),
	( "SVK", i18n`_SVK`),
	( "SVN", i18n`_SLO`),
	( "ESP", i18n`_ESP`),
	( "SWE", i18n`_SWE`),
	( "CHE", i18n`_CHE`),
	( "TUR", i18n`_TUR`),
	( "UKR", i18n`_UKR`),
	( "GBR", i18n`_GBR`),
	( "VAT", i18n`_VAT`),
]);
