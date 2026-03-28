import { Sample, @registerSuite, @metadata, @tags, EXPECT, MockFunction } from "xtest.xs"
import { map } from "system://functional"
import { hasProp, dispose, disposeSeq } from "system://core"
import { observe } from "system://core.observe"
import { DisposeSet } from "system://core.types"
import { reverse } from "system://itertools"

hookReg(event, ...params) {
    registrator r  {started = true};
    r.hook(event, ...params);
    return r;
}
class MockResource {
    #released = false;
    disposed = MockFunction{};
    [Symbol.dispose]() {
        if (!this.#released)
            this.disposed();
        this.#released = true;
    }
}

decorator @disposeArray() { @dispose(disposeSeq) } //    @dispose(a => dispose(...a))

decorator @disposeStack() {
    @dispose(s => disposeSeq(reverse(s)))
}

class MockCloseableResource {
    closed = MockFunction{};
    #fileClosed = false;
    close() {
        if (!this.#fileClosed)
            this.closed();
    }
}


@registerSuite
class DisposeSamples extends Sample {
    sample_classWithResources() {
        odict d { alma=42};
        class ResourceHolder {
            @dispose subRouteChanged = new MockResource();
            @dispose timer = new MockResource();
            @dispose obs = observe(_ => d.alma).subscribe(v => {d.korte=d.alma});
            @dispose(f=>f.close()) file = new MockCloseableResource()
        }
        
        ResourceHolder obj;
        
        // check observer is working
        d.alma = 10;
        EXPECT.EQ(d.korte, 10);
        EXPECT.CALL(obj.subRouteChanged.disposed);
        EXPECT.CALL(obj.timer.disposed);
        EXPECT.CALL(obj.file.closed);
        
        dispose(obj);
        
        // members marked with @dispose are cleared (set to undef)
        EXPECT.EQ(obj.timer, undef);
        
        // observer is finished
        d.alma = 20;
        EXPECT.EQ(d.korte, 10); // haven't updated
    }
    
    sample_objectHierarchy() {
        let activeWorkflows = 0;
        let runningWorkFlows = 0;
        let activeDirectors = 0;
        
        class Workflow {
            #running = false;
            #director;
            name;
            constructor(name, director) {
                activeWorkflows++;
                this.name = name;
                this.#director = weak(director);
            }
            start() {
                if (!this.#running) {
                    runningWorkFlows++;
                    this.#running = true;
                    console.log("Started ", this.name)
                }
            }
            
            finish(options = {notifyDirector : true}) {
                if (this.#running) {
                    console.log("Finished ", this.name);
                    runningWorkFlows--;
                    this.#running = false;
                    if (options.notifyDirector)
                        this.#director.onWorkflowFinished(this);
                }
            }
            
            get running() { this.#running }
            
            [Symbol.dispose]() {
                this.finish({ notifyDirector:false });
                activeWorkflows--;
                console.log("Disposed ", this.name)
            }
        }
        
        class Director {
            @dispose controller = new MockResource();
            @disposeArray #children = [];
            @disposeStack #wfStack = [];
            
            @dispose( stuff => activeDirectors-- ) #stuff = {}; // NOTE: this could be inside [Symbol.dispose] if needed
            
            constructor() {
                activeDirectors++; 
            }
            
            registerDirector(director) {
                this.#children.push(director);    
            }
            
            startWorkflow(name) {
                let workflow = new Workflow(name, this);
                this.#wfStack.push(workflow);
                workflow.start();
                return workflow;
            }
            
            onWorkflowFinished(wf) {
                if (wf == this.#wfStack[-1]) {
                    dispose(wf);
                    this.#wfStack.pop();
                }
            }
        }
        
        class DirectorRoot extends Director {
            @dispose(w => w.close()) window = new MockCloseableResource();
            
        }
        
        DirectorRoot appDirector;
        Director sidePanelDir;
        Director mainDir;
        
        appDirector.registerDirector(sidePanelDir);
        appDirector.registerDirector(mainDir);
        
        EXPECT.EQ(activeDirectors, 3);
        
        sidePanelDir.startWorkflow("menu");
        const search = sidePanelDir.startWorkflow("search");
        mainDir.startWorkflow("map");
        mainDir.startWorkflow("routeOverview");
        
        EXPECT.EQ(activeWorkflows, 4);
        EXPECT.EQ(runningWorkFlows, 4);
        
        search.finish();
        
        EXPECT.EQ(activeWorkflows, 3);
        EXPECT.EQ(runningWorkFlows, 3);
        
        // Expectations regarding disposable resources held by directors and workflows
        EXPECT.CALL(appDirector.window.closed);
        EXPECT.CALL(appDirector.controller.disposed);
        EXPECT.CALL(mainDir.controller.disposed);
        EXPECT.CALL(sidePanelDir.controller.disposed);
        
        console.log("\n\nClosing app...\n");
        dispose(appDirector);
        
        EXPECT.EQ(activeDirectors, 0);
        EXPECT.EQ(activeWorkflows, 0);
        EXPECT.EQ(runningWorkFlows, 0);
    }
    
    sample_dispreg() {
        odict d { alam=42 };
        let resources = new DisposeSet;
        let obs = observe(_ => d.alam).subscribeScoped(v => {d.korte=d.alam});
        let obs2 = observe(_ => d.alam).subscribeScoped(v => {d.korte=d.alam});
        EXPECT.EQ(d.korte, 42);

        d.alam = 77;
        EXPECT.EQ(d.korte, 77);

        resources.add(obs,obs2);
        dispose(resources);

        d.alam = 88;
        EXPECT.EQ(d.korte, 77);
    }

    sample_usingBlock() {
        odict d { alam=42 };
        let obs = observe(_ => d.alam).subscribeScoped(v => {d.korte=d.alam});
        let obs2 = observe(_ => d.alam).subscribe(v => {d.korte=d.alam});
        EXPECT.EQ(d.korte, 42);

        using (const resources = DisposeSet _ [obs, obs2] ) {
            d.alam = 77;
            EXPECT.EQ(d.korte, 77);
        }
        d.alam = 88;
        EXPECT.EQ(d.korte, 77);
    }

    sample_usingNonBlock() {
        odict d { alam=42 };
        let obs = observe(_ => d.alam).subscribeScoped(v => {d.korte=d.alam});
        let obs2 = observe(_ => d.alam).subscribe(v => {d.korte=d.alam});
        EXPECT.EQ(d.korte, 42);

        {
            using const resources = DisposeSet _ [ obs, obs2];

            d.alam = 77;
            EXPECT.EQ(d.korte, 77);
        }
        d.alam = 88;
        EXPECT.EQ(d.korte, 77);
    }

    sample_usingNoVarDecl() {
        odict d { alam=42 };
        let obs = observe(_ => d.alam).subscribeScoped(v => {d.korte=d.alam});
        let obs2 = observe(_ => d.alam).subscribe(v => {d.korte=d.alam});
        EXPECT.EQ(d.korte, 42);

        let resources = new DisposeSet;
        using (resources, obs, obs2)
        {
            resources.add(obs,obs2);

            d.alam = 77;
            EXPECT.EQ(d.korte, 77);
        }
        d.alam = 88;
        EXPECT.EQ(d.korte, 77);
    }

    sample_DispRegClass() {
        odict d { alam=42 };
        class K {
            @dispose #d = DisposeSet {};
            @dispose(a => dispose(...a)) subs = [];
            funka() {
                let obs = observe(_ => d.alam).subscribeScoped(v => {d.korte=d.alam});
                let obs3 = observeScoped(_ => d.alam).subscribe(v => {d.korte=d.alam});
                let obs2 = observe(_ => d.alam).subscribe(v => {d.korte=d.alam});
                this.#d.add(obs2);
                this.subs.push(obs);
            }
        }
    }
    async sample_using() {
        event evt { passEventArg = false};
        async function triggerLater(delay, arg) { 
            await Chrono.delay(delay);
            evt(arg);
            return 1 
        }

		using (hookReg(evt, arg => console.log("triggered with ", arg))) {
            let r = await.all [triggerLater(2000, "alma"), triggerLater(1000, "korte") ];
            console.log("result:", r);
		}
        evt("banan"); // won't call event
        await 1;
    }
}