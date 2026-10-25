# Steamcommunity 302 V15

2026-10-25: replace 14.0.02 with the official Linux x64 WebKit 15.0.9 AppImage.
Official version manifest: https://www.dogfight360.com/Usbeam/V15/S302.ini
Official notes: https://www.dogfight360.com/blog/18682/
SHA256: `7884bbf43abe9b6202de37c133b3edfd8ff768c6c533e8d822d8aabf3a6f3fdd`.

V15 no longer implements V14's INI/run-marker/exit-marker control protocol.
The existing menu and Gitee downloader remain; the verified official AppImage
extracts into the staging directory. Its original `s302-service-installer`
installs the root-owned resources in `var-lib` mode, suitable for SteamOS's
read-only `/usr`. The GUI runs as the desktop user. The vendor installs
`s302-<uid>.service`, `/run/s302/<uid>/control.json`, and the per-user credential
under `~/.config/Steamcommunity_302/control.token`.

`steam302_control.py` uses only the authenticated Unix socket advertised by the
root-owned descriptor, API version `1.0`. When socket permissions require it,
the adapter can use the vendor-advertised, authenticated `127.0.0.1` fallback;
arbitrary IPs, names and ports outside 1..65535 are rejected. It never sends the
credential on the command line or to an external address. Requests use the vendor's revisioned
configuration API, preserve existing options/custom rules, and add the previous
Renkit Steam/GitHub defaults. Engine acceptance is followed by operation and
actual state checks. A 200/202 response alone is insufficient.

SSL handling uses the official `/v1/cert/install` operation and checks system/NSS
trust afterwards. Upstream fixed Steam Deck's automatic certificate import in
15.0.4 and intermediate certificate signing/expiry in 15.0.5. Each enable pass
rechecks the trust stores so newly created Steam NSS databases are included.
Partial/unknown trust fails visibly. No `curl -k`, disabled Git verification,
private CA key export, or global certificate bypass is used. Restart Steam after
changing trust. This addresses 302's certificate handling; it does not claim to
repair every unrelated remote server, clock, network or application SSL error.

Legacy files are kept until the new service and certificate/engine checks pass.
Download/extraction/resource/helper failures restore the previous application
directory. If the vendor service installs but later checks fail, preserve the
old directory and report its path rather than claiming a complete rollback.
Only a Renkit-owned V14 service may be stopped or disabled. Standalone old
versions must first be stopped/uninstalled through their original installation.

Validation on macOS is limited to original-image SHA256/ELF checks, static
inspection of the official installer/frontend/API JSON types, bundle resource
hash checks and offline mocked regression tests. SteamOS/Steam hardware has
not been exercised on this machine.
