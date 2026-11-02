import AppKit

/// 設定視窗：伺服器 / 分享 / 帳號
/// 純 AppKit 實作（Command Line Tools 沒有 SwiftUI 巨集外掛，無法用 @State）
final class SettingsWindowController: NSWindowController, NSTextFieldDelegate {
    private let onSave: () -> Void
    private let serverField = NSTextField()
    private let shareField = NSTextField()
    private let userField = NSTextField()
    private let saveButton = NSButton(title: "儲存", target: nil, action: nil)

    init(onSave: @escaping () -> Void) {
        self.onSave = onSave
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 200),
            styleMask: [.titled, .closable],
            backing: .buffered, defer: false)
        window.title = "Keep SMB Online 設定"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        buildContent()
        window.center()
    }

    required init?(coder: NSCoder) { fatalError() }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(serverField)
    }

    private func buildContent() {
        let s = Settings.shared
        serverField.stringValue = s.server
        serverField.placeholderString = "192.168.1.10"
        shareField.stringValue = s.share
        shareField.placeholderString = "home"
        userField.stringValue = s.userSetting
        userField.placeholderString = "留空 = \(NSUserName())"
        serverField.delegate = self

        let grid = NSGridView(views: [
            [NSTextField(labelWithString: "伺服器："), serverField],
            [NSTextField(labelWithString: "分享名稱："), shareField],
            [NSTextField(labelWithString: "帳號："), userField],
        ])
        grid.column(at: 0).xPlacement = .trailing
        grid.rowSpacing = 10
        grid.columnSpacing = 8
        for f in [serverField, shareField, userField] {
            f.widthAnchor.constraint(equalToConstant: 280).isActive = true
        }

        let note = NSTextField(wrappingLabelWithString:
            "密碼不存於 App；請用選單「記住密碼…」在 Finder 視窗勾選記住到鑰匙圈。")
        note.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        note.textColor = .secondaryLabelColor

        let cancel = NSButton(title: "取消", target: self, action: #selector(cancel))
        cancel.keyEquivalent = "\u{1b}"
        saveButton.target = self
        saveButton.action = #selector(save)
        saveButton.keyEquivalent = "\r"
        updateSaveEnabled()

        let buttons = NSStackView(views: [NSView(), cancel, saveButton])
        buttons.orientation = .horizontal

        let stack = NSStackView(views: [grid, note, buttons])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        stack.translatesAutoresizingMaskIntoConstraints = false
        buttons.widthAnchor.constraint(equalTo: grid.widthAnchor).isActive = true
        note.widthAnchor.constraint(equalTo: grid.widthAnchor).isActive = true

        let content = NSView()
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            stack.topAnchor.constraint(equalTo: content.topAnchor),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor),
        ])
        window?.contentView = content
    }

    func controlTextDidChange(_ obj: Notification) { updateSaveEnabled() }

    private func updateSaveEnabled() {
        saveButton.isEnabled = !serverField.stringValue.trimmingCharacters(in: .whitespaces).isEmpty
    }

    @objc private func save() {
        let s = Settings.shared
        s.server = serverField.stringValue
        s.share = shareField.stringValue
        s.userSetting = userField.stringValue
        onSave()
        close()
    }

    @objc private func cancel() { close() }
}
