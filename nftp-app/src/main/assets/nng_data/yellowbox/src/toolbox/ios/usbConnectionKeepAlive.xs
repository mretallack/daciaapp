import {UIApplication} from "uie/ios/UiKit.xs"
import * as os from "system://os"
import {observeValue} from "core://observe"
import {headUnit} from "~/src/toolbox/connections.xs"
import * as objc from "system://objc"?

class UsbConnectionMonitor {
    @dispose
    #connectionSub;
    app;
    @dispose(id => id && UIApplication.sharedApplication.endBackgroundTask(id))
    bgTaskId;
    @dispose
    keepAliveTimer; 
    
    activate() {
        this.app = UIApplication.sharedApplication;
        this.keepAliveTimer = Chrono.createTimer(0, 5s, ()=> { // when run the code snippet below prevents the screen to turn off
            this.app.setIdleTimerDisabled(false);
            this.app.setIdleTimerDisabled(true);
        });
        this.#connectionSub = observeValue(()=> headUnit.connected).subscribe(this.connectionChanged(?));
    }
    
    connectionChanged(connected) {
        if (connected && !this.keepAliveTimer.isRunning) {
            this.keepAliveTimer.start();
            // try to start a background task, this won't do a thing, but will request additional background execution time for the app 
            // the expiration handler will signal that the task is ended, otherwise the OS may terminate the app
            this.bgTaskId = this.app.beginBackgroundTaskWithName("YellowBoxUsbKeepAlive", objc.makeBlock("v@?", this.endBgTask(?) ));
        } else if (!connected && this.keepAliveTimer.isRunning) {
            this.keepAliveTimer.stop();
            this.app.setIdleTimerDisabled(false); // screen can turn off after USB disconnected
            this.endBgTask();
        }
    }
    
    endBgTask() {
        if (!this.bgTaskId) return;
        this.app.endBackgroundTask(this.bgTaskId);
        this.bgTaskId = undef;
    }
}

@dispose
export UsbConnectionMonitor usbConnMonitor;

@onStart
activate() {
    if (os.platform == "ios")
        usbConnMonitor.activate();    
}