import AppKit
import ServiceManagement

/// 頂端列圖示：左鍵點擊切換開/關，右鍵或 ⌥ 點擊開啟選單（仿 Caffeine）
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let controller = SMBController()
    private let settings = Settings.shared
    private var statusItem: NSStatusItem!
    private var settingsWindow: SettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        controller.onChange = { [weak self] _ in self?.updateIcon() }
        controller.onUnmountFailed = { [weak self] point, output in
            self?.alert("未卸載 \(point)", "有檔案正在使用，未卸載；常駐已停止。\n請關閉使用中的檔案後，再到 Finder 退出。\n\n\(output)")
        }
        controller.restore()
        updateIcon()

        // 首次啟動尚未設定伺服器時，直接開設定視窗
        if !settings.isConfigured { openSettings() }
    }

    // MARK: - 點擊

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp || event.modifierFlags.contains(.option)
            || event.modifierFlags.contains(.control) {
            showMenu()
        } else {
            toggle()
        }
    }

    @objc private func toggle() {
        let turnOn = !controller.isEnabled
        if turnOn && !settings.isConfigured {
            openSettings()
            return
        }
        controller.setEnabled(turnOn)
        updateIcon()
    }

    private func showMenu() {
        statusItem.menu = buildMenu()
        statusItem.button?.performClick(nil)
    }

    // 選單關閉後移除，讓左鍵恢復成切換
    func menuDidClose(_ menu: NSMenu) {
        statusItem.menu = nil
    }

    // MARK: - 圖示

    private func updateIcon() {
        guard let button = statusItem?.button else { return }
        let symbol: String
        var alpha: CGFloat = 1
        switch controller.state {
        case .off:
            symbol = "externaldrive"
            alpha = 0.6
        case .checking:
            symbol = "externaldrive.fill"
            alpha = 0.6
        case .mounted:
            symbol = "externaldrive.fill"
        case .notConfigured, .noCredential, .failed:
            symbol = "externaldrive.badge.exclamationmark"
        }
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: statusText)
            ?? NSImage(systemSymbolName: "externaldrive", accessibilityDescription: statusText)
        image?.isTemplate = true
        button.image = image
        button.alphaValue = alpha
        button.toolTip = "Keep SMB Online — \(statusText)"
    }

    private var statusText: String {
        switch controller.state {
        case .off: return "已關閉"
        case .checking: return "檢查中…"
        case .mounted: return "已掛載 \(settings.mountPoint)"
        case .notConfigured: return "尚未設定伺服器"
        case .noCredential: return "鑰匙圈尚無憑證"
        case .failed: return "掛載失敗，稍後重試"
        }
    }

    // MARK: - 選單

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self

        let target = settings.isConfigured
            ? "\(settings.user)@\(settings.server)/\(settings.share)" : "尚未設定"
        menu.addItem(disabledItem("SMB：\(target)"))
        menu.addItem(disabledItem("狀態：\(statusText)"))
        menu.addItem(.separator())

        menu.addItem(item(controller.isEnabled ? "關閉常駐掛載" : "開啟常駐掛載", #selector(toggle)))
        let remount = item("立即檢查 / 重新掛載", #selector(checkNow))
        remount.isEnabled = controller.isEnabled
        menu.addItem(remount)
        let finder = item("在 Finder 開啟", #selector(openInFinder))
        finder.isEnabled = controller.state == .mounted
        menu.addItem(finder)
        menu.addItem(.separator())

        let cred = item("記住密碼…", #selector(saveCredential))
        cred.isEnabled = settings.isConfigured
        menu.addItem(cred)
        menu.addItem(item("設定…", #selector(openSettings), key: ","))
        let login = item("登入時啟動", #selector(toggleLaunchAtLogin))
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)
        menu.addItem(item("查看 log", #selector(openLog)))
        menu.addItem(.separator())
        menu.addItem(item("結束 Keep SMB Online", #selector(quit), key: "q"))
        return menu
    }

    private func item(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let i = NSMenuItem(title: title, action: action, keyEquivalent: key)
        i.target = self
        return i
    }

    private func disabledItem(_ title: String) -> NSMenuItem {
        let i = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        i.isEnabled = false
        return i
    }

    // MARK: - 動作

    @objc private func checkNow() { controller.check() }

    @objc private func openInFinder() {
        let point = SMBController.mountPoint(server: settings.server, share: settings.share)
            ?? settings.mountPoint
        NSWorkspace.shared.open(URL(fileURLWithPath: point))
    }

    /// 等同 save-credential.sh：用 Finder 開啟連線視窗，讓使用者勾選記住密碼
    @objc private func saveCredential() {
        guard let url = settings.url else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func openSettings() {
        // 每次重建，讓表單讀到最新值
        settingsWindow = SettingsWindowController { [weak self] in
            guard let self else { return }
            Logger.log("設定已更新：\(self.settings.server)/\(self.settings.share)")
            if self.controller.isEnabled {
                self.controller.check()
            }
            self.updateIcon()
        }
        settingsWindow?.show()
    }

    @objc private func toggleLaunchAtLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
            }
        } catch {
            alert("無法變更登入時啟動", error.localizedDescription
                  + "\n\n請確認 App 位於「應用程式」資料夾（./build-app.sh --install）。")
        }
    }

    @objc private func openLog() {
        if !FileManager.default.fileExists(atPath: Logger.url.path) {
            FileManager.default.createFile(atPath: Logger.url.path, contents: nil)
        }
        NSWorkspace.shared.open(Logger.url)
    }

    @objc private func quit() { NSApp.terminate(nil) }

    private func alert(_ title: String, _ text: String) {
        NSApp.activate(ignoringOtherApps: true)
        let a = NSAlert()
        a.messageText = title
        a.informativeText = text
        a.runModal()
    }
}
