import Foundation

public enum LaunchAgent {
    public static let label = "com.mackey68.agent"

    public static var plistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    public static var logURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/MacKey68.log")
    }

    public static func install(executable: URL, arguments: [String]) throws {
        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": [executable.path] + arguments,
            "RunAtLoad": true,
            "KeepAlive": true,
            "ProcessType": "Interactive",
            "StandardOutPath": logURL.path,
            "StandardErrorPath": logURL.path,
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try FileManager.default.createDirectory(at: plistURL.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try data.write(to: plistURL)

        // Replace an already loaded copy so the new arguments take effect.
        _ = shell("/bin/launchctl", ["bootout", "gui/\(getuid())", plistURL.path])
        try shellThrowing("/bin/launchctl", ["bootstrap", "gui/\(getuid())", plistURL.path])
    }

    public static func uninstall() throws {
        _ = shell("/bin/launchctl", ["bootout", "gui/\(getuid())", plistURL.path])
        if FileManager.default.fileExists(atPath: plistURL.path) {
            try FileManager.default.removeItem(at: plistURL)
        }
    }

    public static func status() -> String {
        let output = shell("/bin/launchctl", ["print", "gui/\(getuid())/\(label)"])
        if let output, output.contains("state = running") { return "running" }
        if let output, !output.isEmpty { return "loaded" }
        return "not installed"
    }

    @discardableResult
    private static func shell(_ launchPath: String, _ arguments: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
        } catch {
            return nil
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(decoding: data, as: UTF8.self)
    }

    private static func shellThrowing(_ launchPath: String, _ arguments: [String]) throws {
        let output = shell(launchPath, arguments) ?? ""
        if output.contains("Bootstrap failed") {
            throw NSError(domain: "MacKey68", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: output])
        }
    }
}
