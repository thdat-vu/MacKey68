// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation
import IOKit

/// Keeps a hidutil mapping alive: hidutil only touches devices that exist at the
/// moment it runs, so a replug (or a new wake-up) silently drops the remap.
/// This watches the IORegistry for HID devices appearing and re-applies.
public final class DeviceWatcher {
    public typealias Handler = (HIDDevice) -> Void
    public typealias DetachHandler = (DeviceID) -> Void

    private let onAttach: Handler
    private let onDetach: DetachHandler?
    private let wanted: DeviceID?
    private var notifyPort: IONotificationPortRef?
    private var arrivalIterator: io_iterator_t = 0
    private var removalIterator: io_iterator_t = 0
    private var applied = Set<String>()

    /// - Parameter matching: when set, only that vendor/product is reported.
    public init(matching: DeviceID? = nil,
                onAttach: @escaping Handler,
                onDetach: DetachHandler? = nil) {
        self.wanted = matching
        self.onAttach = onAttach
        self.onDetach = onDetach
    }

    public func start() {
        let port = IONotificationPortCreate(kIOMainPortDefault)
        notifyPort = port
        IONotificationPortSetDispatchQueue(port, DispatchQueue.main)

        let arrivalCallback: IOServiceMatchingCallback = { refcon, iterator in
            guard let refcon else { return }
            Unmanaged<DeviceWatcher>.fromOpaque(refcon).takeUnretainedValue().handleArrivals(iterator)
        }
        let removalCallback: IOServiceMatchingCallback = { refcon, iterator in
            guard let refcon else { return }
            Unmanaged<DeviceWatcher>.fromOpaque(refcon).takeUnretainedValue().handleRemovals(iterator)
        }

        let context = Unmanaged.passUnretained(self).toOpaque()

        if let matching = IOServiceMatching("IOHIDDevice") {
            IOServiceAddMatchingNotification(port, kIOFirstMatchNotification, matching,
                                             arrivalCallback, context, &arrivalIterator)
            handleArrivals(arrivalIterator)
        }
        if let matching = IOServiceMatching("IOHIDDevice") {
            IOServiceAddMatchingNotification(port, kIOTerminatedNotification, matching,
                                             removalCallback, context, &removalIterator)
            handleRemovals(removalIterator)
        }
    }

    public func stop() {
        if arrivalIterator != 0 { IOObjectRelease(arrivalIterator) }
        if removalIterator != 0 { IOObjectRelease(removalIterator) }
        if let port = notifyPort { IONotificationPortDestroy(port) }
        notifyPort = nil
    }

    private func handleArrivals(_ iterator: io_iterator_t) {
        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }
            guard let device = read(service), device.isKeyboard else { continue }
            if let wanted, !wanted.matches(device.id) { continue }
            // A device publishes several HID services (keyboard, consumer page,
            // vendor page, ...); only re-apply once per physical keyboard model.
            guard applied.insert("\(device.id.description)|\(device.product)").inserted else { continue }
            onAttach(device)
        }
    }

    private func handleRemovals(_ iterator: io_iterator_t) {
        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }
            guard let device = read(service) else { continue }
            applied.remove("\(device.id.description)|\(device.product)")
            onDetach?(device.id)
        }
    }

    private func read(_ service: io_service_t) -> HIDDevice? {
        func int(_ key: String) -> Int? {
            (IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?
                .takeRetainedValue() as? NSNumber)?.intValue
        }
        func string(_ key: String) -> String {
            IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?
                .takeRetainedValue() as? String ?? ""
        }
        guard let vendor = int("VendorID"), let product = int("ProductID") else { return nil }
        return HIDDevice(
            vendorID: vendor,
            productID: product,
            product: string("Product"),
            manufacturer: string("Manufacturer"),
            usagePage: int("PrimaryUsagePage") ?? 0,
            usage: int("PrimaryUsage") ?? 0,
            transport: string("Transport")
        )
    }
}

extension DeviceID {
    public func matches(_ other: DeviceID) -> Bool {
        (vendorID == nil || vendorID == other.vendorID)
            && (productID == nil || productID == other.productID)
    }
}
