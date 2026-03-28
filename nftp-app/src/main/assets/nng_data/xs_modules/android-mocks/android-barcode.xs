/// [module] android://barcode

import * as clipboard from "system://clipboard"
import {Async} from "xtest.xs"

export async scan() 
{
    await Async.delay(1000);
    return #{
        contents: clipboard.readTextSync()    
    }
}