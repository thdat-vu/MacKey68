// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation
import AppKit
import IOKit
import MacKeyKit

/// State for the Keyboard Lab: live key tester, chatter detection and
/// "press a key to select it" mode.
@MainActor
final class KeyLab: ObservableObject {
    enum Status: Equatable {
        case idle
        case running
        case denied(kern_return_t)

        var isRunning: Bool { self == .running }
    }

    struct Event: Identifiable {
        let id = UUID()
        let usage: UInt32
        let name: String
        let pressed: Bool
        let at: Date
        let delta: TimeInterval?
    }

    static let chatterThreshold: TimeInterval = 0.05

    @Published private(set) var status: Status = .idle
    @Published private(set) var events: [Event] = []
    @Published private(set) var counts: [UInt32: Int] = [:]
    @Published private(set) var chatter: [UInt32: Int] = [:]
    @Published private(set) var total = 0
    @Published private(set) var lastKey: Event?
    @Published var learnMode = false

    /// Called when learn mode captures a key down.
    var onLearn: ((UInt32) -> Void)?

    private var monitor: KeyMonitor?
    private var lastDown: [UInt32: TimeInterval] = [:]
    private var lastEventTime: TimeInterval?

    func start() {
        guard monitor == nil else { return }

        let monitor = KeyMonitor { [weak self] event in
            Task { @MainActor in self?.handle(event) }
        }
        let result = monitor.start()
        guard result == kIOReturnSuccess else {
            status = .denied(result)
            return
        }
        self.monitor = monitor
        status = .running
    }

    func stop() {
        monitor?.stop()
        monitor = nil
        status = .idle
        learnMode = false
    }

    func reset() {
        events = []
        counts = [:]
        chatter = [:]
        total = 0
        lastKey = nil
        lastDown = [:]
        lastEventTime = nil
    }

    func openInputMonitoringSettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
        ) else { return }
        NSWorkspace.shared.open(url)
    }

    private func handle(_ event: KeyMonitor.Event) {
        let delta = lastEventTime.map { event.timestamp - $0 }
        lastEventTime = event.timestamp

        let item = Event(usage: event.usage,
                         name: KeyCodes.name(for: event.usage)
                            ?? String(format: "0x%02X", event.usage),
                         pressed: event.pressed,
                         at: Date(),
                         delta: delta)

        if event.pressed {
            total += 1
            counts[event.usage, default: 0] += 1
            if let previous = lastDown[event.usage],
               event.timestamp - previous < Self.chatterThreshold {
                chatter[event.usage, default: 0] += 1
            }
            lastDown[event.usage] = event.timestamp
            lastKey = item

            if learnMode {
                learnMode = false
                onLearn?(event.usage)
            }
        }

        events.insert(item, at: 0)
        if events.count > 16 { events.removeLast(events.count - 16) }
    }
}
