# keep-smb-online

macOS 頂端列小工具（仿 [Caffeine](https://github.com/domzilla/Caffeine)），讓指定的 SMB 分享（例：`smb://192.168.1.10/home`）保持**常駐掛載**：點一下開啟，掉線、喚醒、換網路都會自動重連；再點一下停止並卸載。**密碼不以明文存在於任何地方**（一律透過 macOS 鑰匙圈提供）。

專案**不含任何個人識別資訊**：帳號預設為目前登入者，站點設定存在各機 App 的偏好設定，可安全公開並跨多台 macOS 主機部署。

## 使用方式

| 操作 | 行為 |
| --- | --- |
| 左鍵點擊圖示 | 開啟（立即掛載＋自動重連）／關閉（停止常駐並卸載） |
| 右鍵或 ⌥ 點擊 | 選單：狀態、立即重新掛載、在 Finder 開啟、記住密碼…、設定…、登入時啟動、查看 log、結束 |

圖示狀態：

| 圖示 | 意義 |
| --- | --- |
| 空心淡色磁碟 | 已關閉 |
| 實心磁碟 | 已掛載 |
| 帶驚嘆號 | 未設定伺服器／鑰匙圈無憑證／掛載失敗（會持續重試） |

## 安裝

```bash
git clone https://github.com/<你的帳號>/keep-smb-online.git
cd keep-smb-online
./build-app.sh --install     # 建置並安裝到 ~/Applications，啟動 App
```

首次啟動會開啟設定視窗：

1. 填入**伺服器**（IP 或主機名）、**分享名稱**；**帳號**留空 = 目前登入者。
2. 頂端列右鍵 →「**記住密碼…**」：在跳出的 Finder 視窗輸入密碼，並勾選「在我的鑰匙圈中記住此密碼」後連線。
3. 左鍵點圖示開啟常駐掛載。
4. 右鍵勾選「**登入時啟動**」，之後登入即自動恢復上次的開/關狀態。

## 運作原理

- **觸發檢查**：開啟時每 60 秒檢查一次（保底），另外在**系統喚醒**與**網路變為可用**時立即檢查；未掛載就重新掛載。
- **走 NetAuth 掛載**：以 AppleScript `mount volume` 掛載，會自動向 macOS 鑰匙圈取用密碼。
  > 註：現代 macOS 的 `mount_smbfs` **不會**讀取鑰匙圈，因此改走 NetAuth（與 Finder 相同機制）。
- **憑證閘門**：鑰匙圈尚無憑證時略過掛載（不會每分鐘跳密碼框），圖示顯示驚嘆號。
- **安全卸載**：關閉時以 `diskutil unmount` 卸載，**不強制**；若有檔案正在使用會保留掛載並提示。
- **掛載點**：`/Volumes/<分享名稱>`（macOS 慣例位置，與 Finder 一致）。
- **日誌**：`~/Library/Logs/keep-smb-online.log`，相同訊息不重複寫，超過 512KB 自動修剪。

## 檔案說明

| 檔案 | 用途 |
| --- | --- |
| `app/` | Swift 原始碼（SwiftPM 套件） |
| `build-app.sh` | 建置 `build/KeepSMBOnline.app`；`--install` 安裝並啟動，`--uninstall` 移除 |

## 移除

```bash
./build-app.sh --uninstall
```

會結束 App、移除登入項目、刪除 `~/Applications/KeepSMBOnline.app` 與偏好設定；**鑰匙圈憑證與 log 保留**。如需一併刪除憑證：

```bash
security delete-internet-password -s "<你的伺服器>" -a "$(id -un)"
```

## 從舊版（LaunchAgent）升級

2.x 版以 shell 腳本＋LaunchAgent 運作，與 App 同時存在會重複掛載。升級前請先手動移除舊排程：

```bash
launchctl bootout "gui/$(id -u)/com.keep-smb-online.agent"
rm -f ~/Library/LaunchAgents/com.keep-smb-online.agent.plist
```

鑰匙圈中的憑證可沿用，不需重新記住密碼；舊的 `config.env` 不再使用，請在 App「設定…」重新填入伺服器與分享名稱。

## 需求環境

- macOS 13 以上
- 建置需 Command Line Tools（`xcode-select --install`），不需完整 Xcode
