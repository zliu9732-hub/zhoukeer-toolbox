#!/bin/bash
set -euo pipefail
# Temporary synthetic ZIP and local transport only; no installer or network runs.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TEST_ROOT"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
mkdir -p "$TEST_ROOT/repo/core" "$TEST_ROOT/repo/utils" "$TEST_ROOT/repo/scripts"
cp "$ROOT/core/env.sh" "$ROOT/core/download_policy.sh" "$TEST_ROOT/repo/core/"
cp "$ROOT/utils/github_download.sh" "$ROOT/utils/gitee_download.sh" "$TEST_ROOT/repo/utils/"
cp "$ROOT/scripts/mirror_gitee_assets.sh" "$TEST_ROOT/repo/scripts/"
python3 - "$TEST_ROOT/DeckHomeThemes-v1.10.7.zip" <<'PY'
import sys, zipfile
with zipfile.ZipFile(sys.argv[1], 'w') as z:
    z.writestr('DeckHomeThemes/fixture.txt', 'Harmless download fixture.\n' * 30)
PY
URL=https://github.com/Kaal31/benderthemes/releases/download/v1.10.7/DeckHomeThemes-v1.10.7.zip
SHA="$(shasum -a 256 "$TEST_ROOT/DeckHomeThemes-v1.10.7.zip" | awk '{print $1}')"
generate() {
    bash "$TEST_ROOT/repo/scripts/mirror_gitee_assets.sh" --local \
        deckhomethemes DeckHomeThemes v1.10.7 DeckHomeThemes-v1.10.7.zip "$URL" "$TEST_ROOT/DeckHomeThemes-v1.10.7.zip" >/dev/null
}
generate
FIXTURE="$TEST_ROOT/repo/mirrors/deckhomethemes"
grep -q '^chunks=1$' "$FIXTURE/latest.txt" || fail 'Small package skipped chunk manifest'
grep -q '^chunk_size=1048576$' "$FIXTURE/latest.txt" || fail 'DeckHomeThemes chunk exceeds 1 MiB'
cmp "$FIXTURE/v1.10.7/part.0001" "$TEST_ROOT/DeckHomeThemes-v1.10.7.zip" || fail 'Single part differs'
[ ! -e "$FIXTURE/v1.10.7/DeckHomeThemes-v1.10.7.zip" ] || fail 'Direct package unexpectedly published'
rm -rf -- "$FIXTURE"
ZHOUKEER_GITEE_MIRROR_CHUNK_BYTES=64 generate
source "$TEST_ROOT/repo/core/env.sh"
[ "$(gitee_mirror_manifest_repo deckhomethemes)" = zhoukeer-toolbox-mirror-4 ] || fail 'DeckHomeThemes routing wrong'
[ "$(gitee_mirror_id_for_url "$URL")" = deckhomethemes ] || fail 'Pinned URL mapping missing'
if gitee_mirror_id_for_url "${URL/v1.10.7/v9.9.9}" >/dev/null; then fail 'Unreviewed version mapped'; fi
MODE=ok
CALLS="$TEST_ROOT/calls"
GITEE_MIRROR_QUIET=1
curl() {
    local output='' url='' path
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --output) output="$2"; shift 2 ;;
            https://*) url="$1"; shift ;;
            *) shift ;;
        esac
    done
    echo "$url" >> "$CALLS"
    case "$url" in
        https://gitee.com/zliu9732-hub/zhoukeer-toolbox-mirror-4/raw/main/deckhomethemes/*)
            path="${url#*/raw/main/deckhomethemes/}" ;;
        *) fail 'Unmocked transport requested' ;;
    esac
    if [ "$path" = latest.txt ] && [ "$MODE" = mismatch ]; then
        sed "s/^sha256=.*/sha256=$(printf '%064d' 0)/" "$FIXTURE/latest.txt" > "$output"
    elif [ "$path" = v1.10.7/part.0002 ] && [ "$MODE" = missing ]; then
        return 22
    elif [ "$path" = v1.10.7/part.0002 ] && [ "$MODE" = html ]; then
        printf '<html>error</html>' > "$output"
    elif [ "$path" = v1.10.7/part.0002 ] && [ "$MODE" = corrupt ]; then
        printf '%064d' 0 > "$output"
    else
        cp "$FIXTURE/$path" "$output"
    fi
}
download_github_file() {
    echo official >> "$CALLS"
    [ "$1" = "$URL" ] && [ "$3" = "$SHA" ] || fail 'Fallback changed package or hash'
    cp "$TEST_ROOT/DeckHomeThemes-v1.10.7.zip" "$2"
}
for MODE in ok mismatch missing html corrupt; do
    : > "$CALLS"
    rm -f -- "$TEST_ROOT/download.zip"
    download_with_gitee_mirror_fallback deckhomethemes "$URL" "$SHA" \
        "$TEST_ROOT/download.zip" DeckHomeThemes > "$TEST_ROOT/output" || fail "$MODE failed"
    ! grep -Eiq 'gitee|镜像|分块|https://' "$TEST_ROOT/output" || fail 'Download UI exposed source details'
    cmp "$TEST_ROOT/download.zip" "$TEST_ROOT/DeckHomeThemes-v1.10.7.zip" || fail "$MODE changed content"
    if [ "$MODE" = ok ]; then
        ! grep -q '^official$' "$CALLS" || fail 'Healthy mirror used fallback'
        grep -q 'part.0002' "$CALLS" || fail 'Multiple chunks not downloaded'
    else
        grep -q '^official$' "$CALLS" || fail "$MODE did not fall back safely"
    fi
done
for path in "$TEST_ROOT"/download.zip.part.*; do [ ! -e "$path" ] || fail 'Partial download leaked'; done
grep -Fq 'sync_plugin deckhomethemes "Kaal31/benderthemes"' "$ROOT/scripts/sync_gitee_mirrors.sh" || fail 'Scheduled mirror entry missing'
grep -Fq "deckhomethemes|主页主题（ThemeHub）|v1.10.7|DeckHomeThemes-v1.10.7.zip|$URL|63c08a3ceb9c91d07eaaba2227c1cb7bffd3616b198418fd1a7449bc70a89a74|" \
    "$ROOT/scripts/mirror_gitee_assets.sh" || fail 'Reviewed manifest entry missing'
echo 'PASS: DeckHomeThemes single/multiple chunk generation, mirror reconstruction, pinned routing, bad manifest/missing/HTML/corrupt fallback and cleanup'
