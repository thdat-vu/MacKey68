// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation

public struct DeviceID: Codable, Equatable, Hashable {
    public var vendorID: Int?
    public var productID: Int?

    public init(vendorID: Int? = nil, productID: Int? = nil) {
        self.vendorID = vendorID
        self.productID = productID
    }

    public var isEmpty: Bool { vendorID == nil && productID == nil }

    public var description: String {
        switch (vendorID, productID) {
        case let (v?, p?): return String(format: "0x%04X:0x%04X", v, p)
        case let (v?, nil): return String(format: "0x%04X:*", v)
        case let (nil, p?): return String(format: "*:0x%04X", p)
        default: return "all keyboards"
        }
    }

    /// Parses "0x3151:0x5029", "3151:5029" or "vendor:product".
    public init?(spec: String) {
        let parts = spec.split(separator: ":")
        guard parts.count == 2 else { return nil }
        func number(_ text: Substring) -> Int? {
            let s = String(text)
            if s.hasPrefix("0x") || s.hasPrefix("0X") {
                return Int(s.dropFirst(2), radix: 16)
            }
            return Int(s, radix: 16) ?? Int(s)
        }
        guard let v = number(parts[0]), let p = number(parts[1]) else { return nil }
        self.init(vendorID: v, productID: p)
    }
}

public struct KeyMapping: Codable, Equatable {
    public var from: String
    public var to: String

    public init(from: String, to: String) {
        self.from = from
        self.to = to
    }
}

public struct KeymapConfig: Codable {
    public var name: String?
    public var device: DeviceID?
    /// Dạng cũ (một bộ mapping duy nhất). Vẫn đọc được.
    public var mappings: [KeyMapping]?
    /// Nhiều bộ mapping, có thể gắn với app để tự chuyển.
    public var profiles: [Profile]?

    public init(name: String? = nil,
                device: DeviceID? = nil,
                mappings: [KeyMapping]? = nil,
                profiles: [Profile]? = nil) {
        self.name = name
        self.device = device
        self.mappings = mappings
        self.profiles = profiles
    }

    /// Luôn có ít nhất một profile; config cũ được nâng thành profile "default".
    public var allProfiles: [Profile] {
        if let profiles, !profiles.isEmpty { return profiles }
        return [Profile(id: "default", name: "Default", autoFor: [], mappings: mappings ?? [])]
    }

    public var defaultProfile: Profile { allProfiles[0] }

    public func profile(matchingBundleID bundleID: String?) -> Profile? {
        guard let bundleID, !bundleID.isEmpty else { return nil }
        return allProfiles.first { profile in
            profile.autoFor.contains { bundleID == $0 || bundleID.hasPrefix($0) }
        }
    }

    public static func load(from url: URL) throws -> KeymapConfig {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(KeymapConfig.self, from: data)
    }

    public func save(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        // Ghi qua file tạm rồi đổi tên để không bao giờ để lại config hỏng.
        let temporary = url.appendingPathExtension("tmp")
        try data.write(to: temporary)
        _ = try FileManager.default.replaceItemAt(url, withItemAt: temporary)
    }
}

public struct Profile: Codable, Identifiable, Equatable {
    public var id: String
    public var name: String
    /// Bundle id của app mà profile này tự bật khi app đó đang là app phía trước.
    public var autoFor: [String]
    public var mappings: [KeyMapping]

    public init(id: String, name: String, autoFor: [String] = [], mappings: [KeyMapping]) {
        self.id = id
        self.name = name
        self.autoFor = autoFor
        self.mappings = mappings
    }

    public func destination(for source: UInt32) -> UInt32? {
        for mapping in mappings {
            guard let src = KeyCodes.code(for: mapping.from), src == source,
                  let dst = KeyCodes.code(for: mapping.to) else { continue }
            return dst
        }
        return nil
    }
}

public enum KeymapError: Error, CustomStringConvertible {
    case unknownKey(String, side: String)
    case duplicateSource(String)

    public var description: String {
        switch self {
        case let .unknownKey(name, side):
            return "'\(name)' (on the \(side) side) is not a key I know. Run `mackey keys` for the list."
        case let .duplicateSource(name):
            return "'\(name)' is mapped more than once."
        }
    }
}

public struct ResolvedMapping: Equatable {
    public var source: UInt32
    public var destination: UInt32

    public init(source: UInt32, destination: UInt32) {
        self.source = source
        self.destination = destination
    }
}

public enum KeymapResolver {
    public static func resolve(_ mappings: [KeyMapping]) throws -> [ResolvedMapping] {
        var seen = Set<UInt32>()
        var result: [ResolvedMapping] = []

        for mapping in mappings {
            guard let src = KeyCodes.code(for: mapping.from) else {
                throw KeymapError.unknownKey(mapping.from, side: "left")
            }
            guard let dst = KeyCodes.code(for: mapping.to) else {
                throw KeymapError.unknownKey(mapping.to, side: "right")
            }
            guard seen.insert(src).inserted else {
                throw KeymapError.duplicateSource(mapping.from)
            }
            result.append(ResolvedMapping(source: src, destination: dst))
        }
        return result
    }
}
