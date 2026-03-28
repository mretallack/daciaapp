import { EXPECT, FIX_ME, Sample, GenericFragments , @registerSuite, @metadata, @windowConfig, StyleResource, Async, MockFunction, @tags, hasProperties, anyNumber } from "xtest.xs"
import { @registerStyle } from "uie/styles.xs"
const winCfg = {w: 600, h: 400, dpi: screen.root.dpi, title: "Style blocks"};

// NOTE: if this weren't a sample you could register the style right away, using
// @registerStyle
style sampleStyles {
    @declare {
        
    }    
    
    sprite.bg {
        top: 0;
        left: 0;
        w: 100%;
        h: 100%;
        position: @absolute;
    }
    
    template#tStyle {
        paddingLeft: 8;
        paddingRight: 8;
        paddingTop: 5;
        paddingBottom: 5;
        fontSize: 15;
        marginBottom: 5;
        
        color: #eee;
        boxAlign: @stretch;
    }
    
    template#tStyle > text {
        marginBottom: 5;
    }
    
    template#tStyle > sprite.bg {
        opacity: 80%;
    }
    
    template#tStyle > sprite.bg.d1 {
        img: #d7be35; // weather
    }
    
    template#tStyle > sprite.bg.d2 {
        img: #8d33c1; // audio
    }
    
    template#tStyle > sprite.bg.d3 {
        img: #00adbc; // phone
    }
}

// common paddings text size etc.
style common {
    window {
        font: default;
    }
    
    .style_sample {
        fontSize: 20;
    }
    
    button {
        paddingLeft: 10;
        paddingRight: 10;
        marginRight: 10;
        marginBottom: 10;
    }
    
    button.wide {
        minW: 120;
    }
}

// ease the reading experience, larger texts
style easyReading {
    window {
        font: defaultbd;
    }
    
    .style_sample {
        fontSize: 32;
    }
    
    button {
        paddingLeft: 20;
        paddingRight: 20;
    }
    
    button.secondary {
        bg: #d7be35;
    }
    
    button.wide {
        fontSize: 40;
        maxW: -1;
    }
}

// troll styles, nobody benefits...
style troll {
    button.wide {
        minW: -1;
        maxW: 25;
    }
    
    .style_sample {
        fontSize: 15;
    }
    
    button {
        color: #c33;
        paddingLeft: 0;
        paddingRight: 0;
    }
    
    button.secondary {
        fontSize: 50;
    }
}


<fragment frStyleShowcase class=fill,style_sample w=70% layout=@flex orientation=@vertical paddingLeft=50 paddingTop=10 valign=@top >
    own {
        let tc = (controller.tc);
        
    }
    <hbox>
        <button text="A" />
        <button text="B" class=secondary /> 
    </hbox>
                  
    <button class=wide text="C" onRelease() { tc.finished = true; }/>
    
</fragment>

<fragment frStyleHierarchy w=30% right=0 layout=@flex orientation=@vertical paddingRight=10 paddingTop=10 valign=@top align=@right>
    own {
        let tc = (controller.tc);
    }
    <lister model=(tc.styles) template=tStyle param=({depth: 1}) >
    </lister>
    
</fragment>

<template tStyle layout=@flex orientation=@vertical>
    <sprite class=(@bg, `d${param.depth}`) />
    <text text=(item.name)/>
    <lister model=(item.styles ?? undef) template=tStyle param=({depth: param.depth + 1})/>
</template>

@registerSuite @windowConfig(winCfg)
class StyleBlockSamples extends Sample with GenericFragments {
    @dispose
    #winCloseSub;
    finished = false;
    styles = [];
    
    
    constructor() {
        super();
        // this subscription will set the state of the samples to finished
        this.#winCloseSub = screen.onWindowClosed.subscribe((hook, win) => {
           if (win == this.win) {
               this.finished = true;
           } 
        }, 1/*prio*/);
        this.ctrl.tc = weak(this);
        
        // add sample styles
        styles.add(sampleStyles);
    }
    
    done() {
        sampleStyles.unlink();
        common.unlink();
        easyReading.unlink();
        troll.unlink();
        super.done();
    }
    
    async showStyles() {
        this.ctrl.state = state {
            use = frStyleShowcase, frStyleHierarchy;
        };
        
        console.log("Close the window to finish the sample!");
        await Async.condition(_ => this.finished );
    }
    
    async sample_buttonsWithDefaultStyle() {
        this.styles = [{
            name: "styles",
            styles: [ 
                { name: "app"},
                {
                name: "sampleStyles",
            }]
        }];
        
        await this.showStyles();
    }
    
    async sample_buttonsWithCommonStyles() {
        sampleStyles.add(common);
        
        this.styles = [{
            name: "styles",
            styles: [ 
                { name: "app"},
                {
                name: "sampleStyles",
                styles: [
                    { name: "common" },
                ]
            }]
        }];
        
        await this.showStyles();
    }
    
    async sample_buttonsWithEasyReadingStyles() {
        sampleStyles.add(easyReading);
        
        this.styles = [{
            name: "styles",
            styles: [ 
                { name: "app"},
                {
                name: "sampleStyles",
                styles: [
                    { name: "easyReading" },
                ]
            }]
        }];
        
        await this.showStyles();
    }
    
    async sample_buttonsWithCommonAndEasyReadingStyles() {
        sampleStyles.add(common);
        sampleStyles.add(easyReading);
        
        this.styles = [{
            name: "styles",
            styles: [ 
                { name: "app"},
                {
                name: "sampleStyles",
                styles: [
                    { name: "common" },
                    { name: "easyReading" }
                ]
            }]
        }];
        
        await this.showStyles();
    }
    
    async sample_buttonsWithEasyReadingAndCommonStyles() {
        sampleStyles.add(easyReading);
        sampleStyles.add(common);
        
        this.styles = [{
            name: "styles",
            styles: [ 
                { name: "app"},
                {
                name: "sampleStyles",
                styles: [
                    { name: "easyReading" },
                    { name: "common" },
                ]
            }]
        }];
        
        await this.showStyles();
    }
    
    async sample_buttonsWithCommonTroll() {
        sampleStyles.add(common, troll);
        
        this.styles = [{
            name: "styles",
            styles: [ 
                { name: "app"},
                {
                name: "sampleStyles",
                styles: [
                    { name: "common" },
                    { name: "troll" },
                ]
            }]
        }];
        
        await this.showStyles();
    }
    
    async sample_buttonsWithTrollCommon() {
        sampleStyles.add(troll, common);
        
        this.styles = [{
            name: "styles",
            styles: [ 
                { name: "app"},
                {
                name: "sampleStyles",
                styles: [
                    { name: "troll" },
                    { name: "common" },
                ]
            }]
        }];
        
        await this.showStyles();
    }
    
    async sample_buttonsWithCommonTrollEasy() {
        sampleStyles.add(common, troll, easyReading);
        
        this.styles = [{
            name: "styles",
            styles: [ 
                { name: "app"},
                {
                name: "sampleStyles",
                styles: [
                    { name: "common" },
                    { name: "troll" },
                    { name: "easyReading" },
                ]
            }]
        }];
        
        await this.showStyles();
    }
    
    async sample_buttonsWithCommonEasyTroll() {
        sampleStyles.add(common, easyReading, troll);
        
        this.styles = [{
            name: "styles",
            styles: [ 
                { name: "app"},
                {
                name: "sampleStyles",
                styles: [
                    { name: "common" },
                    { name: "easyReading" },
                    { name: "troll" },
                ]
            }]
        }];
        
        await this.showStyles();
    }
    
    async sample_buttonsWithTrollCommonEasy() {
        sampleStyles.add(troll, common, easyReading);
        
        this.styles = [{
            name: "styles",
            styles: [ 
                { name: "app"},
                {
                name: "sampleStyles",
                styles: [
                    { name: "troll" },
                    { name: "common" },
                    { name: "easyReading" },
                ]
            }]
        }];
        
        await this.showStyles();
    }
}
