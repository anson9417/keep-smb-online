#!/bin/bash
#
# save-credential.sh
# 把 smb://<SMB_SERVER>/<SMB_SHARE> 的密碼以「無明文」方式存進 macOS 鑰匙圈。
#
# 說明：
#   現代 macOS 的 mount_smbfs 不會讀取鑰匙圈；只有走 NetAuth 的
#   Finder /「mount volume」才會。而 NetAuth 認得的鑰匙圈項目，必須由
#   Finder 連線時勾選「在我的鑰匙圈中記住此密碼」來建立。
#
#   本腳本會用 Finder 開啟連線視窗，剩下由你輸入密碼並勾選記住即可。
#   密碼只在 Finder 的系統對話框中輸入，不經過本腳本、不留任何明文。
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -f "${SCRIPT_DIR}/config.env" ]; then
    # shellcheck source=/dev/null
    source "${SCRIPT_DIR}/config.env"
fi

SMB_SERVER="${SMB_SERVER:-}"
SMB_SHARE="${SMB_SHARE:-home}"
SMB_USER="${SMB_USER:-}"
[ -z "${SMB_USER}" ] && SMB_USER="$(id -un)"

if [ -z "${SMB_SERVER}" ]; then
    echo "錯誤：未設定 SMB_SERVER。請先： cp config.env.example config.env 並填入設定。" >&2
    exit 1
fi

SMB_URL="smb://${SMB_USER}@${SMB_SERVER}/${SMB_SHARE}"

cat <<EOF
即將用 Finder 開啟連線視窗：
    ${SMB_URL}

請在跳出的視窗中：
  1. 輸入密碼
  2. 勾選「在我的鑰匙圈中記住此密碼 / Remember this password in my keychain」
  3. 按「連線 / Connect」

完成後密碼就會以 NetAuth 認得的方式存入鑰匙圈，之後排程即可自動、無密碼掛載。
（密碼只在系統對話框輸入，不會經過此腳本。）

按 Enter 開啟 Finder 連線視窗...
EOF
read -r _

open "${SMB_URL}"

echo
echo "已開啟 Finder 連線視窗。完成連線並勾選記住密碼後，即可執行 ./install.sh。"
