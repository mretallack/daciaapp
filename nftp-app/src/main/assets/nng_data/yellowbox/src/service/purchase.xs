import {purchase as purchaseApi, purchasePoll, bindDevice } from "app://yellowbox.updateApi"
import { packageList } from "../service/packages.xs"
import {currentUser, goToSignIn} from "~/src/profile/user.ui"
import {headUnit} from "~/src/toolbox/connections.xs"
import {Map} from "system://core.types"
import * as os from "system://os"
import * as remoting from "system://remoting"
import { encodeComponent, parse } from "system://web.URI"
import * as appDelegate from "system://ios.appDelegate"?
import {yellowBoxAppDelegate} from "./ios/appDelegate.xs"
import {labSettings} from "~/src/lab.ui"?
import CancellationTokenSource from "core/CancellationTokenSource.xs"
import {openUrl} from "~/src/utils/util.xs"
import {urlHandler} from "~/src/start.xs"
import {initMarketingCloud} from "./marketingCloud.xs"
import {yellowStorage, defaultPushServer} from "../app.xs"

export enum PaymentResolution {
    success = "success",
    failed = "failed",
    canceled = "canceled",
    pending = "pending"
}

export handleResultUrlStr(urlStr) { handleResultUrl(parse(urlStr)) }

export handleResultUrl(url) {
    console.log("[payment] Result url received: ", url.toString());
    
    const primaryInvoiceId = url.queryParams?.["invoiceId"];
    const result = url.queryParams?.["resolution"];
    purchaseHandler.resultReceived(primaryInvoiceId, result);
}

resolveable() { 
    let resFunc=undef;
    new Promise(r=>{resFunc=r}), resFunc
}

class PurchaseHandler {
    #ongoing = new Map;
    currentPurchase;
    isPurchaseWfSupported := labSettings?.isPurchaseWfSupported ?? true;

    #openWorldpay(primaryInvoiceId, url) {
        openUrl(url, { message: "to complete the purchase"});
        console.log("[payment] open the link to complete the purchase: ", url);

    }

    async purchase(salesPackages, currency, voucherCodes, ctoken) {
        const device = headUnit.device ?? headUnit.lastConnectedDevice;
        // TODO: try to bind device to user, it may not binded.
        // TODO: bindDevice error is not handled properly at the moment, but the error does not mean that the purchase must be interrupted
        // Note: The server API doesn't support query of the binded devices
        let res = await bindDevice(device, currentUser.token, ctoken);
        if (ctoken.canceled) return undef;
        const ret = await purchaseApi(device, currentUser.token, salesPackages, currency, voucherCodes, ctoken);
        if (ctoken.canceled) return undef;
        if (ret.success) {
            const primaryInvoiceId = ret.data.primaryInvoiceId;
            console.log( "[payment] Opening WordPay. url: ", ret.data.url, " , id: ", primaryInvoiceId );
            this.#openWorldpay(primaryInvoiceId, ret.data.url);
            const promise, resolver = resolveable();
            const subs = ctoken.subscribe( () => {
                console.log( "[payment] Payment canceled by the user. Id: ", primaryInvoiceId ); 
                this.resultReceived(primaryInvoiceId, "CANCELED"); 
            });
            this.#ongoing.set(primaryInvoiceId,
                {promise, resolver, subs, isPolling:false, onResult:undef, ctoken, ttokenSrc:undef});
            this.currentPurchase = { primaryInvoiceId };
            return { success: true,  primaryInvoiceId };
        } else {
            return ret;
        }
    }

    waitForPurchase(primaryInvoiceId, onResultRecv ) {
        const task = this.#ongoing?.[primaryInvoiceId];
        if (!task) {
            console.log( "[payment] payment failed: purchase has not started. Id: ", primaryInvoiceId );
            return Promise.resolve("FAILED");    // purchase has not started
        }
        task.onResult = onResultRecv;
        if (this.isPurchaseWfSupported) {
            task.ttokenSrc = CancellationTokenSource(task.ctoken);
            // todo on application focus we have to start polling immediatelly
            // wait for 15 sec then start polling if result didn't recieved
            async do {
                await Chrono.delay( 15s, task.ttokenSrc.token );
                task.ttokenSrc = undef;
                if (!task.ctoken.canceled)
                    this.#pollUntilSuccess( primaryInvoiceId, task );
            }
        }
        return task.promise;
    }

    resultReceived(primaryInvoiceId, result) {
        // when purchase is pending we can treat is as success (poll should finalize it sooner or later)
        // this is a rare occurence
        const success = (result == PaymentResolution.success || result == PaymentResolution.pending);
        const task = this.#ongoing.getAndRemove(primaryInvoiceId) ?? undef;
        if (this.currentPurchase?.primaryInvoiceId == primaryInvoiceId)
            this.currentPurchase = undef;
        if (task == undef) return;
        if (success) {
            console.log( "[payment] Successful payment! id: ", primaryInvoiceId );
            packageList.reset();  // need to refresh package prices in case of using voucher code
            task.onResult?.();
            this.#pollUntilSuccess(primaryInvoiceId, task )
        } else
            task.resolver(result); // fail the task
    }
    
    #finishTask(primaryInvoiceId, task, result) {
        console.log( "[payment] Payment finished with result: ", result, ". Id: ", primaryInvoiceId );
        this.#ongoing.remove(primaryInvoiceId);
        task.resolver(result);
    }

    async #pollUntilSuccess( primaryInvoiceId, task ){
        console.log( "[payment] polling server for payment result. Id: ", primaryInvoiceId );
        const ctoken = task.ctoken;
        task.ttokenSrc?.cancel();
        if (task.isPolling)
            return
        this.isPolling = true;
        let pollResult;
        let retry = 2s;
        while (!ctoken.canceled) { 
            pollResult = await this.#poll(primaryInvoiceId, ctoken);
            if (pollResult.success) {
                if ( ( pollResult.data.saleStatus.compareNoCase("unknown") ?? -1 ) == 0 )
                    retry = pollResult?.retryAfter ?? 2s;
                else
                    return this.#finishTask(primaryInvoiceId, task, pollResult.data.saleStatus);
            }
            await Chrono.delay(retry, ctoken);
        }
        this.#finishTask(primaryInvoiceId, task, "CANCELED");
    }

    async #poll(primaryInvoiceId, ctoken) {
        const device = headUnit.device ?? headUnit.lastConnectedDevice;
        const res = await purchasePoll(device, currentUser.token, primaryInvoiceId, ctoken);
        // todo handle unsuccessfull payment!
        return res.success ? res : undef;
    }

}

export PurchaseHandler purchaseHandler;

@onStart
onStart() {
    urlHandler.registerUrl("/payment-result", handleResultUrl);
    appDelegate?.setDelegate(yellowBoxAppDelegate); // set up app delgate on iOS
    const pushServerId = SysConfig.get("yellowBox", "pushServer", defaultPushServer);
    const brand = SysConfig.get("yellowbox", "brand", "dacia_ulc");
    initMarketingCloud(pushServerId, yellowStorage.pushNotiEnabled, brand);
}
