# keep-smb-online

在 macOS 上讓指定的 SMB 分享（例：`smb://192.168.1.10/home`）保持**常駐掛載**：開機/登入自動掛載、掉線自動重連，且**密碼不以明文存在於任何腳本或排程中**（一律透過 macOS 鑰匙圈提供）。

專案**不含任何個人識別資訊**：帳號自動帶入目前登入者，站點設定（伺服器、分享名稱等）放在未納版控的 `config.env`，可安全公開並跨多台 macOS 主機部署。

## 運作原理

- **常駐排程**：使用 `LaunchAgent`（`launchd`），登入時載入、每 60 秒檢查一次；發現未掛載就自動重新掛載。
- **走 NetAuth 掛載**：以 AppleScript `mount volume` 掛載，會自動向 macOS 鑰匙圈取用密碼。
  > 註：現代 macOS 的 `mount_smbfs` **不會**讀取鑰匙圈，因此本工具改走 NetAuth（與 Finder 相同機制）。
- **無明文密碼**：密碼由你在 Finder 連線時勾選「記住密碼到鑰匙圈」建立，腳本與排程內完全沒有密碼字串。
- **免個資、可攜**：帳號留空時自動用 `$(id -un)`；LaunchAgent plist 於安裝時依本機路徑動態產生（不進版控）。
- **憑證閘門**：鑰匙圈尚無憑證時會略過掛載（不會每分鐘跳密碼框）。
- **掛載點**：`/Volumes/<分享名稱>`（macOS 慣例位置，與 Finder 一致）。

## 檔案說明

| 檔案 | 用途 |
| --- | --- |
| `keep-smb-online.sh` | 主腳本：檢查並在需要時掛載 SMB |
| `save-credential.sh` | 用 Finder 開啟連線，讓你把密碼記住到鑰匙圈（無明文） |
| `install.sh` | 佈署並啟用排程（動態產生 LaunchAgent plist） |
| `uninstall.sh` | 停用並移除排程 |
| `config.env.example` | 設定範本；複製成 `config.env` 後調整（`config.env` 不進版控） |

## 安裝步驟

```bash
# 1) 進入專案目錄
cd keep-smb-online

# 2) 建立並調整站點設定
cp config.env.example config.env
#    編輯 config.env：SMB_SERVER、SMB_SHARE 等（SMB_USER 留空 = 目前登入者）

# 3) 建立鑰匙圈憑證（會用 Finder 開啟連線視窗）
./save-credential.sh
#    在跳出的 Finder 視窗輸入密碼，並勾選「在我的鑰匙圈中記住此密碼」後連線

# 4) 安裝並啟用常駐排程
./install.sh
```

安裝後系統會立即嘗試掛載一次，之後每 60 秒自動檢查、掉線自動重連。

## 設定項（`config.env`）

| 變數 | 說明 | 預設 |
| --- | --- | --- |
| `SMB_SERVER` | SMB 伺服器 IP 或主機名 | `192.168.1.10` |
| `SMB_SHARE` | 要掛載的分享名稱（掛在 `/Volumes/<分享名稱>`） | `home` |
| `SMB_USER` | SMB 帳號；留空 = 目前登入者 | （空） |

## 部署到其他 macOS 主機

每台主機各自獨立安裝，帳號自動偵測、密碼各機獨立存放於各自的鑰匙圈：

```bash
git clone https://github.com/<你的帳號>/keep-smb-online.git
cd keep-smb-online
cp config.env.example config.env   # 依該台環境調整
./save-credential.sh               # 在該台用 Finder 記住密碼
./install.sh
```

## 確認狀態

```bash
launchctl list | grep keep-smb-online     # 排程是否載入
mount | grep smbfs                        # 是否已掛載
tail -f ~/Library/Logs/keep-smb-online.log
```

## 移除

```bash
./uninstall.sh
# 如需一併刪除鑰匙圈憑證（自行帶入你的伺服器）：
security delete-internet-password -s "<你的伺服器>" -a "$(id -un)"
```

## 需求環境

- macOS
- 內建 `osascript`、`launchctl`、`security`、`plutil`（皆為系統內建，無需額外安裝）
