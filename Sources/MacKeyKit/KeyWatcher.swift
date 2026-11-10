import Foundation
import IOKit.hid

/// Live dump of what the keyboard actually reports. This is the tool you reach
/// for when you do not know what an Fn combo really sends.
///
/// Reading keyboard input needs the Input Monitoring permission on macOS 13+;
/// the first run will either prompt for it or print a pointer to System Settings.
public enum KeyWatcher {
    public static func run(filter: DeviceID? = nil) -> Never {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        let matching: [String: Any] = [
            kIOHIDDeviceUsagePageKey as String: 0x01,
            kIOHIDDeviceUsageKey as String: 0x06,
        ]
        IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)

        IOHIDManagerRegisterInputValueCallback(manager, { _, _, _, value in
            let element = IOHIDValueGetElement(value)
            let usagePage = IOHIDElementGetUsagePage(element)
            let usage = IOHIDElementGetUsage(element)
            let pressed = IOHIDValueGetIntegerValue(value) != 0

            guard usagePage == 0x07, usage >= 0x04, usage <= 0xE7 else { return }
            let name = KeyCodes.name(for: UInt32(usage)) ?? "?"
            print(String(format: "%@  usage 0x%02X  %-13@  -> hidutil 0x%X",
                         pressed ? "down" : "up  ", usage, name as NSString,
                         KeyCodes.usage(UInt32(usage))))
            fflush(stdout)
        }, nil)

        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        let opened = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        if opened != kIOReturnSuccess {
            FileHandle.standardError.write(Data("""
            Không mở được thiết bị HID (mã \(opened)).
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
