// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation
import IOKit.hid

/// Non-blocking keyboard monitor used by the CLI `watch` command and the app's
/// Keyboard Lab. Needs Input Monitoring permission on macOS 13+.
public final class KeyMonitor {
    public struct Event {
        public let usage: UInt32
        public let pressed: Bool
        public let timestamp: TimeInterval
    }

    public typealias Handler = (Event) -> Void

    private let handler: Handler
    private var manager: IOHIDManager?

    public init(handler: @escaping Handler) {
        self.handler = handler
    }

    /// Returns `kIOReturnSuccess` when the HID manager opened. A permission
    /// problem usually comes back as `kIOReturnNotPermitted`.
    @discardableResult
    public func start() -> kern_return_t {
        stop()

        // Ask macOS for Input Monitoring (prompts once, then respects TCC).
        _ = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)

        let manager = IOHIDManagerCreate(kCFAllocatorDefault,
                                         IOOptionBits(kIOHIDOptionsTypeNone))
        let matching: [String: Any] = [
            kIOHIDDeviceUsagePageKey as String: 0x01,
            kIOHIDDeviceUsageKey as String: 0x06,
        ]
        IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)

        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterInputValueCallback(manager, { context, _, _, value in
            guard let context else { return }
            Unmanaged<KeyMonitor>.fromOpaque(context)
                .takeUnretainedValue()
                .handle(value)
        }, context)
        IOHIDManagerScheduleWithRunLoop(manager,
                                        CFRunLoopGetMain(),
                                        CFRunLoopMode.defaultMode.rawValue)

        let result = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        guard result == kIOReturnSuccess else {
            IOHIDManagerUnscheduleFromRunLoop(manager,
                                              CFRunLoopGetMain(),
                                              CFRunLoopMode.defaultMode.rawValue)
            return result
        }

        self.manager = manager
        return kIOReturnSuccess
    }

    public func stop() {
        guard let manager else { return }
        IOHIDManagerUnscheduleFromRunLoop(manager,
                                          CFRunLoopGetMain(),
                                          CFRunLoopMode.defaultMode.rawValue)
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        self.manager = nil
    }

    private func handle(_ value: IOHIDValue) {
        let element = IOHIDValueGetElement(value)
        guard IOHIDElementGetUsagePage(element) == 0x07 else { return }
        let usage = IOHIDElementGetUsage(element)
        guard usage >= 0x04, usage <= 0xE7 else { return }

        handler(Event(usage: UInt32(usage),
                      pressed: IOHIDValueGetIntegerValue(value) != 0,
                      timestamp: Date().timeIntervalSince1970))
    }
}
