
export enum Direction {
	None = 0,
	Left = 1,
	Right = 2,
	Up = 3,
	Down = 4,
    // next and prev are pseudo directions, ex. representing a focus wheel
    Prev = 5,
    Next = 6,
}

/// Helper class for using UI engine's focus system.
/// Implements a strategy for moving focus inside listViews, otherwise will forward movement
/// to the focus system.
export class FocusHandler {
    animateListScroll = true;
    animTime = 200;
    repeatTreshold = 100; // if focus events repeat inside this threshold, don't start animation
    focusedList = undef;  /// the currently focused listView
    #prevNextAxis = @horizontal;
    defaultAxis = @horizontal;

    get prevNextAxis() {
        this.#prevNextAxis;
    }

    get focusSystem() {
        this.#focusSystem;
    }

    get window() {
        this.#window;
    }

    get keyHandlers() {
        this.#keyHandlers;
    }

    set prevNextAxis(ax) {
        if (ax == @horizontal || ax == @vertical)
            this.#prevNextAxis = ax;
        else 
            this.#prevNextAxis = this.defaultAxis;
    }

    #tween = undef;
    #keyHandlers;
    #lastKeyPressTime = (Chrono.now - 1000);
    #focusSystem;
    #window;

    constructor(window) {
        this.#window = weak(window);
        this.#focusSystem = window.focus;
    }

    dispose() {
        if (this.#keyHandlers)
            this.#keyHandlers = this.#window.removeEventListener("keyDown", this.#keyHandlers); 
    }

    /// a keyMapping may be presented to map keyCodes to the direction and activation key (enter and space on home pcs)
    registerFocusKeyhandlers(keyMapping) {
        if (this.#keyHandlers) {
            console.error("registerFocusKeyhandlers was already called once");
            return;
        }
        
        this.#keyHandlers = weak(this.#window.addEventListener("keyDown", () => { 
            var handled = this.handleKeypress(event.rawkeycode, keyMapping);
             
            if (handled)
                event.stopPropagation(); 
        }));
    }

    handleKeypress(keycode, keyMapping) {
        const UP = keyMapping.up ?? 0x26;
        const DOWN = keyMapping.down ?? 0x28;
        const LEFT = keyMapping.left ?? 0x25;
        const RIGHT = keyMapping.right ?? 0x27;
        const SPACE = keyMapping.activate ?? 0x20;
        const RETURN = keyMapping.activate1 ?? 0x0D;
        const PREV = keyMapping.prev ?? 0x3a; // wheel up, ffcode is 0x20
        const NEXT = keyMapping.next ?? 0x3b; // wheel down, ffcode is 0x21

        var handled = false;
        if (keycode == UP) {
            this.moveInDirection(Direction.Up);
            handled = true;
        } else if (keycode == DOWN) {
            this.moveInDirection(Direction.Down);
            handled = true;
        } else if (keycode == LEFT) {
            this.moveInDirection(Direction.Left);
            handled = true;
        } else if (keycode == RIGHT) {
            this.moveInDirection(Direction.Right);
            handled = true;
        } else if (keycode == SPACE || keycode == RETURN) {
            ??this.#focusSystem.focusedObject.SIMULATEHIT();
            handled = true;
        } else if (keycode == PREV || keycode == NEXT) {
            this.moveInDirection(keycode == PREV ? Direction.Prev : Direction.Next);
        }
        
        return handled;
    }

    moveInDirection(dir) {
        let focusSystem = this.#focusSystem;
        let axis = this.prevNextAxis;
        if (this.focusedList) {
            const template = focusSystem.focusedObject;
            const listView = this.focusedList; 
            
            if (isDirectionOnAxis(dir, listView.orientation)) {
                axis = listView.orientation;  // if list move doesn't succeed prev/next will be still converted based on listView's axis
                dir = convertDirection(dir, listView.orientation);
                let scrollDir = (dir == Direction.Down || dir == Direction.Right) ? 1 : -1; // 1 will add to scroll, -1 will subtract
                // pp - pos property, ep - extent property
                const pp = listView.orientation == @horizontal ? @x : @y;
                const ep = listView.orientation == @horizontal ? @w : @h;
                
                // get candidate with a simple focus search, where the system doesn't move focus
                let candidate = focusSystem.traverseStrategy.findNextFocusable(template, dir);

                if (candidate || (scrollDir == 1 && listView.scroll.belowMax) 
                            || (scrollDir == -1 && listView.scroll.aboveMin)) {
                    let offset = listView.scroll.value;
                    const listCenter = listView.scroll.viewSize / 2;

                    let focusedPos;
                    if (candidate)
                        focusedPos = (candidate[pp] - offset) + candidate[ep] / 2;
                    else {
                        focusedPos = (template[pp] - offset) + template[ep] / 2 + scrollDir * template[ep];
                        console.log("no candidate yet. offset: ", offset, "template." + pp + ": ", template[pp], "scrollDir: ", scrollDir);
                    }
                    
                    // try to keep focus at the center
                    // how to keep from an equal distance in number of items from the list edges?
                    //       is this a good idea? maybe keeping distance in pixels is better
                    if ( (focusedPos > listCenter && scrollDir == 1 && listView.scroll.belowMax)
                        ||focusedPos < listCenter && scrollDir == -1 && listView.scroll.aboveMin) {
                        // check for fast repeat rate, before restarting animations
                        const keyPressDelay = Chrono.now - this.#lastKeyPressTime;
                        this.#lastKeyPressTime = Chrono.now;

                        let target = listView.scroll.value + (focusedPos - listCenter);
                        if (this.animateListScroll && !this.#tween && keyPressDelay >= this.repeatTreshold) {
                            this.#tween = Animation.tweenTo(listView.scroll, this.animTime , 
                                            {value: target, 
                                            onComplete: () => { focusSystem.focusedObject = candidate; this.#tween = undef;} } );
                        } else {
                            if (this.#tween) {
                                this.#tween.kill({ seek: "stay"}); 
                                this.#tween = undef;
                            }
                            listView.scroll.value = target;
                            if (candidate)
                                focusSystem.focusedObject = candidate;
                        }
                        return;
                    }
                }
            }
        }

        // converts prev/next on horizontal axis, if not suitable, we can comme up with something
        // more sophisticated later on
        dir = convertDirection(dir, axis);
        focusSystem.move(dir);
    }
}

/// converts prev,next directions to up/down or left/right
/// other directions are left intact
export convertDirection(dir, axis = @horizontal) {
    if (dir == Direction.Next || dir == Direction.Prev) {
        if (axis == @horizontal)
            return dir == Direction.Next ? Direction.Right : Direction.Left;
        else 
            return dir == Direction.Next ? Direction.Down : Direction.Up;
    }
    return dir;
}

isDirectionOnAxis(dir, axis) {
    if (dir == Direction.Next || dir == Direction.Prev) 
        return true;
    if (axis == @horizontal)
        return dir == Direction.Left || dir == Direction.Right;
    else 
        return dir == Direction.Up || dir == Direction.Down;
}