import version from "../version.json" with { type: @json }
import gitVersion from "../../gitversion.json"? with { type: @json }
import {platform} from "system://os"

export const nftpHeader = `YellowBox/${version.version}+${gitVersion?.hash ?? 'devbuild'}`;
export const userAgent = `YellowBox/${version.version}+${gitVersion?.hash ?? 'devbuild'} (os=${platform})`; 

@onLoad
export logAppVersion() {
    const nsdkVer = gitVersion ?`NSDK/#${gitVersion.nsdk.hash} (${gitVersion.nsdk.branch})` : `NSDK/devbuild`;
    console.log(`YellowBox/${version.version}+${gitVersion?.hash ?? 'devbuild'} (os=${platform},branch=${gitVersion?.branch ?? 'devbuild'}), ${nsdkVer}`);
    
}