#!/bin/bash
#
# keep-smb-online.sh
# 讓 smb://<SMB_SERVER>/<SMB_SHARE> 在 macOS 上保持常駐掛載。
# 由 LaunchAgent 定期呼叫：若尚未掛載（或掛載已失效）就重新掛載。
#
# 密碼不會出現在本檔案或排程中，一律由 macOS Keychain 提供
# （mount_smbfs -N 會自動向 Keychain 取用）。
#
# 站點設定（伺服器、帳號等）放在同目錄的 config.env，不進版控。
#

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---- 設定：優先讀環境變數，其次 config.env，最後才用預設 --------------------
if [ -f "${SCRIPT_DIR}/config.env" ]; then
    # shellcheck source=/dev/null
    source "${SCRIPT_DIR}/config.env"
fi

SMB_SERVER="${SMB_SERVER:-}"
SMB_SHARE="${SMB_SHARE:-home}"
SMB_USER="${SMB_USER:-}"
MOUNT_SUBDIR="${MOUNT_SUBDIR:-mnt/smb-home}"

# 帳號留空時自動使用目前登入者
[ -z "${SMB_USER}" ] && SMB_USER="$(id -un)"

MOUNTPOINT="${HOME}/${MOUNT_SUBDIR}"
LOG_FILE="${HOME}/Library/Logs/keep-smb-online.log"
# ----------------------------------------------------------------------------

log() {
    printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >>"${LOG_FILE}"
}

# 確保 log 目錄與掛載點存在
mkdir -p "$(dirname "${LOG_FILE}")"
mkdir -p "${MOUNTPOINT}"

if [ -z "${SMB_SERVER}" ]; then
    log "未設定 SMB_SERVER（請複製 config.env.example 為 config.env 並填入）"
    exit 1
fi

# macOS 預設沒有 timeout 指令，若不存在則用 perl 的替代方案
if command -v timeout >/dev/null 2>&1; then
    run_timeout() { timeout "$@"; }
else
    run_timeout() {
        local secs="$1"; shift
        perl -e 'alarm shift; exec @ARGV' "${secs}" "$@"
    }
fi

# 判斷是否已掛載，並確認連線仍存活（避免 stale mount）
is_mounted() {
    # mount 表中要有這個掛載點
    if ! mount | grep -q " on ${MOUNTPOINT} (smbfs"; then
        return 1
    fi
    # 用 5 秒逾時做存活檢查，掛載若卡死視為未掛載
    if ! run_timeout 5 /bin/ls "${MOUNTPOINT}" >/dev/null 2>&1; then
        return 1
    fi
    return 0
}

do_mount() {
    log "偵測到未掛載，開始掛載 //${SMB_USER}@${SMB_SERVER}/${SMB_SHARE} -> ${MOUNTPOINT}"
    # -N：不互動詢問密碼，改由 Keychain 取用
    if /sbin/mount_smbfs -N "//${SMB_USER}@${SMB_SERVER}/${SMB_SHARE}" "${MOUNTPOINT}" 2>>"${LOG_FILE}"; then
        log "掛載成功"
    else
        log "掛載失敗（請確認網路可達、Keychain 是否已存入 ${SMB_SERVER} 的憑證）"
    fi
}

if is_mounted; then
    # 已掛載且存活，不做任何事（保持安靜，避免灌爆 log）
    exit 0
else
    # 若掛載點殘留 stale mount，先卸載再重掛
    if mount | grep -q " on ${MOUNTPOINT} (smbfs"; then
        log "偵測到失效掛載，先卸載 ${MOUNTPOINT}"
        /sbin/umount -f "${MOUNTPOINT}" 2>>"${LOG_FILE}" || diskutil unmount force "${MOUNTPOINT}" 2>>"${LOG_FILE}"
    fi
    do_mount
fi
