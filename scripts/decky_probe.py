#!/usr/bin/env python3
"""Probe Decky tabs to find the Steam UI context that knows a shortcut appid."""

from __future__ import annotations

import argparse
import json
import sys

import decky_ws_call


TABS = [
    "SharedJSContext",
    "Steam Shared Context presented by Valve™",
    "Steam",
    "SP",
]


def probe_javascript(appids: list[int]) -> str:
    ids = json.dumps(appids, separators=(",", ":"))
    return (
        "(async function(){try{const ids=" + ids + ";const o=[];"
        "for(const id of ids){let v=null;try{v=window.appStore?.GetAppOverviewByAppID?.(id)||null}catch(e){}"
        "o.push({id,found:!!v,name:v?.strDisplayName||null,compat:v?.strCompatToolName||null});}"
        'return "probe:"+JSON.stringify(o)}'
        "catch(e){return \"probe-fail:\"+String(e&&e.message||e);}})()"
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--token", required=True)
    parser.add_argument("--appids", required=True)
    parser.add_argument("--base-url", default="http://127.0.0.1:1337")
    parser.add_argument("--timeout", type=float, default=15.0)
    args = parser.parse_args()
    try:
        appids = [int(item) for item in args.appids.split(",") if item]
    except ValueError:
        print("decky_probe.py: --appids must be comma-separated integers", file=sys.stderr)
        return 1
    if not appids:
        print("decky_probe.py: --appids is empty", file=sys.stderr)
        return 1
    if not args.token:
        parser.error("--token is required")

    code = probe_javascript(appids)
    found_any = False
    for tab in TABS:
        payload = {
            "tab": tab,
            "run_async": True,
            "code": code,
        }
        try:
            result = decky_ws_call.call_execute_in_tab(args.base_url, args.token, payload, args.timeout)
            if not isinstance(result, dict) or result.get("success") is not True:
                print(f"{tab}\terror\tunexpected Decky result", flush=True)
                continue
            text = result.get("result") or ""
            if not str(text).startswith("probe:"):
                print(f"{tab}\terror\tunexpected probe result", flush=True)
                continue
            entries = json.loads(str(text)[6:])
            found = [entry for entry in entries if entry.get("found")]
            if found:
                found_any = True
                first = found[0]
                print(
                    f"{tab}\ttrue\t{first.get('id')}\t{first.get('name') or ''}",
                    flush=True,
                )
            else:
                print(f"{tab}\tfalse\t-\t-", flush=True)
        except Exception as error:
            print(f"{tab}\terror\t{error}", flush=True)
    return 0 if found_any else 1


if __name__ == "__main__":
    raise SystemExit(main())
