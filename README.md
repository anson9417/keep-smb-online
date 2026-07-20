# keep-smb-online

在 macOS 上讓指定的 SMB 分享（例：`smb://192.168.1.10/home`）保持**常駐掛載**：開機/登入自動掛載、掉線自動重連，且**密碼不以明文存在於任何腳本或排程中**（一律透過 macOS Keychain 提供）。

專案**不含任何個人識別資訊**：帳號自動帶入目前登入者，站點設定（伺服器、分享名稱等）放在未納版控的 `config.env`，可安全公開並跨多台 macOS 主機部署。

## 運作原理

- **常駐排程**：使用 `LaunchAgent`（`launchd`），登入時載入、每 60 秒檢查一次；發現未掛載或掛載失效就自動重新掛載。
- **無明文密碼**：密碼由你自己存進 macOS Keychain；掛載時用 `mount_smbfs -N` 向 Keychain 取用，腳本與 plist 內完全沒有密碼字串。
- **免個資、可攜**：帳號留空時自動用 `$(id -un)`；LaunchAgent plist 於安裝時依本機路徑動態產生（不進版控）。
- **掛載點**：預設 `~/mnt/smb-home`（獨立於 Finder 的 `/Volumes/...`，免 sudo、避免衝突）。

## 檔案說明

| 檔案 | 用途 |
| --- | --- |
| `keep-smb-online.sh` | 主腳本：檢查並在需要時掛載 SMB |
| `save-credential.sh` | 由你執行一次，把密碼互動式存入 Keychain |
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

# 3) 把密碼存進 Keychain（會互動提示輸入密碼，不留明文）
./save-credential.sh

# 4) 安裝並啟用常駐排程
./install.sh
```

安裝後系統會立即嘗試掛載一次，之後每 60 秒自動檢查、掉線自動重連。

## 設定項（`config.env`）

| 變數 | 說明 | 預設 |
| --- | --- | --- |
| `SMB_SERVER` | SMB 伺服器 IP 或主機名 | `192.168.1.10` |
| `SMB_SHARE` | 要掛載的分享名稱 | `home` |
| `SMB_USER` | SMB 帳號；留空 = 目前登入者 | （空） |
| `MOUNT_SUBDIR` | 掛載點（相對家目錄） | `mnt/smb-home` |

## 部署到其他 macOS 主機

每台主機各自獨立安裝，帳號自動偵測、密碼各機獨立存放於各自的 Keychain：

```bash
git clone https://github.com/<你的帳號>/keep-smb-online.git
cd keep-smb-online
cp config.env.example config.env   # 依該台環境調整
./save-credential.sh               # 在該台輸入密碼
./install.sh
```

## 確認狀態

```bash
launchctl list | grep keep-smb-online     # 排程是否載入
mount | grep smb-home                     # 是否已掛載
tail -f ~/Library/Logs/keep-smb-online.log
```

## 移除

```bash
./uninstall.sh
# 如需一併刪除 Keychain 憑證（自行帶入你的伺服器）：
security delete-internet-password -s "<你的伺服器>" -a "$(id -un)"
```

## 需求環境

- macOS
- 內建 `mount_smbfs`、`launchctl`、`security`、`plutil`（皆為系統內建，無需額外安裝）
