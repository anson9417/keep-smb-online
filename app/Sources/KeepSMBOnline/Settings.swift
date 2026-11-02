import Foundation

/// 站點設定，存在 UserDefaults。帳號留空 = 目前登入者。
final class Settings {
    static let shared = Settings()
    private let defaults = UserDefaults.standard

    private enum Key {
        static let server = "smbServer"
        static let share = "smbShare"
        static let user = "smbUser"
        static let enabled = "enabled"
    }

    var server: String {
        get { defaults.string(forKey: Key.server) ?? "" }
        set { defaults.set(newValue.trimmingCharacters(in: .whitespaces), forKey: Key.server) }
    }

    var share: String {
        get {
            let v = defaults.string(forKey: Key.share) ?? ""
            return v.isEmpty ? "home" : v
        }
        set { defaults.set(newValue.trimmingCharacters(in: .whitespaces), forKey: Key.share) }
    }

    /// 原始設定值（可能為空）
    var userSetting: String {
        get { defaults.string(forKey: Key.user) ?? "" }
        set { defaults.set(newValue.trimmingCharacters(in: .whitespaces), forKey: Key.user) }
    }

    /// 實際使用的帳號
    var user: String { userSetting.isEmpty ? NSUserName() : userSetting }

    var enabled: Bool {
        get { defaults.bool(forKey: Key.enabled) }
        set { defaults.set(newValue, forKey: Key.enabled) }
    }

    var isConfigured: Bool { !server.isEmpty }

    var url: URL? {
        var c = URLComponents()
        c.scheme = "smb"
        c.user = user
        c.host = server
        c.path = "/" + share
        return c.url
    }

    var mountPoint: String { "/Volumes/\(share)" }
}
