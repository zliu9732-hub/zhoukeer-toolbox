#!/bin/sh

[ "$UID" -eq 0 ] || exec sudo "$0" "$@"

# check if gitee.com is reachable
if ! curl -Is https://gitee.com | head -1 | grep 200 > /dev/null
then
    echo "Mirror appears to be unreachable, you may not be connected to the internet"
    exit 1
fi

echo "Installing Steam Deck Plugin Loader release..."

USER_DIR="$(getent passwd $SUDO_USER | cut -d: -f6)"
HOMEBREW_FOLDER="${USER_DIR}/homebrew"

# Create folder structure
rm -rf "${HOMEBREW_FOLDER}/services"
sudo -u $SUDO_USER mkdir -p "${HOMEBREW_FOLDER}/services"
sudo -u $SUDO_USER mkdir -p "${HOMEBREW_FOLDER}/plugins"
sudo -u $SUDO_USER touch "${USER_DIR}/.steam/steam/.cef-enable-remote-debugging"
# if installed as flatpak, put .cef-enable-remote-debugging there
[ -d "${USER_DIR}/.var/app/com.valvesoftware.Steam/data/Steam/" ] && sudo -u $SUDO_USER touch "${USER_DIR}/.var/app/com.valvesoftware.Steam/data/Steam/.cef-enable-remote-debugging"

# Mirrored release on Gitee (large binary is split into 8MB chunks)
VERSION="v3.2.6"
MIRROR_BASE="https://gitee.com/zliu9732-hub/zhoukeer-toolbox/raw/main/decky-installer-cn"
DOWNLOAD_PARTS=4
EXPECTED_SHA256="30f017a36a8baeb8c3dbae884f5d64be987a9b351b3859bf33e88615b653cf5e"

printf "Installing version %s...\n" "${VERSION}"
rm -f "${HOMEBREW_FOLDER}/services/PluginLoader"
for i in $(seq 0 $((DOWNLOAD_PARTS - 1))); do
    part=$(printf '%02d' "$i")
    curl -fL "${MIRROR_BASE}/PluginLoader.part.${part}" >> "${HOMEBREW_FOLDER}/services/PluginLoader" || { echo "PluginLoader 分块下载失败: ${part}"; exit 1; }
done
chmod +x ${HOMEBREW_FOLDER}/services/PluginLoader
actual_sha=$(sha256sum "${HOMEBREW_FOLDER}/services/PluginLoader" | cut -d' ' -f1)
if [ "$actual_sha" != "$EXPECTED_SHA256" ]; then
    echo "PluginLoader SHA256 校验失败"
    exit 1
fi

echo "Check for SELinux presence and if it is present, set the correct permission on the binary file..."
hash getenforce 2>/dev/null && getenforce | grep "Enforcing" >/dev/null && chcon -t bin_t ${HOMEBREW_FOLDER}/services/PluginLoader

echo $VERSION > ${HOMEBREW_FOLDER}/services/.loader.version

systemctl --user stop plugin_loader 2> /dev/null
systemctl --user disable plugin_loader 2> /dev/null

systemctl stop plugin_loader 2> /dev/null
systemctl disable plugin_loader 2> /dev/null

curl -L https://gitee.com/zliu9732-hub/zhoukeer-toolbox/raw/main/decky-installer-cn/plugin_loader-release.service  --output ${HOMEBREW_FOLDER}/services/plugin_loader-release.service

cat > "${HOMEBREW_FOLDER}/services/plugin_loader-backup.service" <<- EOM
[Unit]
Description=SteamDeck Plugin Loader
After=network-online.target
Wants=network-online.target
[Service]
Type=simple
User=root
Restart=always
ExecStart=${HOMEBREW_FOLDER}/services/PluginLoader
WorkingDirectory=${HOMEBREW_FOLDER}/services
KillSignal=SIGKILL
Environment=PLUGIN_PATH=${HOMEBREW_FOLDER}/plugins
Environment=LOG_LEVEL=INFO
[Install]
WantedBy=multi-user.target
EOM

if [[ -f "${HOMEBREW_FOLDER}/services/plugin_loader-release.service" ]]; then
    printf "Grabbed latest release service.\n"
    sed -i -e "s|\${HOMEBREW_FOLDER}|${HOMEBREW_FOLDER}|" "${HOMEBREW_FOLDER}/services/plugin_loader-release.service"
    cp -f "${HOMEBREW_FOLDER}/services/plugin_loader-release.service" "/etc/systemd/system/plugin_loader.service"
else
    printf "Could not curl latest release systemd service, using built-in service as a backup!\n"
    rm -f "/etc/systemd/system/plugin_loader.service"
    cp "${HOMEBREW_FOLDER}/services/plugin_loader-backup.service" "/etc/systemd/system/plugin_loader.service"
fi

mkdir -p ${HOMEBREW_FOLDER}/services/.systemd
cp ${HOMEBREW_FOLDER}/services/plugin_loader-release.service ${HOMEBREW_FOLDER}/services/.systemd/plugin_loader-release.service
cp ${HOMEBREW_FOLDER}/services/plugin_loader-backup.service ${HOMEBREW_FOLDER}/services/.systemd/plugin_loader-backup.service
rm ${HOMEBREW_FOLDER}/services/plugin_loader-backup.service ${HOMEBREW_FOLDER}/services/plugin_loader-release.service

systemctl daemon-reload
systemctl start plugin_loader
systemctl enable plugin_loader
