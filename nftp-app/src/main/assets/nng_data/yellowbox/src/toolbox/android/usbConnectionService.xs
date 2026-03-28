import { observeValue} from "core://observe"
import {headUnit} from "~/src/toolbox/connections.xs"
import {platform} from "system://os"
import * as notifications from "android://notifications"?
import { i18n } from "system://i18n"
import * as androidUsbForegroundService from "android://yellow.usbConnection"?
import * as aoa from "android://aoa"?
import {tryDispose} from "system://core"

// This file host code to start a foreground service on Android while the headunit connection is active
// It will display a notification to the user about the ongoing connection, which can be canceled (closed) by the user
// When yellowbox runs on other platforms this code won't be activated

// ## Tasks:
// - also progress could be updated on this service at a later time

class UsbConnectionService {
    #running = false;
    @dispose
    #connectionSub;
    #notification;
    channelId = "nngMapUpdate"
    title = i18n`Connected`
    description = i18n`USB connection between phone and car active`
    labelDetails = i18n`Details`
    
    constructor() {
        notifications.createNotificationChannel(this.channelId, "Connection notifications", {
            description: "Provides notifications about connection to the car head unit",
            importance: notifications.Importance.Low  // make no sound
        })
    }
    
    activate() {
        this.#connectionSub = observeValue(()=> headUnit.connected).subscribe(this.connectionChanged(?));
        notifications.registerActionHandler("yellowbox.usbconnection.tap", ()=> {
            console.log("Usb foreground service noti tapped")
        });
        
        notifications.registerActionHandler("yellowbox.usbconnection.details", ()=> {
            console.log("Show USB connection details");
        });
    }
    
    connectionChanged() {
        const connected = headUnit.connected;
        if (connected && !this.#running)
            this.startForegroundService();
        else if (!connected && this.#running) {
            this.stopForegroundService()
        }
    }
    
    async startForegroundService() {
        this.#running = true;
        const notification = await this.createNotification();        
        androidUsbForegroundService.startForegroundService(notification)
    }
    
    stopForegroundService() {
        this.#running = false;
        this.#notification = undef;
        androidUsbForegroundService.stopForegroundService();
    } 
    
    async createNotification() {
        this.#notification = await notifications.createNotification(this.channelId, {
            title: this.title.toString(),
            text: this.description.toString(),
            smallIcon: "ic_navigation", // todo: use icon representing usb conn.
            ongoing: true, // required for foreground service, so it can't be dismissed by default
            tapAction: "yellowbox.usbconnection.tap",
            actions: [
                { title:this.labelDetails.toString(), action:"yellowbox.usbconnection.details", showActivity:true }
            ]
        });
        return this.#notification
    }
}

@dispose
export UsbConnectionService service;

@onStart
activate() {
    if (platform == "android")
        service.activate()
}