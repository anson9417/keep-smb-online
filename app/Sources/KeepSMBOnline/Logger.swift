import Foundation

/// 與 keep-smb-online.sh 共用同一個 log 檔，沿用相同規則：
/// 與上一則內容相同時不重複寫；超過 512KB 只保留最後 200 行。
enum Logger {
    static let url = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Logs/keep-smb-online.log")

    private static let maxBytes = 524_288
    private static let keepLines = 200
    private static let queue = DispatchQueue(label: "keep-smb-online.log")
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f
    }()

    static func log(_ msg: String) {
        queue.async {
            let fm = FileManager.default
            try? fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            rotate()

            if let text = try? String(contentsOf: url, encoding: .utf8),
               let last = text.split(separator: "\n").last {
                // 去掉開頭的 "yyyy-MM-dd HH:mm:ss " 再比較
                let body = last.split(separator: " ", maxSplits: 2).dropFirst(2).first.map(String.init) ?? ""
                if body == msg { return }
            }

            let line = "\(formatter.string(from: Date())) \(msg)\n"
            if let handle = try? FileHandle(forWritingTo: url) {
                handle.seekToEndOfFile()
                handle.write(Data(line.utf8))
                try? handle.close()
            } else {
                try? line.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }

    private static func rotate() {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? Int, size > maxBytes,
              let text = try? String(contentsOf: url, encoding: .utf8) else { return }
        let tail = text.split(separator: "\n", omittingEmptySubsequences: false).suffix(keepLines + 1)
        try? tail.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
    }
}
