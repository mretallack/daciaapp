import { observe } from "system://core.observe"
import { setTypeCheckOption } from "ifw/ifwOptions.xs"
import { hasProp } from "system://core"
import {bootMenuList} from "./bootMenuList.ui"

export odict bootChoices {
	choices = undef;
}

style bootStyles {
	.fill {
		left:0;
		top:0;
		w:100%;
		h:100%;
	}

	sprite.bg {
		position:@absolute;
		left:0;
		top:0;
		w:100%;
		h:100%;
	}

	text {
		fontSize: 20;
		color: #cdcdcd;
	}

	.pad {
		padding: 10;
	}

	text.pad {
		paddingTop: 10;
	}

	#selectUi > * {
		boxAlign: @stretch;
	}

	fragment.content {
		top: 5%;
	}

	group.header {
		h: 5%;
		top: 0;
		w: 100%;
		left: 0;
	}

	sprite.header {
		img: #cdcdcd;
	}


	text.header {
		color: #3f3f3f;
		align: @center;
		boxAlign: @center;
	}

	group.choices {
		paddingLeft: 20;
		paddingRight: 20;
	}


	template.choice:focus sprite.bg {
		img: #cdcdcd;
	}

	template.choice:active sprite.bg {
		img: #E9E9E9;
	}

	template.choice {
		useFocus: 1;
	}


	template.choice:focus text {
		color: #151515;
	}

	vbox > * {
		boxAlign: @stretch;
	}
}

/// Choice interface, describes an item in the boot selector list
interface Choice {
	name;     ///< text of the choice
    action?; ///< optional. the action to run when the choice is selected
    ui?;      ///< if no action is selected, the ui file name proivided here is loaded
    loadPlugins = false; ///< load plugins or not. defaults to false
	typecheck?;  ///< enable/disable runtime type checker. Default is to use SysConfig.
}

interface WindowParams {
	width = 480; ///< the width of the window in pixels. default: 480
	height = 920 ///< the height of the window in pixels. default: 920
  	dpi = 240 ///< the dpi of the window. defaults to 240
	/// {<other>}  will  be passed to createWindow as options, @see uie.createWindow for details
}

interface Options {
	/// @type {WindowWidget | @create}
	/// on which window to display the selector menu. the @create special value can be used to create a new window. default: the main window (screen.root)
	window = (screen.root);
	/// @type {WindowParams}
	/// will be used only when the @create option is used for window. Contains options for creating the window: 
  	windowParams? = {}; // NOTE: {} is put here only for sake of sourceInfo
  	
  	title? = "UIE Boot Manager" /// title to display for the selector menu. default: "UIE Boot Manager"
}

/**
  * Show boot selector menu.
  * @param {Choice[]} choices items in list/sequence
  * @param {Options} options optional argument.
  */
export show(choices = [], options = {}) {
    var params = options.windowParams ?? {};
	var uie;
	if (??options.window) {
		if (options.window == @create) {
			uie = System.createUIE("", false, params);
		} else {
			uie = System.createUIE("", false, {window: options.window});
		}
	} else {
		uie = System.createUIE("", false);
	}
    var window = uie.root;
	window.styles.add(bootStyles);
    window.controller = ctrl;
	ctrl.choices = choices;
    ctrl.title = options.title ?? "UIE Boot Manager";
	ctrl.state = new Uiml.state({
		use: ( selectUi, bootHeader ),
		init() { 
			let res = [];
			for (var c in choices) {
				res.append(c.name);
			}
			bootChoices.choices = res;
		},
		done() { 
			bootChoices.choices = undef;
 		},
	});
    initFocus(uie, window);
}

export selectChoiceBy(name, choiceList) {
	if (let c = (screen.root?.controller?.choices ?? choiceList ?? bootMenuList ).find(item => item.name == name)) {

		let r = selectChoice(c);
		return hasProp(r,@then) ? r : true; // return promise if result is promise/thenable
	}
	return false;
}

selectChoice(item) {
	function defaultAction() {
		System.createUIE( item.ui, item.loadPlugins??false, { window: screen.root } );
	};

	setTypeCheckOption(item?.typecheck);
	if (??item.action) {
		item.action(defaultAction);
	} else {
		defaultAction();
	}

}

async bootRunningPhase( name, postBootActions )
{
	await 1; // continue on next loop
	var uie = System.createUIE( name, false, { window: screen.root } );
	if (postBootActions) {
		postBootActions();
	}
}

/// in the postBootActions callback you can run extra steps, after the engine is created
export boot( name, postBootActions, windowParams = undef ){
	var uie;
	if ( ??windowParams ) {
		uie = System.createUIE( "", false, windowParams );
	} else {
		uie = System.createUIE( "" );
	}
	uie.root.styles.add(bootStyles);
	uie.root.controller = ctrl;
	ctrl.state = new Uiml.state({use: ( loading, bootHeader )});

	observe( _ => app.status.phase ).subscribe((s, phase) => {
		if ( phase == ProgramPhase.Running ) {
			bootRunningPhase( name, postBootActions );
			s.cancel();
		}
	});
}

<template tChoice class=@choice layout=@flex boxAlign=@stretch orientation=@vertical visible=(item.visible ?? 1) onRelease(){ selectChoice(item); }>
	<sprite class=@bg, @fill/>
	<text class=@choice text=(item.name) align="left" boxAlign=@stretch/>
</template>

<fragment bootHeader class=@fill>
	<group class=@header, @pad layout=@flex valign=@top>
		<sprite class=@header,@bg />
        <text class=@header text=(controller.title ?? "") />
	</group>
</fragment>

<fragment selectUi class=@fill, @content, @pad layout=@flex orientation=@vertical>
	<sprite bg class=@fill img=#000 position=@absolute/>
	<text text="Choose ui to start:" />

	<group class=@choices layout=@flex orientation=@vertical flex=1 valign=@top>
		<lister  model=(controller.choices) template=(tChoice) />
	</group>
</fragment>

<fragment loading class=@fill, @content layout=@flex valign=@top>
	<sprite bg class=@fill img=#000 position=@absolute/>
	<text class=@pad text="Application is loading, please wait!" />
</fragment>

controller ctrl {
	choices = [];
}

enum Direction {
	None = 0,
	Left = 1,
	Right = 2,
	Up = 3,
	Down = 4,
}

export enum ProgramPhase {
	First,
	PreInit,
	FileSysInit,
	ConfigReady,
	IntroScreen,
	StartUp,
	PreLangReady,
	LanguageReady,
	ContentReady,
	PrepareForUI,
	LoadingUI,
	UIReady,
	Running,
	CloseStart,
	CloseSignal,
	NoMoreInput,
	PreSingleThreaded,
	SingleThreaded,
	PreCanDestroy,
	CanDestroy
}

initFocus(uie, window) {
    var focusSystem = window.focus;
	uie.REGISTERKEYCODE( "hw_up", -38 );
	uie.KEY_SAVE( "hw_up", _ => { focusSystem.move(Direction.Up); event.stopPropagation() } );

	screen.REGISTERKEYCODE( "hw_down", -40 );
	screen.KEY_SAVE( "hw_down", _ =>  { focusSystem.move(Direction.Down); event.stopPropagation() });

	uie.REGISTERKEYCODE( "hw_space", -32 );
	uie.REGISTERKEYCODE( "hw_enter", -13 );
	uie.KEY_SAVE("hw_space", _ => { event.stopPropagation(); ??focusSystem.focusedObject.SIMULATEHIT();  } );
	uie.KEY_SAVE("hw_enter", _ => { event.stopPropagation(); ??focusSystem.focusedObject.SIMULATEHIT();  } );

	focusSystem.enabled = true;
	focusSystem.traverseStrategy = "nearest";
	focusSystem.traverseStrategy.cyclic = 0;
}
