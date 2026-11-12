// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation
import CoreGraphics
import ApplicationServices
import MacKeyKit

struct LayerRules {
    var triggerKeyCodes: Set<Int64> = []
    var mappings: [Int64: Int64] = [:]
    /// Reported name (after hidutil) → physical name, lowercased.
    var inverseProfile: [String: String] = [:]

    var isEmpty: Bool { triggerKeyCodes.isEmpty || mappings.isEmpty }

    static func build(layers: [Layer], profile: Profile) -> LayerRules {
        var rules = LayerRules()

        func normalized(_ name: String) -> String {
            name.lowercased().filter { !" -_".contains($0) }
        }

        for mapping in profile.mappings {
            let from = normalized(mapping.from)
            let to = normalized(mapping.to)
            if rules.inverseProfile[to] == nil {
                rules.inverseProfile[to] = from
            }
        }

        for layer in layers where layer.enabled {
            if let code = MacKeyCodes.code(for: layer.trigger) {
                rules.triggerKeyCodes.insert(Int64(code))
            }
            for mapping in layer.mappings {
                let physical = normalized(mapping.from)
                let reportedName = profile.mappings.first {
                    normalized($0.from) == physical
                }?.to ?? mapping.from
                guard let source = MacKeyCodes.code(for: reportedName),
                      let target = MacKeyCodes.code(for: mapping.to) else { continue }
                rules.mappings[Int64(source)] = Int64(target)
            }
        }

        return rules
    }
}

/// Active CGEventTap for hold-to-activate layers. It only touches events while
/// the trigger key is held; everything else passes through unchanged.
final class LayerEngine: @unchecked Sendable {
    enum Status: Equatable {
        case off
        case running
        case denied
        case failed(String)
    }

    private static let magic: Int64 = 0x4D_4B_36_38 // "MK68"

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var rules = LayerRules()
    private let lock = NSLock()
    private var layerActive = false
    private var translations: [Int64: Int64] = [:]
    private(set) var status: Status = .off

    func start(rules: LayerRules) -> Status {
        stop()
        self.rules = rules

        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
        guard AXIsProcessTrusted() else {
            status = .denied
            return status
        }
        guard !rules.isEmpty else {
            status = .failed("Layer has no mappings or trigger.")
            return status
        }

        let mask = (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: { _, type, event, refcon in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let engine = Unmanaged<LayerEngine>
                    .fromOpaque(refcon).takeUnretainedValue()
                return engine.handle(type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            status = .denied
            return status
        }

        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.source = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        status = .running
        return status
    }

    func update(rules: LayerRules) {
        lock.lock()
        self.rules = rules
        lock.unlock()
    }

    func stop() {
        lock.lock()
        layerActive = false
        translations.removeAll()
        lock.unlock()

        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let source {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        tap = nil
        source = nil
        status = .off
    }


    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            // If our callback is too slow, stay disabled rather than looping.
            if type == .tapDisabledByUserInput, let tap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        let magicValue = event.getIntegerValueField(.eventSourceUserData)
        if magicValue == Self.magic {
            return Unmanaged.passUnretained(event)
        }

        lock.lock()
        let rules = self.rules
        let active = layerActive
        lock.unlock()

        let code = event.getIntegerValueField(.keyboardEventKeycode)

        if rules.triggerKeyCodes.contains(code) {
            if type == .flagsChanged {
                let next = event.flags.contains(.maskAlphaShift)
                lock.lock()
                layerActive = next
                lock.unlock()
                return nil
            }
            if type == .keyDown {
                lock.lock(); layerActive = true; lock.unlock()
                return nil
            }
            if type == .keyUp {
                lock.lock(); layerActive = false; lock.unlock()
                return nil
            }
        }

        if type == .keyUp, let target = translation(for: code) {
            lock.lock()
            translations.removeValue(forKey: code)
            lock.unlock()
            return synthetic(target: target, from: event, down: false)
        }

        guard active, type == .keyDown else {
            return Unmanaged.passUnretained(event)
        }
        guard let target = rules.mappings[code] else {
            return Unmanaged.passUnretained(event)
        }

        lock.lock()
        translations[code] = target
        lock.unlock()
        return synthetic(target: target, from: event, down: true)
    }

    private func translation(for code: Int64) -> Int64? {
        lock.lock()
        defer { lock.unlock() }
        return translations[code]
    }

    private func synthetic(target: Int64, from event: CGEvent, down: Bool) -> Unmanaged<CGEvent>? {
        guard let new = CGEvent(keyboardEventSource: nil,
                                virtualKey: CGKeyCode(target),
                                keyDown: down) else {
            return nil
        }
        new.flags = event.flags
        new.setIntegerValueField(
            .keyboardEventAutorepeat,
            value: event.getIntegerValueField(.keyboardEventAutorepeat)
        )
        new.setIntegerValueField(.eventSourceUserData, value: Self.magic)
        return Unmanaged.passRetained(new)
    }
}
