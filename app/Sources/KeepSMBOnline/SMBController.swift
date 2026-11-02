import AppKit
import Network

/// 常駐掛載的核心邏輯，行為移植自 keep-smb-online.sh。
/// 所有外部指令在背景 queue 執行，狀態變化回主執行緒通知。
final class SMBController {
    enum State: Equatable {
        case off
        case checking
        case mounted
        case notConfigured
        case noCredential
        case failed(String)
    }

    static let checkInterval: TimeInterval = 60

    private let settings = Settings.shared
    private let queue = DispatchQueue(label: "keep-smb-online.smb")
    private var timer: Timer?
    private var pathMonitor: NWPathMonitor?
    private var wakeObserver: NSObjectProtocol?
    /// 避免同時跑兩次 mount volume（計時器、喚醒、網路變化可能同時觸發）
    private var inFlight = false

    private(set) var state: State = .off {
        didSet { if state != oldValue { onChange?(state) } }
    }
    var onChange: ((State) -> Void)?
    /// 卸載失敗（通常是有檔案正在使用）時呼叫，參數為掛載點與錯誤訊息
    var onUnmountFailed: ((String, String) -> Void)?

    var isEnabled: Bool { settings.enabled }

    // MARK: - 開/關

    func setEnabled(_ on: Bool) {
        settings.enabled = on
        if on {
            Logger.log("已由頂端列開啟常駐掛載")
            startWatching()
            check()
        } else {
            Logger.log("已由頂端列關閉常駐掛載")
            stopWatching()
            state = .off
            unmount()
        }
    }

    /// App 啟動時依上次狀態恢復
    func restore() {
        if settings.enabled {
            startWatching()
            check()
        } else {
            state = .off
        }
    }

    // MARK: - 檢查與掛載

    /// 等同 keep-smb-online.sh 一次執行：已掛載就安靜；無憑證就略過；否則掛載
    func check() {
        guard settings.enabled, !inFlight else { return }
        guard settings.isConfigured else {
            state = .notConfigured
            Logger.log("未設定 SMB 伺服器（請在頂端列選單開啟「設定…」填入）")
            return
        }
        let server = settings.server, share = settings.share, user = settings.user
        let url = settings.url?.absoluteString ?? ""
        if state != .mounted { state = .checking }
        inFlight = true

        queue.async { [weak self] in
            guard let self else { return }
            let result: State
            if Self.mountPoint(server: server, share: share) != nil {
                result = .mounted
            } else if !Self.hasCredential(server: server, user: user) {
                Logger.log("鑰匙圈尚無 \(server) / \(user) 的憑證，略過掛載。請從選單選「記住密碼…」")
                result = .noCredential
            } else {
                Logger.log("偵測到未掛載，開始掛載 \(url)")
                let r = Self.run("/usr/bin/osascript", ["-e", "mount volume \"\(url)\""])
                if r.status == 0 {
                    Logger.log("掛載成功：\(r.output)")
                    result = .mounted
                } else {
                    Logger.log("掛載失敗：\(r.output)（請確認網路可達，且已用 Finder 將密碼記住到鑰匙圈）")
                    result = .failed(r.output)
                }
            }
            DispatchQueue.main.async {
                self.inFlight = false
                // 檢查途中被關閉就不覆寫狀態
                if self.settings.enabled { self.state = result }
            }
        }
    }

    private func unmount() {
        let server = settings.server, share = settings.share
        queue.async { [weak self] in
            guard let point = Self.mountPoint(server: server, share: share) else { return }
            // 不強制卸載：有檔案正在使用時寧可留著，避免未存資料寫入失敗
            let r = Self.run("/usr/sbin/diskutil", ["unmount", point])
            if r.status == 0 {
                Logger.log("已卸載 \(point)")
            } else {
                Logger.log("卸載失敗：\(r.output)（常駐已停止，掛載保留）")
                DispatchQueue.main.async { self?.onUnmountFailed?(point, r.output) }
            }
        }
    }

    // MARK: - 觸發來源：60 秒計時器（保底）、系統喚醒、網路變化

    private func startWatching() {
        stopWatching()
        let t = Timer(timeInterval: Self.checkInterval, repeats: true) { [weak self] _ in self?.check() }
        t.tolerance = 5
        RunLoop.main.add(t, forMode: .common)
        timer = t

        // 喚醒後網路通常還沒就緒，稍等再檢查
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Logger.log("系統喚醒，稍後檢查掛載")
            self?.checkSoon(after: 5)
        }

        // 網路變為可用時立即檢查（例：換 Wi-Fi、接上網路線）
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            guard path.status == .satisfied else { return }
            DispatchQueue.main.async { self?.checkSoon(after: 2) }
        }
        monitor.start(queue: queue)
        pathMonitor = monitor
    }

    private func stopWatching() {
        timer?.invalidate()
        timer = nil
        pathMonitor?.cancel()
        pathMonitor = nil
        if let o = wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(o)
            wakeObserver = nil
        }
    }

    private func checkSoon(after seconds: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { [weak self] in self?.check() }
    }

    // MARK: - 系統指令

    /// 回傳該分享的實際掛載點（例：/Volumes/home），未掛載則 nil
    static func mountPoint(server: String, share: String) -> String? {
        let out = run("/sbin/mount", []).output
        let needle = "@\(server)/\(share) on "
        for line in out.split(separator: "\n") {
            guard let r = line.range(of: needle) else { continue }
            let rest = line[r.upperBound...]
            if let paren = rest.range(of: " (") {
                return String(rest[..<paren.lowerBound])
            }
            return String(rest)
        }
        return nil
    }

    static func hasCredential(server: String, user: String) -> Bool {
        run("/usr/bin/security", ["find-internet-password", "-s", server, "-a", user]).status == 0
    }

    @discardableResult
    static func run(_ path: String, _ args: [String]) -> (status: Int32, output: String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = pipe
        do {
            try p.run()
        } catch {
            return (-1, error.localizedDescription)
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        let text = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return (p.terminationStatus, text)
    }
}
