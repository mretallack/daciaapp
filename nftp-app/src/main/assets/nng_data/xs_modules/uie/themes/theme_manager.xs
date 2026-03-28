import { changeTheme as switchTheme } from "system://ui.theme"
import { typeof, hasProp } from "system://core"
import { list } from "system://core.types"

/**
* The theme manager class is a helper utility that aids in switching between themes and helps managing their dependencies.
*/
export class ThemeManager {
    #themeList = list[];
    #currentIndex = undef;
    #themeSwitcher = undef;

    /**
    * Constructor of the ThemeManager class. A custom theme switcher can be passed that can override the 
    * built-in theme switcher inside the engine.
    * @constructor
    * @param customThemeSwitcher - An optional custom theme switcher function to replace the one inside the engine. The function receives theme names as string parameters and has no return values.
    */
    constructor(customThemeSwitcher = undef) {
        this.reset(customThemeSwitcher);
    }

    /**
    * Resets the theme manager. This will clear all themes and reset any previously set default theme.
    * @param customThemeSwitcher - An optional custom theme switcher function to replace the one inside the engine. The function receives theme names as string parameters and has no return values.
    */
    reset(customThemeSwitcher = undef){
        this.#themeList.clear();
        this.#currentIndex = undef;
        this.#themeSwitcher = customThemeSwitcher == undef ? switchTheme : customThemeSwitcher;
        this.addTheme({ name:"common", title:"Default theme", fallbackPaths: undef });

        this.changeTheme(); //Switch to default theme
    }

    /**
    * Adds a new theme to be managed by the Theme Manager.
    * The theme must be a valid theme object, with a unique name.
    * @param themeObj - The theme object to be added
    * @returns Returns true if the theme passed the validation and got inserted into the list of managed themes. Returns false otherwise.
    */
    addTheme(themeObj) {
        if (this.#validateTheme(themeObj))
        {
            if (this.#getThemeByName(themeObj.name) != undef)
                return false;

            this.#themeList.append(themeObj);
            return true;
        }

        return false;
    }

    /**
    * Removes a theme from the Theme Manager.
    * If the theme to be removed is currently active, the Theme Manager will switch to the default theme.
    * The default theme cannot be removed.
    * If an invalid name or id is given, no removal will occur.
    * @param theme - The themes numeric id, or the themes name.
    */
    removeTheme(theme)
    {
        if ( typeof( theme ) == @int && theme < this.#themeList.size && theme >= 1 ) //The default theme cannot be deleted
        {
            if (theme == this.#currentIndex)
                this.changeTheme(0); //If the current theme is getting deleted, revert to default

            this.#themeList.remove(theme);
        }
        else if ( typeof( theme ) == @wstring )
        {
            this.removeTheme(""+theme);
        }
        else if ( typeof( theme ) == @string )
        {
            this.removeTheme(this.#getThemeIndexByName(theme));
        }
    }

    /**
    * Forces an update to the themes. May be needed if the theme objects are modified (e.g.: their fallback paths) from outside, and they need to be re-applied.
    */ 
    forceThemeUpdate(){
        this.#changeTheme_internal(this.#currentIndex, true);
    }

    /**
    * Changes the current theme to the specified one.
    * If called without parameters (or undef), the Theme Manager will switch to the default theme.
    * @param theme - The themes numeric id, or the themes name.
    */
    changeTheme(theme){ this.#changeTheme_internal(theme, false); }

    /**
    * Replaces the theme switcher with a user specified function. Used only for testing.
    * @param customThemeSwitcher - A custom theme switcher function to replace the one inside the engine. The function receives theme names as string parameters and has no return values.
    */
    setThemeSwitcher(customThemeSwitcher){
        this.#themeSwitcher = customThemeSwitcher;
    }

    get currentIndex() { return this.#currentIndex; }

    get themeList() { return this.#themeList; }
    
    get defaultTheme() { return this.#themeList[0]; }

    set defaultTheme(newDefaultTheme) {
        if (this.#validateTheme(newDefaultTheme))
        {
            var needsUpdate = newDefaultTheme.name != this.defaultTheme.name;
            
            this.#themeList[0] = newDefaultTheme;

            if (needsUpdate)
                this.forceThemeUpdate();
        }
      }

    get current() { return this.#themeList[this.#currentIndex]; }

    #getThemeByName(name){
        var index = this.#getThemeIndexByName(name);
        if (index == undef)
            return undef;

        return this.#themeList[index];
    }
    
    #getThemeIndexByName(name){
        for(var idx = 0; idx < this.#themeList.size; ++idx){
            if (this.#themeList[idx].name == name)
                return idx;
        }
        return undef;
    }

    static #contains(list, value){
        for(var t in list){
            if ( t == value )
                return true;
        }
        return false;
    }

    #collectPathListFromTheme(targetList, theme, skipFallbackPaths = false){
        if ( ThemeManager.#contains(targetList, theme.name) )
            return;
        
        targetList.append(theme.name);

        if (hasProp(theme, @fallbackPaths) && theme.fallbackPaths != undef && !skipFallbackPaths) {
            for(var themeName in theme.fallbackPaths ){
                var fallbackTheme = this.#getThemeByName(themeName);
                if (fallbackTheme != undef)
                    this.#collectPathListFromTheme(targetList, fallbackTheme);
            }
        }
    }
    
    #validateTheme(themeObj){ return typeof( themeObj ) == @object && hasProp(themeObj, @name) && typeof( themeObj.name ) == @string;}

    #changeTheme_internal(theme, force){
        var targetThemeIndex = undef;

        if (theme == undef)
        {
            targetThemeIndex = 0;
        }
        else if ( typeof( theme ) == @int && theme < this.#themeList.size && theme >= 0 )
        {
            targetThemeIndex = theme;
        }
        else if ( typeof( theme ) == @string )
        {
            targetThemeIndex = this.#getThemeIndexByName(theme);
        }

        if(targetThemeIndex != undef && (this.#currentIndex == undef || targetThemeIndex != this.#currentIndex || force)) 
        {
            this.#currentIndex = targetThemeIndex;

            var themeList = list.from([]);

            if (targetThemeIndex >= 1)
                this.#collectPathListFromTheme(themeList, this.current);

            this.#collectPathListFromTheme(themeList, this.defaultTheme, true); //The default theme's fallback paths will be ignored

            this.#themeSwitcher(...themeList);
        }
    }
}

export default ThemeManager themeManager;
