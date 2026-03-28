import { EXPECT, FIX_ME, Sample, GenericFragments , @registerSuite, @metadata, @windowConfig, StyleResource, Async, MockFunction, @tags } from "xtest.xs"

const winCfg = {w: 600, h: 400, dpi: screen.root.dpi, title: "Buttons"};

<fragment frButtons class=fill layout=@flex orientation=@vertical >
    <button text="First button" marginBottom=10 bg=#bbb>
</fragment>

<fragment frButtonsWithImage class=fill layout=@flex orientation=@vertical paddingLeft=50 paddingTop=10 valign=@top >
    <button  marginBottom=10 bg=#bbb paddingLeft=0 paddingRight=0>
        <sprite img=#cc6666 imageW=30 imageH=30 />
    </button>
    
    <button  marginBottom=10 bg=#bbb paddingLeft=10 paddingRight=10 >
        <sprite img=#cc6666 imageW=30 imageH=30 />
    </button>
    
    <button  marginBottom=10 bg=#bbb paddingLeft=10 paddingRight=10 paddingTop=10 paddingBottom=10>
        <sprite img=#cc6666 imageW=30 imageH=30 />
    </button>
</fragment>

<fragment frButtonsWithImageAbsolutePos class=fill>
    <button  bg=#bbb top=10 left=20 paddingLeft=0 paddingRight=0>
        <sprite img=#cc6666 imageW=30 imageH=30 />
    </button>
    
    <button bg=#bbb paddingLeft=10 paddingRight=10 top=10 left=70>
        <sprite img=#cc6666 imageW=30 imageH=30 />
    </button>
    
    <button bg=#bbb paddingLeft=10 paddingRight=10 paddingTop=10 paddingBottom=10 top=10 left=130>
        <sprite img=#cc6666 imageW=30 imageH=30 />
    </button>
</fragment>

@registerSuite @windowConfig(winCfg)
class ButtonSamples extends Sample with GenericFragments {
    @dispose
    #winCloseSub;
    finished = false;
    
    constructor() {
        super();
        this.#winCloseSub = screen.onWindowClosed.subscribe((hook, win) => {
           if (win == this.win) {
               this.finished = true;
           } 
        }, 1/*prio*/);
    }
    
    async sample_buttonsWithImage() {
        this.ctrl.state = state {
            use = frButtonsWithImage;
        };
        await Async.nextFrame();
        const buttons = [...this.ctrl.target.querySelectorAll("button")];
        EXPECT.EQ(buttons[0].w, 30);
        EXPECT.EQ(buttons[0].h, 30);
        EXPECT.EQ(buttons[1].w, 50);
        EXPECT.EQ(buttons[1].h, 30);
        EXPECT.EQ(buttons[2].w, 50);
        EXPECT.EQ(buttons[2].h, 50);
        // todo: this could be moved to async done!
        console.log("Close the window to finish the sample!");
        await Async.condition(_ => this.finished );
    }
    
    async sample_buttonsWithImageAbsPos() {
        this.ctrl.state = state {
            use = frButtonsWithImageAbsolutePos;
        };
        await Async.nextFrame();
        const buttons = [...this.ctrl.target.querySelectorAll("button")];
        EXPECT.EQ(buttons[0].w, 30);
        EXPECT.EQ(buttons[0].h, 30);
        EXPECT.EQ(buttons[1].w, 50);
        EXPECT.EQ(buttons[1].h, 30);
        EXPECT.EQ(buttons[2].w, 50);
        EXPECT.EQ(buttons[2].h, 50);
        
        console.log("Close the window to finish the sample!");
        await Async.condition(_ => this.finished );
    }
}