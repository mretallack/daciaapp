import { EXPECT, FIX_ME, Sample, GenericFragments , @registerSuite, @metadata, @windowConfig, StyleResource, Async, MockFunction, @tags, hasProperties, anyNumber, _ } from "xtest.xs"

const winCfg = {w: 600, h: 400, dpi: screen.root.dpi, title: "Disabled click handling"};

<fragment frDisabledClick class=fill,testFragment  >
    own {
        let tc = (controller.tc);
        let someEnabled = false;
    }
    <button normal marginBottom=10 paddingLeft=0 paddingRight=0 text="Normal button" tooltip="Normal action"  
            onClick() {tc.buttonClick(@normal)} onRelease() { tc.buttonRelease(@normal); } />
    <button disabled enable=false marginBottom=10  paddingLeft=10 paddingRight=10 text="Disabled button" 
                  onClick() { tc.buttonClick(@disabled) }  onRelease() { tc.buttonRelease(@disabled); } />
    
    <button toggle marginBottom=10 text="Toggle enabled for `Some`" onRelease() { invert(someEnabled) } />
    <button some marginBottom=10 text="Some" enable=(someEnabled) tooltip="Some action"
        onClick() { tc.buttonClick(@some) }  onRelease() { tc.buttonRelease(@some);}/>
</fragment>

<fragment frInheritEnabledButton class=fill,testFragment  >
    own {
        let tc = (controller.tc);
        let someEnabled = true;
    }
    <button toggle marginBottom=10 text="Toggle enabled" onRelease() { invert(someEnabled); } />
    <group enable=(someEnabled) class=fill layout=@flex orientation=@vertical>
        <text text=(someEnabled ? "Group is enabled" : "Group is disabled") color=#fff />
        <button normal marginBottom=10 paddingLeft=0 paddingRight=0 text="Enabled button">
            <sprite class=iconOpacity imageH=50 imageW=50 img="icons/service.svg" />
        </button>
        <button normal marginBottom=10 paddingLeft=0 paddingRight=0 enable=0 text="Disabled button">
            <sprite class=iconOpacity imageH=50 imageW=50 img="icons/service.svg" />
        </button>
        <button normal marginBottom=10 paddingLeft=0 paddingRight=0 inheritEnable=0 text="Enabled button (no inherit)">
            <sprite class=iconOpacity imageH=50 imageW=50 img="icons/service.svg" />
        </button>
        <button normal marginBottom=10 paddingLeft=0 paddingRight=0 inheritEnable=0 enable=0 text="Disabled button (no inherit)">
            <sprite class=iconOpacity imageH=50 imageW=50 img="icons/service.svg" />
        </button>
    </group>
</fragment>

<fragment frDisabledUnderWheel class=fill,testFragment >
    own {
        let tc = (controller.tc);
        <template tItem layout=@flex orientation=@vertical w=100% enable=(item.enabled ?? true) tooltip=(item.tooltip ?? `${index} (${item.title})`)
                  onClick() {tc.buttonClick(@list, index)} onRelease() { tc.buttonRelease(@list, index); } >
            <sprite class=fill, bg position=@absolute  />
            <text text=(item.title) />
        </template>
    }
    
    <listView model=(tc.list) template=tItem boxAlign=@stretch flex=1 >
        <wheel/>
        <scroll/>
    </listView>
</fragment>

style disabledStyles {
    .testFragment {
        layout:@flex;
        orientation:@vertical;
        paddingLeft:50;
        paddingTop:10;
        valign:@top;
    }
    
    #tItem:disabled > sprite.bg {
        img: #767474;
    }
    
    #tItem > sprite.bg {
        img: #398BB0;
    }
    
    #tItem > text {
        color: #eee;
        fontSize: 28;
    }
    
    #tItem {
        paddingTop: 15;
        paddingBottom:15;
        paddingLeft: 15;
        paddingRight: 15;
        
        useVisibleArea: true; // make whole item clickable
    }

    .iconOpacity:disabled {
        opacity: 0.2;
    }
}


@registerSuite @windowConfig(winCfg)
class DisabledClickSamples extends Sample with GenericFragments {
    @dispose
    #winCloseSub;
    finished = false;
    
    buttonClick = MockFunction{};
    buttonRelease = MockFunction{};
    windowClick = MockFunction{};
    list = [];
    static demo = {
        description : "Showcasing how to handle clicks on disabled elements",
        date : (new Uiml.date(2021, 02, 15))
    };
    
    static initSuite() {
        super.initSuite();
        this.use(new StyleResource(disabledStyles));
    }
    
    constructor() {
        super();
        // this subscription will set the state of the samples to finished
        this.#winCloseSub = screen.onWindowClosed.subscribe((hook, win) => {
           if (win == this.win) {
               this.finished = true;
           } 
        }, 1/*prio*/);
        
        // using the @mouseDown event listener (same as click), you can catch all clicks on the window
        // if the event target is disabled a custom message/notification may be displayed
        this.win.addEventListener(@mouseDown, () => { this.windowClick(event.target) });
        this.ctrl.tc = weak(this);
    }
    
    async sample_simpleDisabledClick() {
        this.ctrl.state = state {
            use = frDisabledClick;
        };
        
        EXPECT.CALL(this.buttonClick).with(@normal).will(()=>{ console.log("Normal button down"); });
        EXPECT.CALL(this.buttonRelease).with(@normal).will(()=>{ console.log("Normal button clicked"); });
        EXPECT.CALL(this.buttonClick).with(@disabled).times(0);
        EXPECT.CALL(this.buttonClick).with(@some).times(anyNumber); 
        EXPECT.CALL(this.buttonRelease).with(@disabled).times(0);
        EXPECT.CALL(this.buttonRelease).with(@some).will(()=>{ console.log("Some action"); });
        
        EXPECT.CALL(this.windowClick).will((target)=> {
            console.log("Clicked on ", target.id ?? "Unknown");
        });
        
        // todo: this could be moved to async done!
        console.log("Close the window to finish the sample!");
        await Async.condition(_ => this.finished );
    }
    
    async sample_disabledClickSimpleNotification() {
        this.ctrl.state = state {
            use = frDisabledClick;
        };
        
        EXPECT.CALL(this.buttonRelease).with(@normal).will(()=>{ console.log("Normal button clicked"); });
        EXPECT.CALL(this.buttonRelease).with(@some).will(()=>{ console.log("Some action"); });
        EXPECT.CALL(this.windowClick).will((target)=> {
            if (!target.enable) {
                // NOTE: in a real app you could display a notification, messagebox etc.
                console.log("Function is disabled, please lower your speed");
            } 
        });
        
        console.log("Close the window to finish the sample!");
        await Async.condition(_ => this.finished );
    }
    
    async sample_disabledClickTooltipNotification() {
        this.ctrl.state = state {
            use = frDisabledClick;
        };
        
        EXPECT.CALL(this.buttonRelease).with(@normal).will(()=>{ console.log("Normal button clicked"); });
        EXPECT.CALL(this.buttonRelease).with(@some).will(()=>{ console.log("Some action"); });
        EXPECT.CALL(this.windowClick).will((target)=> {
            if (!target.enable) {
                // based on the tooltip property you can display custom messages
                // NOTE: all kinds of properties and custom properties may be used
                const message = `${target.tooltip ?? 'function'} unavailable`;
                console.log(message, ". Please lower your speed");
            } 
        });
        
        console.log("Close the window to finish the sample!");
        await Async.condition(_ => this.finished );
    }

    async sample_InheritEnabledButton() {
        this.ctrl.state = state {
            use = frInheritEnabledButton;
        };
        
        console.log("Close the window to finish the sample!");
        await Async.condition(_ => this.finished );
    }
    
    async sample_disabledItemsUnderWheel() {
        this.ctrl.state = state {
            use = frDisabledUnderWheel;
        };
        
        this.list = [
          { title: "Alma" },  
          { title: "Cekla" },  
          { title: "Bella", enabled:false},  
          { title: "lorem", enabled:false },  
          { title: "ipsum", enabled:false },  
          { title: "blabla" },
          { title: "Narancs", enabled:false },
          { title: "Apple" },
          { title: "Orange", enabled:false },
          { title: "Something" },
          { title: "Stuff", enabled:false },
            
        ];
        
        EXPECT.CALL(this.windowClick).will((target)=> {
            if (!target.enable) {
                console.log("Disabled list item clicked: ", target.tooltip ?? "<no info>")
            }
        });
        
        EXPECT.CALL(this.buttonRelease).with(@list, _).will((id, index)=>{ console.log(`${index}. list item clicked`); });
        
        // todo: this could be moved to async done!
        console.log("Close the window to finish the sample!");
        await Async.condition(_ => this.finished );       
    }
}