#!/bin/bash
#
# install.sh — 安裝 LaunchAgent，讓 SMB 常駐掛載開始運作。
# plist 於此動態產生，內含本機實際路徑，不含個資、也不進版控。
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_LABEL="com.keep-smb-online.agent"
PLIST_DST="${HOME}/Library/LaunchAgents/${AGENT_LABEL}.plist"

# ---- 確認站點設定存在 -------------------------------------------------------
if [ ! -f "${SCRIPT_DIR}/config.env" ]; then
    echo "==> 尚無 config.env，從範本複製一份"
    cp "${SCRIPT_DIR}/config.env.example" "${SCRIPT_DIR}/config.env"
    echo "    已建立 ${SCRIPT_DIR}/config.env"
    echo "    請確認/調整內容（SMB_SERVER、SMB_SHARE 等）後再重新執行 ./install.sh"
    exit 0
fi
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/config.env"
SMB_SERVER="${SMB_SERVER:-}"
SMB_USER="${SMB_USER:-}"
[ -z "${SMB_USER}" ] && SMB_USER="$(id -un)"

echo "==> 賦予腳本執行權限"
chmod +x "${SCRIPT_DIR}"/*.sh

echo "==> 檢查鑰匙圈是否已存入憑證（${SMB_SERVER} / ${SMB_USER}）"
if ! security find-internet-password -s "${SMB_SERVER}" -a "${SMB_USER}" >/dev/null 2>&1; then
    echo "    ⚠️  尚未在鑰匙圈找到憑證。"
    echo "    請先執行： ${SCRIPT_DIR}/save-credential.sh"
    echo "    （並在 Finder 視窗勾選「記住密碼到鑰匙圈」，否則常駐掛載會失敗）"
fi

echo "==> 動態產生 LaunchAgent -> ${PLIST_DST}"
mkdir -p "${HOME}/Library/LaunchAgents"
cat >"${PLIST_DST}" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${AGENT_LABEL}</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>${SCRIPT_DIR}/keep-smb-online.sh</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>StartInterval</key>
    <integer>60</integer>
    <key>StandardOutPath</key>
    <string>${HOME}/Library/Logs/keep-smb-online.out.log</string>
    <key>StandardErrorPath</key>
    <string>${HOME}/Library/Logs/keep-smb-online.err.log</string>
    <key>ProcessType</key>
    <string>Background</string>
</dict>
</plist>
PLIST

echo "==> 驗證 plist 格式"
plutil -lint "${PLIST_DST}"

echo "==> 載入 LaunchAgent"
# 若已載入先卸載，確保套用最新設定
launchctl bootout "gui/$(id -u)/${AGENT_LABEL}" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "${PLIST_DST}"
launchctl enable "gui/$(id -u)/${AGENT_LABEL}"

echo "==> 立即觸發一次"
launchctl kickstart -k "gui/$(id -u)/${AGENT_LABEL}"

echo
echo "完成！排程已啟用（每 60 秒檢查、登入時自動掛載）。"
echo "掛載點： /Volumes/${SMB_SHARE:-home}"
echo "日誌：   ${HOME}/Library/Logs/keep-smb-online.log"
