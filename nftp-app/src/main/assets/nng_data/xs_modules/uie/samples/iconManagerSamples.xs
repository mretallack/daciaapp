import { EXPECT, FIX_ME, Sample, GenericFragments , @registerSuite, @metadata, @windowConfig, StyleResource, Async, MockFunction, @tags, hasProperties, anyNumber, _ } from "xtest.xs"
import { iconMapper } from "resources/iconMapper.xs"
import { hasProp } from "system://core"
import { @curry, map } from "core://functional"

const winCfg = {w: 1000, h: 500, dpi: screen.root.dpi, title: "Icon manager"};

<fragment frIconsList class=fill>
    own {
        let tc = (controller.tc);
    }
    <listView  class=fill w=50% model=(tc.list) template=(tItemWithIcon) >
        <scroll/>
        <wheel/>
    </listView>
    // simulated map
    <sprite class=map>
        // items having mapIcon set to undef won't show on map
        <lister model=(tc.list) template=(tPoiOnMap) templateType() {hasProp(item, @mapIcon) && !item.mapIcon ? undef : @default } 
                param={iconSize: 40, iconSpace:80} />
    </sprite>
</fragment>

<template tItemWithIcon layout=@flex w=100%>
    own {
        let icon = (iconMapper.getIcon(item.icon, {display: @normal}).getResource());
    }
    <sprite class=bg />
    <sprite class=icon img=(icon.uri) /*phaseName*/ params=(icon.params) />
    <vbox>
        <text class=title text=(item.title)/>
        <text class=detail text=(item.detail ?? "")/>
    </vbox> 
</template>

const iconMapperForMap = iconMapper.withConfig({display: @map, bgColor: #fcbc00, w: 40});

<template tPoiOnMap top=(y) left=(x) layout=@flex orientation=@vertical w=(param.iconSpace) valign=@center>
    own {
        let icon = (iconMapperForMap.getIcon(item.mapIcon ?? item.icon).getResource()); // could use intents here
        let numPoisInRow = ( (fragment.head.parent.w - 20) / param.iconSpace); 
        let x = ( 10 + (index % numPoisInRow) * param.iconSpace );
        let y = ( 10 + (index / numPoisInRow) *  2 * param.iconSpace  + (index % 3) * int(param.iconSpace * 0.3) );
    }
    <sprite class=mapIcon img=(icon.uri) /*phaseName*/ params=(icon.params) imageW=(icon.w ?? param.iconSize) boxAlign=@center />
    <text class=label text=(item.title) boxAlign=@center />
</template>

<fragment frFlatIcons class=fill layout=@flex orientation=@vertical>
    own {
        let tc = (controller.tc);
    }
    <lister model=(tc.list) template=tButtonWithIcon/>
    
</fragment>

<button tButtonWithIcon text=(item.text)>
    own {
        let icon = (iconMapper.getIcon(item.icon, {display: @flat}).getResource());
    }
    <sprite class=icon img=(icon.uri) params=(icon.params) />
</button>

const iconProvider = System.import("system://test.iconProvider"); // lazy test module import (maybe it won't be available later...)
<sprite tMapSprite img=(iconProvider.getIconImage(iconMapperForMap, item.icon, param)) />

<fragment frMapIcons class=fill layout=@flex orientation=@vertical>
    own {
        let tc = (controller.tc);
    }
    <sprite class=bg />
    <text text="Near"/>
    <hbox>
        <lister model=(tc.list) template=tMapSprite/>
    </hbox>
    <text text="Far"/>
    <hbox>
        <lister model=(tc.list) template=tMapSprite param=({intent: @far})/>
    </hbox>
</fragment>

@registerSuite @windowConfig(winCfg)
class IconMapperSamples extends Sample with GenericFragments {
    @dispose
    #winCloseSub;
    finished = false;
    
    list = [];
    
    static demo = {
        description : "iconMapper: mapping icon id's to icon resources",
        date : (new Uiml.date(2021, 03, 10))
    };
    
    static initSuite() {
        super.initSuite();
        this.use(new StyleResource(iconMngrStyles));
    }
    
    constructor() {
        super();
        // this subscription will set the state of the samples to finished
        this.#winCloseSub = screen.onWindowClosed.subscribe((hook, win) => {
           if (win == this.win) {
               this.finished = true;
           } 
        }, 1/*prio*/);
        
        this.ctrl.tc = weak(this);
    }
    
    finish() {
        console.log("Close the window to finish the sample!");
        Async.condition(_ => this.finished );    
    }
    
    async sample_iconsInListAndOnMap() {
        this.list = [
          { icon:"poi.restaurant", title:"Restaurant", detail:"All restaurants"},
          { icon:"poi.restaurant.chinese", title:"Chinese cusine"},
          { icon:"poi.restaurant.hu", title:"Hungarian"},
          { icon:"poi.shop", title:"Shopping", detail: "Shopping category"},
          { icon:"poi.shop.mall", title:"Malls", detail: "subcategory"},
          { icon:"poi.shop.mall.spar", title:"Spar", detail: "shop"},
          { icon:"poi.leisure.cafe", title:"Frei caffe", detail: "nice place"},
          { icon:"favorite.home", title:"Home", detail: "I live here", isFavorite:true},
          { icon:"user.heart", title:"Auchan", detail: "I shop here", isFavorite:true},
        ];
        
        this.ctrl.state = state {
            use = frIconsList;
        };
        
        await this.finish();
    }
    
    async sample_iconsForResultItems() {
        const results = [
            //poiResult 1
			{	category : { 
					commonCategory : 1,
					id : "FFFFFFFFF",
					async getName() { return "Accomondation" },
				},
				name : "Kecske Hotel",
				highlight : [1,2],
				position  : {
					latitude: 42.012321,
					longitude: 12.232323
				},
				distance : 120.0,
				resultType : 4 //nng.places.ResultType : COUNTRY,PLACE,ROAD,CROSSROAD,POI,HISTORY,FAVORITE
			},
			//poiResult 2
			{	category : { 
					commonCategory : 9,
					id : "FFFFFFFFF",
					async getName() { return "Cafe or Bar" },
				},
				name : "Baboon Kocsma",
				highlight : [3,5],
				position  : {
					latitude: 42.012321,
					longitude: 12.232323
				},
				distance : 120.0,
				resultType : 4 //nng.places.ResultType : COUNTRY,PLACE,ROAD,CROSSROAD,POI,HISTORY,FAVORITE
			},
            //history result
			{	
				name : "Monkey island",
				highlight : [3,5],
				position  : {
					latitude: 42.012321,
					longitude: 12.232323
				},
				distance : 130.0,
				resultType : 5 //nng.places.ResultType : COUNTRY,PLACE,ROAD,CROSSROAD,POI,HISTORY,FAVORITE
			},
			//favorite 1
			{
				category : { 
					commonCategory : 9,
					id:"places://favorite/STANDARD",
					async getName() { return "Standard" },
				},
				name : "Kecske telep",
				highlight : [3,5],
				position  : {
					latitude: 42.012321,
					longitude: 12.232323
				},
				distance : 120.0,
				resultType : 6 //nng.places.ResultType : COUNTRY,PLACE,ROAD,CROSSROAD,POI,HISTORY,FAVORITE
			},
			//home 1
			{
				category : { 
					commonCategory : 9,
					id:"places://favorite/HOME",
					async getName() { return "Home" },
				},
				name : "My home",
				highlight : [3,5],
				position  : {
					latitude: 42.012321,
					longitude: 12.232323
				},
				distance : 120.0,
				resultType : 6 //nng.places.ResultType : COUNTRY,PLACE,ROAD,CROSSROAD,POI,HISTORY,FAVORITE
			},
			//favorite with own icon
			{
				category : { 
					commonCategory : 9,
					id:"places://favorite/STANDARD",
					async getName() { return "Standard" },
				},
				name : "Kecske kocsma",
				highlight : [3,5],
				position  : {
					latitude: 42.012321,
					longitude: 12.232323
				},
				distance : 120.0,
				resultType : 6, //nng.places.ResultType : COUNTRY,PLACE,ROAD,CROSSROAD,POI,HISTORY,FAVORITE
				attributes : {
					icon : "user.heart"
				},
                resultType : 6, //nng.places.ResultType : COUNTRY,PLACE,ROAD,CROSSROAD,POI,HISTORY,FAVORITE
			},
            // country (has no specific icon currently)
            {
                name : "Kazakhstan",
				position  : {
					latitude: 42.012321,
					longitude: 12.232323
				},
				distance : 1300456.0,
				resultType : 0, //nng.places.ResultType : COUNTRY,PLACE,ROAD,CROSSROAD,POI,HISTORY,FAVORITE
				
            }    
        ];
        
        this.list = map(results, res => {
            return {
                title: res.name,
                detail: `${res.category.getName() ?? ResultType.getNameOf(res.resultType)}, distance: ${res.distance}`,
                icon: getIconIdForItem(@normal, res),
                mapIcon: getIconIdForItem(@map, res)
            }    
        });
        
        this.ctrl.state = state {
            use = frIconsList;
        };
        
        await this.finish();   
    }
    
    async sample_FlatIcons() {
        this.list = [
          { icon:"poi.restaurant", text:"Restaurants" },
          { icon:"poi.shop", text:"Shops"},
          { icon:"poi.leisure.cafe", text:"Caffes"},
          { icon:"favorite", text:"Favorites"},
        ];
        
        this.ctrl.state = state {
            use = frFlatIcons;
        };
        
        await this.finish();
    }
    
    async sample_iconProviderCpp() {
        this.list = [
          { icon:"poi.restaurant", text:"Restaurants" },
          { icon:"poi.shop", text:"Shops"},
          { icon:"poi.leisure.cafe", text:"Caffes"},
          { icon:"favorite", text:"Favorites"},
          { icon:"user.heart", title:"Auchan" },
        ];
        
        this.ctrl.state = state {
            use = frMapIcons;
        };
        
        await this.finish();
    }
}

// Getting icon id from result items
enum ResultType
{
	COUNTRY,   ///< Item type that is applicable to countries, states, etc.. Larger than a `PLACE`.
	PLACE,     ///< Item type that is applicable to municipalities, districts, postal codes, etc.. Larger than a `ROAD`.
	ROAD,      ///< Item type that is applicable to roads with or without house numbers and/or address points.
	CROSSROAD, ///< Crossroads item type.
	POI,       ///< Point of Interest (POI) item type.
	HISTORY,   ///< History item type
	FAVORITE,  ///< Favorite item type
};

enum PoiCommonCategory
{
	GENERAL,                  ///< Only use this category if there are no other, suitable categories.
	ACCOMMODATION,
	AIRPORT,
	ATM,
	CAR_RENTAL,
	CAR_DEALERSHIP,
	CAR_REPAIR_RECOVERY,
	CAR_SERVICES,
	BUSINESS,
	CAFE_OR_BAR,
	COMMUNITY,
	ELECTRIC_VEHICLE_STATION,
	ENTERTAINMENT,
	FINANCE,
	MARINE,
	MEDICAL,
	PHARMACY,
	PARKING,
	PETROL_STATION,
	PLACE_OF_WORSHIP,
	PUBLIC_SERVICES,
	PUBLIC_TRANSPORT,
	REST_AREA,
	RESTAURANT,
	SHOPPING,
	SPORTS,
	TRANSPORT,
	TRAVEL,
};

@curry
getIconIdForItem( display, resultItem ) {
	if ( display != @map && resultItem.resultType == ResultType.HISTORY )
        return "history";
    if ( resultItem.resultType == ResultType.FAVORITE ){
        if ( ??resultItem.attributes.icon ) {
            return resultItem.attributes.icon;
        } else {
            if ( resultItem.category.getName() == "Home" ) {
                return "favorite.home";
            } else if ( resultItem.category.getName() == "Work" ) {
                return "favorite.work";
            } else if ( resultItem.category.getName() == "Quick" ) {
                return "favorite.quick";
            }
            return "favorite";
        }
    }

    let isPoi = resultItem.resultType == ResultType.POI;
    if ( isPoi && ( hasProp( resultItem, @category ) || hasProp( resultItem, @commonCategory ) ) ) {
        let category = resultItem.category.commonCategory ?? 0;
        let categoryName = string(PoiCommonCategory.getNameOf( category )).toLowerCase();
        
        return `poi.${categoryName}`;
    }
    return display == @map ? undef : "listitem"; // fall back to listItem, or for map display undef
}

style iconMngrStyles {
    template > .bg, fragment > .bg {
        img: #eee;
        position: @absolute;
        w: 100%;
        h: 100%;
    }
    
    #tItemWithIcon {
        paddingTop: 10;
        paddingBottom: 10;
        paddingLeft: 20;
        paddingRight: 20;
    }
    
    text.title {
        fontSize: 26;
    }
    
    text.detail {
        fontSize: 20;
    }
    
    template > .icon {
        imageW: 60;
        imageH: -1;
        marginRight: 20;
        canShrink: false;
        boxAlign: @center;
    }
    
    text.label {
        fontSize: 15;
    }
    
    sprite.map {
        img: #f7d89e;
        left: 50%;
        h:100%;
        w: 50%;
    }
    
    text {
        color: #222;
    }
    
    button > .icon {
        imageW: 50;
    }
    
    #frFlatIcons {
        valign: @top;
        w: 30%;
        paddingTop: 10;
        paddingLeft: 10;
    }
    
    #frFlatIcons  button {
        marginBottom: 10;
        boxAlign: @stretch;
        align: @left;
        paddingTop: 5;
        paddingBottom: 5;
    }
    
    #frMapIcons {
        paddingTop: 10;
        paddingLeft: 10;
    }
    
    #frMapIcons  sprite {
        marginRight: 10;
    }
}

/**
 * when icon == "" this will be the root config, the generic fallback
 */
addConfig(icon, confObj) {
    iconMapper.addConfig(icon, confObj)
}

addPoiCategory(categoryName, iconName = categoryName) {
    iconMapper.addConfig(`poi.${categoryName}`, {isCategory:true, icon: `poiicon_${iconName}.svg`})
}

ico(url) { // prefix icon url with sample icon location 
    `nngfile://app/samples/icons/${url}`
}

@onLoad
configurePoiIcons() {
    const backrounds = {
      normal: "poi_listitem.svg",
      map: "poi_background.svg"  
    };
    
    addConfig("poi", {
        url: ico("poi/general.svg"),  
        display(kind, result, configChain, config) {
            const icon = configChain.get(@icon);
            if (kind == @flat) { // don't use template
                if (icon) {
                    result.url = ico(`poi/${icon}`);
                } 
                return result;
            }
            // we expect, that resolved contains the resolved base icon url and settings without any backgrounds set up
            result.url = ico("poi/template.svg");
            result.params = result.params ?? {};
            
            if (icon) {
                result.params.icon = `${icon}#normal`;
            }
            // NOTE: currently svg use elements need a reference for a nemed element, referring just the svg file isn't enough
            result.params.bg = `${backrounds[kind] ?? "poi_background.svg"}#background`;
            result.params.bgColor = config.bgColor ?? undef;
            // we will replace this with a template, where the result url will be used
            //   - what about params inside used elements? They will see the params of the embedding doc
            //   also you can change them with embedded <param> elements
            
            return result
        }
     });
    addConfig("poi.restaurant", { isCategory:true, icon: "poiicon_restaurant.svg" });
    addConfig("poi.leisure", { isCategory:true, icon: "poiicon_cafe_or_bar.svg" });
    addPoiCategory("shop", "shopping");
    addPoiCategory("shopping");
    addPoiCategory("accommodation");
    addPoiCategory("cafe_or_bar");
    
    addConfig("history", { url: ico("poi/history.svg") });
    addConfig("favorite", { url: ico("poi/favorite.svg") });
    addConfig("favorite.home", { url: ico("poi/home.svg") });
    addConfig("favorite.work", { url: ico("poi/work.svg") });
    addConfig("user.heart", { url: ico("poi/custom_fav0.svg") });
}

@onLoad
genericConfig() {
    addConfig("", {url: ico("poi/poi_listitem.svg") }); // note: this could have a generic diplay function for flat icons as well
                                                         //       but this one depends on image configuration too 
}