#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TEST_ROOT"' EXIT

grep -Fq -- '--progress-meter' "$PROJECT_ROOT/utils/github_download.sh" || {
    echo "FAIL: GitHub 下载缺少实时速度显示" >&2
    exit 1
}
if grep -Fq '下载失败，切换备用源。' "$PROJECT_ROOT/utils/github_download.sh"; then
    echo "FAIL: GitHub 下载仍显示逐线路失败提示" >&2
    exit 1
fi
grep -Fq 'echo "$name 下载失败。"' "$PROJECT_ROOT/utils/github_download.sh" || {
    echo "FAIL: GitHub 下载缺少简洁失败提示" >&2
    exit 1
}

BIN_DIR="$TEST_ROOT/bin"
CALLS_FILE="$TEST_ROOT/curl.calls"
PAYLOAD="$TEST_ROOT/payload.zip"
OUTPUT="$TEST_ROOT/output.zip"
mkdir -p "$BIN_DIR"
printf 'verified package payload\n' > "$PAYLOAD"

cat > "$BIN_DIR/curl" <<'EOF'
#!/bin/bash
output=""
write_out=""
url=""
while [ "$#" -gt 0 ]; do
    case "$1" in
        --output|-o) output="$2"; shift 2 ;;
        --write-out|-w) write_out="$2"; shift 2 ;;
        --connect-timeout|--max-time|--proto|--proto-redir|--retry|--retry-delay|--speed-limit|--speed-time|--proxy|--range|--max-filesize)
            shift 2
            ;;
        --*) shift ;;
        *) url="$1"; shift ;;
    esac
done
if [ -n "$write_out" ]; then
    printf 'probe|%s\n' "$url" >> "${GITHUB_TEST_CALLS:?}"
    case "$url" in
        *fast.invalid*) printf '2097152' ;;
        *slow.invalid*) printf '262144' ;;
        *) printf '1048576' ;;
    esac
    exit 0
fi
printf 'download|%s\n' "$url" >> "${GITHUB_TEST_CALLS:?}"
if [ "${GITHUB_TEST_FAIL_DOWNLOAD:-0}" = "1" ]; then
    exit 22
fi
case "$url" in
    *api.github.com/*/releases/latest)
        cp "${GITHUB_TEST_API_JSON:?}" "$output"
        ;;
    *fast.invalid*) cp "${GITHUB_TEST_PAYLOAD:?}" "$output" ;;
    *) exit 22 ;;
esac
EOF
chmod +x "$BIN_DIR/curl"

# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/download_policy.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/utils/github_download.sh"

GITHUB_MIRRORS=""
GITHUB_RELEASE_PROXY="https://ghfast.top/"
GITHUB_MIRRORS="https://ghproxy.net/ https://gh.llkk.cc/"
restored_sources="$(_github_mirror_list 'https://github.com/example/project/releases/download/v1.0.0/example.zip')"
printf '%s\n' "$restored_sources" | grep -Fxq 'https://ghproxy.net/' || {
    echo "FAIL: GitHub Release 未参与已恢复镜像测速" >&2
    exit 1
}
printf '%s\n' "$restored_sources" | grep -Fxq 'https://gh.llkk.cc/' || {
    echo "FAIL: GitHub Release 缺少恢复的 gh.llkk.cc 候选源" >&2
    exit 1
}
GITHUB_MIRRORS=""
release_proxy_sources="$(_github_mirror_list 'https://github.com/example/project/releases/download/v1.0.0/example.zip')"
printf '%s\n' "$release_proxy_sources" | grep -Fxq 'https://ghfast.top/' || {
    echo "FAIL: GitHub Release 未读取可配置的代理前缀" >&2
    exit 1
}
GITHUB_RELEASE_PROXY="https://unknown-mirror.example/"
release_proxy_sources="$(_github_mirror_list 'https://github.com/example/project/releases/download/v1.0.0/example.zip')"
if printf '%s\n' "$release_proxy_sources" | grep -Fxq 'https://unknown-mirror.example/'; then
    echo "FAIL: 未审核的 GitHub Release 代理被使用" >&2
    exit 1
fi
GITHUB_RELEASE_PROXY="https://ghfast.top/"

filtered_progress="$(printf '%b' ' 42 8148k  42 3421k    0     0  1024k      0  0:00:03  0:00:01  0:00:02 1023k\rWarning: Problem : timeout. Will retry in 1 second. 1 retry left.\n' | _github_filter_curl_progress '测试包')"
printf '%s\n' "$filtered_progress" | grep -Fq '正在下载 测试包...（1023 KB/s）' || {
    echo "FAIL: GitHub 下载未显示实时下载速度" >&2
    exit 1
}
if printf '%s\n' "$filtered_progress" | grep -Eiq 'warning:|timeout|retry'; then
    echo "FAIL: GitHub 下载仍向用户显示 curl 英文重试提示" >&2
    exit 1
fi

# 模拟测试使用虚构域名，放开白名单但保留下载器自身的 SHA256 与原子替换逻辑。
download_policy_url_allowed() { return 0; }
download_policy_github_mirror_allowed() { return 0; }
download_policy_github_repo_allowed() { return 0; }
download_policy_response_is_safe() { return 0; }
GITHUB_MIRRORS="https://slow.invalid/{url} https://fast.invalid/{url}"
GITHUB_PROBE_CONNECT_TIMEOUT=1
GITHUB_PROBE_MAX_TIME=1
GITHUB_CONNECT_TIMEOUT=1
GITHUB_MAX_TIME=5
GITHUB_RETRIES=1
GITHUB_MIN_SPEED_BYTES=1
GITHUB_MIN_SPEED_TIME=1

release_sources="$(_github_mirror_list 'https://github.com/example/project/releases/download/v1.0.0/example.zip')"
ghfast_rank="$(printf '%s\n' "$release_sources" | grep -n '^https://ghfast.top/' | head -n 1 | cut -d: -f1)"
mirror_rank="$(printf '%s\n' "$release_sources" | grep -n '^https://slow.invalid/{url}' | head -n 1 | cut -d: -f1)"
[ "$ghfast_rank" -lt "$mirror_rank" ] || {
    echo "FAIL: ghfast.top 未排在 GitHub Release 镜像最前" >&2
    exit 1
}
printf '%s\n' "$release_sources" | grep -Fxq 'https://ghfast.top/' || {
    echo "FAIL: GitHub Release 缺少 ghfast.top 测速候选源" >&2
    exit 1
}
raw_sources="$(_github_mirror_list 'https://raw.githubusercontent.com/example/project/main/archive.zip')"
if printf '%s\n' "$raw_sources" | grep -Fxq 'https://ghfast.top/'; then
    echo "FAIL: ghfast.top 不应被用于非 Release 下载" >&2
    exit 1
fi
export PATH="$BIN_DIR:/usr/bin:/bin"
export GITHUB_TEST_CALLS="$CALLS_FILE"
export GITHUB_TEST_PAYLOAD="$PAYLOAD"

url="https://raw.githubusercontent.com/example/project/main/archive.zip"
expected="$(shasum -a 256 "$PAYLOAD" | awk '{print $1}')"
download_github_file "$url" "$OUTPUT" "$expected" "测试包"
cmp "$PAYLOAD" "$OUTPUT" || { echo "FAIL: 下载结果不匹配" >&2; exit 1; }

first_download="$(grep '^download|' "$CALLS_FILE" | head -n 1)"
case "$first_download" in
    download\|https://fast.invalid/*) ;;
    *) echo "FAIL: 未优先使用测速最快的镜像" >&2; exit 1 ;;
esac
grep -Fq "probe|https://fast.invalid/$url" "$CALLS_FILE" || {
    echo "FAIL: 镜像测速没有使用实际下载文件" >&2
    exit 1
}

: > "$CALLS_FILE"
steam302_download_acceleration_is_ready() { return 0; }
download_github_file "$url" "$OUTPUT" "$expected" "302优先测试"
downloads="$(grep '^download|' "$CALLS_FILE")"
first_download="$(printf '%s\n' "$downloads" | head -n 1)"
second_download="$(printf '%s\n' "$downloads" | sed -n '2p')"
case "$first_download" in
    download\|https://fast.invalid/*) ;;
    *) echo "FAIL: 302运行时没有按实际吞吐选择最快镜像" >&2; exit 1 ;;
esac
unset -f steam302_download_acceleration_is_ready

printf 'keep existing file\n' > "$OUTPUT"
export GITHUB_TEST_FAIL_DOWNLOAD=1
if download_github_file "$url" "$OUTPUT" "$expected" "失败测试包" >/dev/null 2>&1; then
    echo "FAIL: 所有下载源失败时仍返回成功" >&2
    exit 1
fi
grep -Fxq 'keep existing file' "$OUTPUT" || {
    echo "FAIL: 下载失败破坏了现有文件" >&2
    exit 1
}
find "$TEST_ROOT" -maxdepth 1 -name 'output.zip.part.*' | grep -q . && {
    echo "FAIL: 下载失败后遗留临时文件" >&2
    exit 1
}

cat > "$TEST_ROOT/latest.json" <<'EOF'
{
  "tag_name": "GE-Proton11-3",
  "assets": [
    {
      "name": "GE-Proton11-3-aarch64.tar.gz",
      "digest": "sha256:143a5e8593bd07600674da65cfaa0a64a50beeba116c14b2df21585a94877c37",
      "browser_download_url": "https://github.com/GloriousEggroll/proton-ge-custom/releases/download/GE-Proton11-3/GE-Proton11-3-aarch64.tar.gz"
    },
    {
      "name": "GE-Proton11-3.tar.gz",
      "digest": "sha256:861c2edc8d40d051fb1e7a692deb953be52bd339c46d90f2b7dde50ddad91266",
      "browser_download_url": "https://github.com/GloriousEggroll/proton-ge-custom/releases/download/GE-Proton11-3/GE-Proton11-3.tar.gz"
    }
  ]
}
EOF

export GITHUB_TEST_API_JSON="$TEST_ROOT/latest.json"
: > "$CALLS_FILE"
curl() {
    local output=""
    local url=""
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --output) output="$2"; shift 2 ;;
            --*) shift ;;
            *) url="$1"; shift ;;
        esac
    done
    printf 'download|%s\n' "$url" >> "$CALLS_FILE"
    cp "$GITHUB_TEST_API_JSON" "$output"
}
resolve_latest_github_release "GloriousEggroll/proton-ge-custom" \
    '^GE-Proton[0-9]+-[0-9]+[.]tar[.]gz$' "GE-Proton" >/dev/null
unset -f curl
[ "$_LATEST_RELEASE_TAG" = "GE-Proton11-3" ] || {
    echo "FAIL: 最新 Release 标签解析错误" >&2
    exit 1
}
[ "$_LATEST_RELEASE_ASSET" = "GE-Proton11-3.tar.gz" ] || {
    echo "FAIL: 最新 Release 资产解析错误" >&2
    exit 1
}
[ "$_LATEST_RELEASE_SHA256" = "861c2edc8d40d051fb1e7a692deb953be52bd339c46d90f2b7dde50ddad91266" ] || {
    echo "FAIL: 最新 Release SHA256 解析错误" >&2
    exit 1
}
grep -Fq "download|https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases/latest" "$CALLS_FILE" || {
    echo "FAIL: 未请求 GitHub API 最新 Release" >&2
    exit 1
}

echo "PASS: GitHub 镜像并行排序、校验和原子回退测试通过"
