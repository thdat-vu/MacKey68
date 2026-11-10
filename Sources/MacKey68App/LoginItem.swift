// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation

/// Quản lý LaunchAgent của chính app, để bản tải về (DMG) tự chạy khi đăng nhập
/// mà người dùng không phải mở Terminal.
enum LoginItem {
    static let label = "com.mackey68.app"

    static var plistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    static var logURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/MacKey68.log")
    }

    static var isInstalled: Bool {
        FileManager.default.fileExists(atPath: plistURL.path)
    }

    /// Ghi LaunchAgent. Không bootstrap ngay vì app đang chạy sẽ thành hai instance;
    /// file có hiệu lực từ lần đăng nhập sau.
    static func install() {
        guard Bundle.main.bundleURL.pathExtension == "app" else { return }

        // Cho LaunchServices mở app (thay vì chạy binary trực tiếp) để các sự kiện
        // reopen/URL hoạt động đúng như khi người dùng bấm icon.
        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": ["/usr/bin/open", "-a", Bundle.main.bundleURL.path, "--args", "--agent"],
            "RunAtLoad": true,
            "KeepAlive": false,
            "ProcessType": "Interactive",
            "StandardOutPath": logURL.path,
            "StandardErrorPath": logURL.path,
        ]

        do {
            try FileManager.default.createDirectory(
                at: plistURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try PropertyListSerialization.data(
                fromPropertyList: plist, format: .xml, options: 0
            )
            try data.write(to: plistURL, options: .atomic)
        } catch {
            NSLog("MacKey68: không ghi được LaunchAgent: \(error)")
        }
    }

    /// Xoá file; job đang chạy trong phiên này vẫn sống nhưng sẽ không tự chạy lại
    /// sau khi đăng xuất.
    static func remove() {
        try? FileManager.default.removeItem(at: plistURL)
    }

    /// App nằm trong Applications (cài bằng DMG) thì tự bật tự-chạy-lúc-đăng-nhập.
    static func installIfNeededForInstalledApp() {
        guard Bundle.main.bundlePath.contains("/Applications/"),
              !isInstalled else { return }
        install()
    }
}
