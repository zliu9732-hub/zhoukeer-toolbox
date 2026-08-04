#!/usr/bin/env python3

"""Build an execute_in_tab payload that applies Steam library artwork via Decky."""

import base64
import json
import sys


def main() -> int:
    if len(sys.argv) != 6:
        print(
            "usage: build_steam_artwork_payload.py <marker> <appids_json> <asset_type> <image> <tab>",
            file=sys.stderr,
        )
        return 1

    marker, appids_raw, asset_type_raw, image_path, tab = sys.argv[1:6]
    try:
        appids = json.loads(appids_raw)
        asset_type = int(asset_type_raw)
    except (ValueError, TypeError):
        print("invalid appids_json or asset_type", file=sys.stderr)
        return 1
    if not isinstance(appids, list) or not all(isinstance(item, int) for item in appids):
        print("appids_json must be a JSON array of integers", file=sys.stderr)
        return 1
    if asset_type not in (0, 1, 2, 3, 4):
        print("asset_type must be 0..4", file=sys.stderr)
        return 1

    with open(image_path, "rb") as handle:
        image_b64 = base64.b64encode(handle.read()).decode("ascii")

    js = (
        "(async function(){"
        "const m=" + json.dumps(marker) + ";"
        "const ids=" + json.dumps(appids) + ";"
        "const b64=" + json.dumps(image_b64) + ";"
        "try{if(typeof SteamClient===\"undefined\"||!SteamClient.Apps)throw Error(\"SteamClient unavailable\");"
        "let ok=0;for(const appId of ids){"
        "if(SteamClient.Apps.ClearCustomArtworkForApp){try{await SteamClient.Apps.ClearCustomArtworkForApp(appId,"
        + str(asset_type)
        + ");}catch(e){}await new Promise(x=>setTimeout(x,300));}"
        "await SteamClient.Apps.SetCustomArtworkForApp(appId,b64,\"png\","
        + str(asset_type)
        + ");"
        "if(SteamClient.Apps.ReportLibraryAssetCacheMiss){try{SteamClient.Apps.ReportLibraryAssetCacheMiss(appId,"
        + str(asset_type)
        + ");}catch(e){}}"
        "if("
        + str(asset_type)
        + "===2){try{const ov=window.appStore&&window.appStore.GetAppOverviewByAppID?.(appId);if(ov&&window.appDetailsStore)await window.appDetailsStore.SaveCustomLogoPosition(ov,{pinnedPosition:\"BottomLeft\",nWidthPct:50,nHeightPct:50});}catch(e){}}"
        "ok++;}return m+\":ok:\"+ok;"
        "}catch(e){console.error(\"zkeer-artwork:\",e);return m+\":failed:\"+String(e&&e.message||e);}})()"
    )

    print(json.dumps({"tab": tab, "run_async": True, "code": js}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
