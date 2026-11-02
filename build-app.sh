#!/bin/bash
#
# build-app.sh — 建置頂端列 App：build/KeepSMBOnline.app
# 只需 Command Line Tools（swift），不需完整 Xcode；以 ad-hoc 簽章。
#
#   ./build-app.sh            # 只建置
#   ./build-app.sh --install    # 建置後安裝到 ~/Applications 並啟動
#   ./build-app.sh --uninstall  # 移除 App、登入項目與偏好設定（保留鑰匙圈憑證與 log）
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="KeepSMBOnline"
APP_DIR="${SCRIPT_DIR}/build/${APP_NAME}.app"
INSTALL_DIR="${HOME}/Applications"
BUNDLE_ID="com.keep-smb-online.app"

if [ "${1:-}" = "--uninstall" ]; then
    INSTALLED="${INSTALL_DIR}/${APP_NAME}.app"
    echo "==> 結束 App"
    pkill -x "${APP_NAME}" 2>/dev/null || true
    if [ -x "${INSTALLED}/Contents/MacOS/${APP_NAME}" ]; then
        echo "==> 從登入項目移除"
        # 登入項目由 SMAppService 註冊，只能由 App 本身註銷
        "${INSTALLED}/Contents/MacOS/${APP_NAME}" --unregister-login || true
    fi
    echo "==> 刪除 ${INSTALLED}"
    rm -rf "${INSTALLED}"
    echo "==> 刪除偏好設定"
    defaults delete "${BUNDLE_ID}" 2>/dev/null || true
    echo
    echo "完成！已移除 App。鑰匙圈憑證與 ~/Library/Logs/keep-smb-online.log 保留未動。"
    echo "（如需刪除憑證： security delete-internet-password -s \"<你的伺服器>\" -a \"$(id -un)\" ）"
    exit 0
fi

echo "==> 編譯（release）"
swift build -c release --package-path "${SCRIPT_DIR}/app"
BIN="$(swift build -c release --package-path "${SCRIPT_DIR}/app" --show-bin-path)/${APP_NAME}"

echo "==> 組裝 ${APP_DIR}"
rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS" "${APP_DIR}/Contents/Resources"
cp "${BIN}" "${APP_DIR}/Contents/MacOS/${APP_NAME}"
cp "${SCRIPT_DIR}/app/Resources/Info.plist" "${APP_DIR}/Contents/Info.plist"
plutil -lint "${APP_DIR}/Contents/Info.plist"

echo "==> ad-hoc 簽章"
codesign --force --sign - "${APP_DIR}"

if [ "${1:-}" = "--install" ]; then
    echo "==> 安裝到 ${INSTALL_DIR}"
    mkdir -p "${INSTALL_DIR}"
    pkill -x "${APP_NAME}" 2>/dev/null || true
    rm -rf "${INSTALL_DIR}/${APP_NAME}.app"
    cp -R "${APP_DIR}" "${INSTALL_DIR}/"
    open "${INSTALL_DIR}/${APP_NAME}.app"
    echo
    echo "完成！已啟動，請看頂端列的磁碟圖示。"
    echo "（左鍵 = 開/關常駐掛載；右鍵 = 選單，可勾選「登入時啟動」）"
else
    echo
    echo "完成：${APP_DIR}"
    echo "執行： open \"${APP_DIR}\"   或   ./build-app.sh --install"
fi
