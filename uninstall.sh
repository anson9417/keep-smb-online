#!/bin/bash
#
# uninstall.sh — 停用並移除 LaunchAgent（不會刪除 Keychain 憑證）。
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_LABEL="com.keep-smb-online.agent"
PLIST_DST="${HOME}/Library/LaunchAgents/${AGENT_LABEL}.plist"

if [ -f "${SCRIPT_DIR}/config.env" ]; then
    # shellcheck source=/dev/null
    source "${SCRIPT_DIR}/config.env"
fi
MOUNTPOINT="${HOME}/${MOUNT_SUBDIR:-mnt/smb-home}"

echo "==> 卸載 LaunchAgent"
launchctl bootout "gui/$(id -u)/${AGENT_LABEL}" 2>/dev/null || true

echo "==> 移除 plist"
rm -f "${PLIST_DST}"

echo "==> 卸載 SMB 掛載點（若已掛載）"
if mount | grep -q " on ${MOUNTPOINT} (smbfs"; then
    diskutil unmount "${MOUNTPOINT}" 2>/dev/null || /sbin/umount -f "${MOUNTPOINT}" || true
fi

echo
echo "完成！已停用常駐排程。"
echo "（如需一併刪除 Keychain 憑證，請自行執行："
echo "  security delete-internet-password -s \"\${SMB_SERVER:-<你的伺服器>}\" -a \"\$(id -un)\" ）"
