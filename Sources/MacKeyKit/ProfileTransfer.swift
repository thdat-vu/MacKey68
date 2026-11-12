// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation

/// JSON file used to share one profile with another MacKey68 user.
struct ProfileDocument: Codable {
    var format: String
    var version: Int
    var profile: Profile
    /// Model of the keyboard the profile was exported from (informational).
    var keyboard: String?
}

public enum ProfileTransferError: LocalizedError {
    case badFormat
    case unsupportedVersion(Int)
    case tooLarge
    case invalid(String)

    public var errorDescription: String? {
        switch self {
        case .badFormat:
            return "Not a MacKey68 profile file."
        case .unsupportedVersion(let version):
            return "Profile format version \(version) is not supported."
        case .tooLarge:
            return "Profile file is too large."
        case .invalid(let message):
            return message
        }
    }
}

public enum ProfileTransfer {
    public static let format = "mackey68.profile"
    public static let version = 1
    public static let maxFileSize = 256 * 1024

    public static func data(for profile: Profile, keyboard: String?) throws -> Data {
        let document = ProfileDocument(format: format,
                                       version: version,
                                       profile: profile,
                                       keyboard: keyboard)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(document)
    }

    public static func profile(from data: Data) throws -> Profile {
        guard data.count <= maxFileSize else { throw ProfileTransferError.tooLarge }

        let decoder = JSONDecoder()
        let document: ProfileDocument
        do {
            document = try decoder.decode(ProfileDocument.self, from: data)
        } catch {
            // Also accept a bare profile object, for hand-written files.
            if let bare = try? decoder.decode(Profile.self, from: data) {
                return try normalized(bare)
            }
            throw ProfileTransferError.badFormat
        }
        guard document.format == format else { throw ProfileTransferError.badFormat }
        guard document.version == version else {
            throw ProfileTransferError.unsupportedVersion(document.version)
        }
        return try normalized(document.profile)
    }

    public static func normalized(_ profile: Profile) throws -> Profile {
        var result = profile
        result.id = slug(result.id.isEmpty ? result.name : result.id)
        result.name = String(profile.name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(60))
        if result.name.isEmpty { result.name = "Imported profile" }
        if result.id.isEmpty { result.id = "imported" }

        guard (1...64).contains(result.mappings.count) else {
            throw ProfileTransferError.invalid("A profile needs 1–64 key mappings.")
        }
        for mapping in result.mappings {
            guard !mapping.from.isEmpty, !mapping.to.isEmpty else {
                throw ProfileTransferError.invalid("A mapping has an empty key.")
            }
        }
        _ = try KeymapResolver.resolve(result.mappings)

        result.autoFor = result.autoFor
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.count <= 200 }
        if result.autoFor.count > 32 {
            result.autoFor = Array(result.autoFor.prefix(32))
        }
        return result
    }

    public static func withUniqueID(_ profile: Profile,
                             existing: [Profile]) -> Profile {
        var result = profile
        let ids = Set(existing.map(\.id))
        guard ids.contains(result.id) else { return result }

        let base = result.id
        var suffix = 2
        while ids.contains("\(base)-\(suffix)") { suffix += 1 }
        result.id = "\(base)-\(suffix)"
        if existing.contains(where: { $0.name == result.name }) {
            result.name = "\(result.name) (\(suffix))"
        }
        return result
    }

    private static func slug(_ text: String) -> String {
        let lowered = text.lowercased()
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789-")
        let mapped = lowered.unicodeScalars.map { scalar -> Character in
            allowed.contains(scalar) ? Character(scalar) : "-"
        }
        let joined = String(mapped)
            .split(separator: "-", omittingEmptySubsequences: true)
            .joined(separator: "-")
        return String(joined.prefix(48))
    }
}
