import { EXPECT, Sample, GenericFragments , @registerSuite, @metadata, @windowConfig, @tags, @withStlyes, Async } from "xtest.xs"

const winCfg = {w: 600, h: 400, dpi: screen.root.dpi, title: "Fragment inheritance"};

<fragment frSampleBase class=fill,sampleFragment  >
    own {
        let tc = (controller.tc);
        constructor() {
            console.log("Hello base");
        }
    }
    <sprite class=bg />
    <text class=title text=(tc.title) >
    <vbox flex=1 class=content>
        <includeChildren />
    </vbox>
    <includeChildren filter=".footer"/>
</fragment>

<fragment frSampleWithFooter extends=frSampleBase>
    own {
        constructor() {
            console.log("Hello from footer");
        }
    }
    <hbox class=footer boxAlign=@stretch>
        <includeChildren filter=".footerbtn.pre"/>
        <button class=footerbtn text="Close" onRelease() { tc.finished = true; } />
        <includeChildren filter=".footerbtn"/> 
    </hbox>
</fragment>

<fragment frSampleWithActions extends=frSampleWithFooter class=actions>
    <text text="This sample contains some dummy actions in the footer" />
    <button class=footerbtn text="Dummy1">
    <button class=footerbtn text="Dummy2">
</fragment> 

<component kutya class="ugat harap"><button><includeChildren></button></component>
<component farkasKutya class="farkas" extends=kutya><div f1><includeChildren></div><div f2/></component>
<fragment:farkasKutya frRex class="rendor"><div r1></fragment>

@registerSuite @windowConfig(winCfg) @withStlyes(styles)
class FragmentInheritanceSamples extends Sample with GenericFragments {
    @dispose
    #winCloseSub;
    finished = false;
    title = ""
    
    static demo = {
        description : "Samples demonstrating fragment inheritance",
        date : (new Uiml.date(2021, 03, 10))
    };
    
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
    
    async sample_showBaseFragment() {
        this.ctrl.state = state {
            use = frSampleBase;
        };
        this.title = "Base fragment";
        
        
        await this.finish();   
    }
    
    async sample_showFragmentWithFooter() {
        this.ctrl.state = state {
            use = frSampleWithFooter;
        };
        this.title = "Fragment with footer";
        
        
        await this.finish();   
    }
    
    async sample_showDummyActions() {
        this.ctrl.state = state {
            use = frSampleWithActions;
        };
        this.title = "Dummy actions";
        
        
        await this.finish();   
    } 
    async sample_rex() {
        this.ctrl.state = state { use = frRex };
        let rex = this.win.getElementById(@frRex);
        await this.finish();
    }

}

style styles {
    .bg {
        w: 100%;
        h: 100%;
        position: @absolute;
        img: #ccffcc;
    }
    
    .sampleFragment {
        layout: @flex;
        orientation: @vertical;
        valign: @top;
    }
    
    vbox.content {
        valign: @top;
        fontSize: 22;
    }
    
    text.title {
        fontSize: 30;
    }
    
    .footerbtn {
        marginRight: 15;
    }
    
    .footer {
        fontSize: 20;
    }
}