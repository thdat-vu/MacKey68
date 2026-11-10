import Foundation
import IOKit.hid

public struct HIDDevice: Equatable {
    public var vendorID: Int
    public var productID: Int
    public var product: String
    public var manufacturer: String
    public var usagePage: Int
    public var usage: Int
    public var transport: String

    public var isKeyboard: Bool { usagePage == 0x01 && (usage == 0x06 || usage == 0x07) }

    public var id: DeviceID { DeviceID(vendorID: vendorID, productID: productID) }

    public var label: String {
        [manufacturer, product].filter { !$0.isEmpty }.joined(separator: " ")
    }
}

public enum HIDDevices {
    /// Enumerates HID services straight from the IORegistry, so no Input
    /// Monitoring permission is needed just to look at what is plugged in.
    public static func all() -> [HIDDevice] {
        let matching = IOServiceMatching("IOHIDDevice")
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return []
        }
        defer { IOObjectRelease(iterator) }

        var devices: [HIDDevice] = []
        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }
            func int(_ key: String) -> Int? {
                (IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?
                    .takeRetainedValue() as? NSNumber)?.intValue
            }
            func string(_ key: String) -> String {
                IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?
                    .takeRetainedValue() as? String ?? ""
            }
            guard let vendor = int("VendorID"), let product = int("ProductID") else { continue }
            devices.append(HIDDevice(
                vendorID: vendor,
                productID: product,
                product: string("Product"),
                manufacturer: string("Manufacturer"),
                usagePage: int("PrimaryUsagePage") ?? 0,
                usage: int("PrimaryUsage") ?? 0,
                transport: string("Transport")
            ))
        }
        return devices.sorted { ($0.label, $0.usage) < ($1.label, $1.usage) }
    }

    public static func keyboards() -> [HIDDevice] {
        all().filter(\.isKeyboard)
    }

    /// Collapses the per-service entries into one row per physical device.
    public static func uniqueKeyboards() -> [HIDDevice] {
        var seen = Set<DeviceID>()
        return keyboards().filter { seen.insert($0.id).inserted }
    }
}
