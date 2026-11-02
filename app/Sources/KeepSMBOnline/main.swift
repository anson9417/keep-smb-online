import AppKit
import ServiceManagement

// build-app.sh --uninstall 使用：註銷登入項目後直接結束，不啟動 UI
if CommandLine.arguments.contains("--unregister-login") {
    if SMAppService.mainApp.status == .enabled {
        try? SMAppService.mainApp.unregister()
    }
    exit(0)
}

// 頂端列常駐 App：無 Dock 圖示（Info.plist 的 LSUIElement）
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
