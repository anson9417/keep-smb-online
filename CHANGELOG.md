# Changelog

本專案所有重大變更皆記錄於此檔案。

格式依循 [Keep a Changelog](https://keepachangelog.com/zh-TW/1.1.0/)，
版本號採用 [語意化版本](https://semver.org/lang/zh-TW/)。

## [2.1.0] - 2026-07-20

### Changed
- 掛載機制改用 AppleScript `mount volume`（走 NetAuth）取代 `mount_smbfs -N`。
  實測發現現代 macOS 的 `mount_smbfs` 不讀鑰匙圈，改走 NetAuth 才能自動取用憑證。
- 憑證建立改由 `save-credential.sh` 開啟 Finder 連線、勾選「記住密碼到鑰匙圈」（NetAuth 原生項目、無明文）。
- 掛載點改為系統慣例的 `/Volumes/<分享名稱>`。

### Added
- 憑證閘門：鑰匙圈無憑證時略過掛載，避免每 60 秒跳出互動密碼框。

### Removed
- `config.env` 移除已棄用的 `MOUNT_SUBDIR`（掛載點改由系統決定）。

## [2.0.0] - 2026-07-20

### Changed
- 通用化去個資：帳號改為自動帶入目前登入者（`$(id -un)`），移除所有寫死的帳號與伺服器 IP。
- 站點設定改由未納版控的 `config.env` 提供（新增 `config.env.example` 範本）。
- LaunchAgent plist 改為 `install.sh` 依本機路徑動態產生，Label 改為通用的 `com.keep-smb-online.agent`；不再於 repo 內存放含絕對路徑的 plist。
- Keychain 標籤移除帳號名，僅保留伺服器。

### Added
- `.gitignore`：排除 `config.env`、`*.log`、`.DS_Store`。
- README 新增「部署到其他 macOS 主機」段落與設定項說明表。

### Removed
- 移除含個資絕對路徑的固定 LaunchAgent plist（改為安裝時動態產生）。

## [1.0.0] - 2026-07-20

### Added
- `keep-smb-online.sh`：檢查並在需要時掛載指定 SMB 分享，含 stale mount 偵測與存活檢查。
- `save-credential.sh`：以互動方式將 SMB 密碼存入 macOS Keychain，全程無明文。
- LaunchAgent 排程：登入自動掛載、每 60 秒檢查重連。
- `install.sh` / `uninstall.sh`：一鍵佈署與移除排程。
- `README.md`：安裝、驗證、移除與自訂說明。
