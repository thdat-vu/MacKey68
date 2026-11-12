// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation
import IOKit.hid

/// Live dump of what the keyboard actually reports. This is the tool you reach
/// for when you do not know what an Fn combo really sends.
///
/// Reading keyboard input needs the Input Monitoring permission on macOS 13+;
/// the first run will either prompt for it or print a pointer to System Settings.
public enum KeyWatcher {
    public static func run(filter: DeviceID? = nil) -> Never {
        _ = filter
        let monitor = KeyMonitor { event in
            let name = KeyCodes.name(for: event.usage) ?? "?"
            print(String(format: "%@  usage 0x%02X  %-13@  -> hidutil 0x%X",
                         event.pressed ? "down" : "up  ", event.usage, name as NSString,
                         KeyCodes.usage(event.usage)))
            fflush(stdout)
        }

        let result = monitor.start()
        guard result == kIOReturnSuccess else {
            FileHandle.standardError.write(Data("""
            Không mở được thiết bị HID (mã \(result)).
            Vào System Settings → Privacy & Security → Input Monitoring và bật cho Terminal
            (hoặc cho app mackey), rồi chạy lại.

            """.utf8))
            exit(1)
        }

        FileHandle.standardError.write(Data("Đang nghe phím... Ctrl+C để dừng.\n".utf8))
        RunLoop.main.run()
        exit(0)
    }
}
