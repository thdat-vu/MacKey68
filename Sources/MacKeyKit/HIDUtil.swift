// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation

public enum HIDUtilError: Error, CustomStringConvertible {
    case failed(arguments: [String], status: Int32, output: String)

    public var description: String {
        switch self {
        case let .failed(arguments, status, output):
            let message = output.trimmingCharacters(in: .whitespacesAndNewlines)
            return "hidutil \(arguments.joined(separator: " ")) exited \(status)\(message.isEmpty ? "" : ": \(message)")"
        }
    }
}

public enum HIDUtil {
    public static let path = "/usr/bin/hidutil"

    /// Writes the mapping into the running HID stack. Survives sleep, but not a
    /// replug of the keyboard, which is why `mackey agent` exists.
    public static func apply(_ mappings: [ResolvedMapping], matching device: DeviceID?) throws -> String {
        guard !mappings.isEmpty else {
            return try reset(matching: device)
        }
        let entries = mappings.map { mapping in
            "{\"HIDKeyboardModifierMappingSrc\":\(KeyCodes.usage(mapping.source)),"
                + "\"HIDKeyboardModifierMappingDst\":\(KeyCodes.usage(mapping.destination))}"
        }
        let payload = "{\"UserKeyMapping\":[\(entries.joined(separator: ","))]}"
        return try run(setArguments(for: device) + [payload])
    }

    /// Clears every remap for the matched device (or for all keyboards).
    public static func reset(matching device: DeviceID?) throws -> String {
        try run(setArguments(for: device) + ["{\"UserKeyMapping\":[]}"])
    }

    public static func currentMapping(matching device: DeviceID?) throws -> String {
        var arguments = ["property"]
        if let json = matchingJSON(device) {
            arguments += ["--matching", json]
        }
        arguments += ["--get", "UserKeyMapping"]
        return try run(arguments)
    }

    private static func setArguments(for device: DeviceID?) -> [String] {
        var arguments = ["property"]
        if let json = matchingJSON(device) {
            arguments += ["--matching", json]
        }
        arguments += ["--set"]
        return arguments
    }

    private static func matchingJSON(_ device: DeviceID?) -> String? {
        guard let device, !device.isEmpty else { return nil }
        var parts: [String] = []
        if let vendor = device.vendorID { parts.append("\"VendorID\":\(vendor)") }
        if let product = device.productID { parts.append("\"ProductID\":\(product)") }
        return "{\(parts.joined(separator: ","))}"
    }

    @discardableResult
    private static func run(_ arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        let output = String(decoding: data, as: UTF8.self)
        guard process.terminationStatus == 0 else {
            throw HIDUtilError.failed(arguments: arguments, status: process.terminationStatus, output: output)
        }
        return output
    }
}
