#!/bin/bash
#
# keep-smb-online.sh
# 讓 smb://<SMB_SERVER>/<SMB_SHARE> 在 macOS 上保持常駐掛載。
# 由 LaunchAgent 定期呼叫：若尚未掛載（或掛載已失效）就重新掛載。
#
# 掛載透過 AppleScript 的 `mount volume`（走 macOS NetAuth），
# 會自動向 Keychain 取用密碼；腳本與排程內完全沒有明文密碼。
# 憑證請先用 Finder「記住密碼到鑰匙圈」方式建立（見 save-credential.sh）。
#
# 站點設定（伺服器、分享名稱等）放在同目錄的 config.env，不進版控。
#

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---- 設定：讀取 config.env（站點設定的唯一來源）---------------------------
if [ -f "${SCRIPT_DIR}/config.env" ]; then
    # shellcheck source=/dev/null
    source "${SCRIPT_DIR}/config.env"
fi

SMB_SERVER="${SMB_SERVER:-}"
SMB_SHARE="${SMB_SHARE:-home}"
SMB_USER="${SMB_USER:-}"

# 帳號留空時自動使用目前登入者
[ -z "${SMB_USER}" ] && SMB_USER="$(id -un)"

# 掛載用 URL：帶入帳號，讓 NetAuth 對到正確的 Keychain 憑證
SMB_URL="smb://${SMB_USER}@${SMB_SERVER}/${SMB_SHARE}"

LOG_FILE="${HOME}/Library/Logs/keep-smb-online.log"
# ----------------------------------------------------------------------------

log() {
    printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >>"${LOG_FILE}"
}

mkdir -p "$(dirname "${LOG_FILE}")"

if [ -z "${SMB_SERVER}" ]; then
    log "未設定 SMB_SERVER（請複製 config.env.example 為 config.env 並填入）"
    exit 1
fi

# 判斷該分享是否已掛載（mount volume 會掛在 /Volumes/<share>）
is_mounted() {
    mount | grep -q "@${SMB_SERVER}/${SMB_SHARE} on "
}

# 鑰匙圈是否已有此伺服器/帳號的憑證
has_credential() {
    security find-internet-password -s "${SMB_SERVER}" -a "${SMB_USER}" >/dev/null 2>&1
}

do_mount() {
    log "偵測到未掛載，開始掛載 ${SMB_URL}"
    # mount volume 走 NetAuth：密碼由 Keychain 提供，無明文。
    # 若 Keychain 尚無憑證，會嘗試互動而失敗（不會卡住排程）。
    local result
    result="$(/usr/bin/osascript -e "mount volume \"${SMB_URL}\"" 2>&1)"
    if [ $? -eq 0 ]; then
        log "掛載成功：${result}"
    else
        log "掛載失敗：${result}（請確認網路可達，且已用 Finder 將密碼記住到鑰匙圈）"
    fi
}

if is_mounted; then
    # 已掛載，保持安靜
    exit 0
fi

# 沒憑證時不要呼叫 mount volume（會跳互動密碼框），只提示一次
if ! has_credential; then
    log "鑰匙圈尚無 ${SMB_SERVER} / ${SMB_USER} 的憑證，略過掛載。請先執行 save-credential.sh"
    exit 0
fi

do_mount
