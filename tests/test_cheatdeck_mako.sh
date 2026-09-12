#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TMP_ROOT"' EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

export HOME="$TMP_ROOT/home"
export DECKY_PLUGIN_DIR="$HOME/homebrew/plugins"
mkdir -p "$DECKY_PLUGIN_DIR/CheatDeck/dist"
printf '{"name":"CheatDeck"}\n' > "$DECKY_PLUGIN_DIR/CheatDeck/plugin.json"
printf 'bundle\n' > "$DECKY_PLUGIN_DIR/CheatDeck/dist/index.js"

# shellcheck disable=SC1091
source "$PROJECT_ROOT/modules/plugin_store.sh"

first_output="$(install_cheatdeck_mako_launch_option)"
printf '%s\n' "$first_output" | grep -Fq 'Mako_Renkit' || fail "首次安装没有报告 Mako_Renkit"
settings_file="$HOME/homebrew/settings/CheatDeck/settings.json"
[ -f "$settings_file" ] || fail "首次安装没有创建 CheatDeck 设置"
[ "$(stat -c '%a' "$settings_file")" = "600" ] || fail "CheatDeck 设置文件权限不安全"

python3 - "$settings_file" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as source:
    options = json.load(source)["CustomOptionsV6"]

mako = [item for item in options if item.get("id") == "renkit-mako"]
assert len(mako) == 1
assert mako[0]["label"] == "Mako_Renkit"
assert mako[0]["definition"] == {
    "kind": "prefix",
    "command": "/home/deck/.local/bin/mako-run",
    "argv": [],
}
assert {item["id"] for item in options} >= {
    "preset-lossless-scaling",
    "preset-framegen-patch",
    "preset-framegen-unpatch",
    "renkit-mako",
}
PY

python3 - "$settings_file" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path, encoding="utf-8") as source:
    data = json.load(source)
data["CustomOptionsV6"].append({
    "id": "customer-option",
    "label": "用户自己的启动项",
    "definition": {"kind": "prefix", "command": "gamemoderun", "argv": []},
})
with open(path, "w", encoding="utf-8") as target:
    json.dump(data, target, ensure_ascii=False)
PY

second_output="$(install_cheatdeck_mako_launch_option)"
printf '%s\n' "$second_output" | grep -Fq '已有 Mako_Renkit 启动项' || fail "重复安装没有保持幂等"
python3 - "$settings_file" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as source:
    options = json.load(source)["CustomOptionsV6"]
assert sum(item.get("id") == "renkit-mako" for item in options) == 1
assert any(item.get("id") == "customer-option" for item in options)
PY

echo "PASS: CheatDeck Mako_Renkit 启动项创建、保留与幂等测试通过"
