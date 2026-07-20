#!/bin/bash
#
# save-credential.sh
# 把 smb://<SMB_SERVER>/<SMB_SHARE> 的密碼存進 macOS Keychain。
# 由「你自己」執行，密碼在互動式提示中輸入，不會出現在任何檔案或指令歷史中。
#
# 執行後 mount_smbfs -N 就能自動向 Keychain 取用密碼，達成「無明文密碼」。
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -f "${SCRIPT_DIR}/config.env" ]; then
    # shellcheck source=/dev/null
    source "${SCRIPT_DIR}/config.env"
fi

SMB_SERVER="${SMB_SERVER:-}"
SMB_USER="${SMB_USER:-}"
[ -z "${SMB_USER}" ] && SMB_USER="$(id -un)"

if [ -z "${SMB_SERVER}" ]; then
    echo "錯誤：未設定 SMB_SERVER。請先： cp config.env.example config.env 並填入設定。" >&2
    exit 1
fi

echo "即將為 ${SMB_USER}@${SMB_SERVER} (SMB) 建立/更新 Keychain 憑證。"
echo "接下來會提示你輸入密碼（輸入時不會顯示、也不會被記錄）。"
echo

# -r "smb " 指定協定為 SMB（FourCharCode，含結尾空白）
# -T /sbin/mount_smbfs 允許掛載程式免提示存取此項目
# -U 若已存在則更新
# -w 不帶值 → 互動式提示輸入密碼（無明文）
security add-internet-password \
    -a "${SMB_USER}" \
    -s "${SMB_SERVER}" \
    -r "smb " \
    -l "${SMB_SERVER}" \
    -T /sbin/mount_smbfs \
    -U \
    -w

echo
echo "完成。已存入 Keychain（伺服器：${SMB_SERVER}，帳號：${SMB_USER}）。"
