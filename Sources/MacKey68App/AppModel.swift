// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation
import AppKit
import Combine
import MacKeyKit

/// Nguồn sự thật của app: config, profile đang bật, và việc ghi xuống hidutil.
struct AppRef: Equatable {
    var id: String
    var name: String
}

/// Một bàn phím để hiện trong picker (đang cắm hoặc đã cấu hình trước đó).
struct DeviceChoice: Identifiable, Equatable {
    var device: DeviceID
    var model: String?
    var name: String
    var layoutID: LayoutID
    var online: Bool

    var id: String { "\(device.description)|\(model ?? "")" }
    var label: String {
        let suffix = online ? "" : " · offline"
        return "\(name.isEmpty ? device.description : name)\(suffix)"
    }
}

/// Trạng thái remap, giữ dạng cấu trúc để đổi ngôn ngữ không phải áp lại.
enum Status: Equatable {
    case notApplied
    case noDevice
    case applied(profile: String, count: Int, deviceCount: Int)
    case disabled
    case configWriteFailed(String)
    case failed(String)
}

@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()

    static let configURL: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config/mackey/keymap.json")

    private static let languageKey = "MacKey68Language"
    private static let guideKey = "MacKey68HasSeenGuide"

    @Published private(set) var config: KeymapConfig
    @Published private(set) var activeProfileID: String
    @Published private(set) var status: Status = .notApplied
    @Published private(set) var detectedDevice: DeviceID?
    @Published private(set) var availableDevices: [HIDDevice] = []
    @Published var selectedKey: LayoutKey?
    /// App không phải MacKey68 vừa được kích hoạt, dùng cho nút "gắn profile".
    @Published private(set) var lastForeignApp: AppRef?
    /// Ngôn ngữ giao diện (VI/EN).
    @Published private(set) var language: Language
    /// Popup hướng dẫn.
    @Published var isShowingGuide = false
    /// Keyboard Lab (key tester / select by pressing).
    @Published var isShowingLab = false

    /// Bật/tắt toàn bộ remap.
    @Published var enabled: Bool = true {
        didSet { apply() }
    }

    /// Tự chạy khi đăng nhập.
    @Published var launchesAtLogin: Bool = LoginItem.isInstalled {
        didSet {
            guard launchesAtLogin != oldValue else { return }
            launchesAtLogin ? LoginItem.install() : LoginItem.remove()
        }
    }

    private var workspaceObserver: NSObjectProtocol?
    private var watcher: DeviceWatcher?
    private var pendingDeviceSync: Task<Void, Never>?
    private var ready = false

    init() {
        let stored = UserDefaults.standard.string(forKey: Self.languageKey)
        self.language = Language(rawValue: stored ?? "") ?? .vi

        let detected = HIDDevices.uniqueKeyboards()
        let loaded = (try? KeymapConfig.load(from: Self.configURL))
            ?? Self.seedConfig(detected: detected)
        var config = loaded
        // Luôn chuẩn hoá về dạng profiles để phần sửa key có chỗ ghi.
        if config.profiles == nil || config.profiles?.isEmpty == true {
            config.profiles = config.allProfiles
            config.mappings = nil
        }
        Self.migrateDevices(&config, detected: detected)

        self.config = config
        self.activeProfileID = config.defaultProfile.id
        self.availableDevices = detected
        let activeConnected = Self.isConnected(device: config.device,
                                               model: config.activeModel,
                                               in: detected)
        if !activeConnected {
            let preferred = Self.preferredDevice(in: detected, config: config)
            self.config.device = preferred?.id
            self.config.activeModel = preferred.map(Self.modelName(for:))
        } else if self.config.activeModel == nil {
            self.config.activeModel = detected.first {
                config.device?.matches($0.id) == true
            }.map(Self.modelName(for:))
        }
        self.detectedDevice = config.device.flatMap { active in
            detected.first { active.matches($0.id) }?.id
        } ?? Self.preferredDevice(in: detected, config: config)?.id

        ready = true
        persist()
        apply()
        noteForeign(NSWorkspace.shared.frontmostApplication)
        observeFrontmostApp()
        startWatchingDevices()
    }

    // MARK: - Device + layout

    /// Entry of the keyboard selected in the picker (VID:PID + model).
    var activeDeviceEntry: DeviceConfig? {
        guard let active = config.device else { return nil }
        if let model = config.activeModel, !model.isEmpty {
            return config.devices?.first { $0.matches(active, model: model) }
        }
        return config.deviceConfig(for: active)
    }

    /// Layout to draw for the selected keyboard.
    var layoutID: LayoutID {
        activeDeviceEntry?.layoutID ?? .tkl
    }

    var layout: KeyboardLayout { Layouts.layout(for: layoutID) }

    var deviceChoices: [DeviceChoice] {
        var choices: [DeviceChoice] = []
        var onlineIDs = Set<String>()

        for device in availableDevices {
            let entry = config.deviceConfig(for: device)
            let choice = DeviceChoice(
                device: device.id,
                model: Self.modelName(for: device),
                name: entry?.name.isEmpty == false ? entry!.name : Self.friendlyName(for: device),
                layoutID: entry?.layoutID
                    ?? Layouts.detect(product: device.product,
                                      manufacturer: device.manufacturer,
                                      vendorID: device.vendorID,
                                      productID: device.productID),
                online: true
            )
            choices.append(choice)
            onlineIDs.insert(device.id.description)
        }

        for entry in config.devices ?? [] where !onlineIDs.contains(entry.device.description) {
            choices.append(DeviceChoice(device: entry.device,
                                        model: entry.model,
                                        name: entry.name,
                                        layoutID: entry.layoutID,
                                        online: false))
        }

        return choices.sorted {
            if $0.online != $1.online { return $0.online }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    func selectDevice(_ choice: DeviceChoice) {
        config.device = choice.device
        config.activeModel = choice.model

        if config.devices?.contains(where: {
            $0.matches(choice.device, model: choice.model)
        }) != true {
            config.devices = (config.devices ?? []) + [
                DeviceConfig(device: choice.device,
                             model: choice.model,
                             name: choice.name,
                             layout: choice.layoutID.rawValue)
            ]
        }
        selectedKey = nil
        persist()
        apply()
    }

    func setLayout(_ layout: LayoutID) {
        guard let active = config.device else { return }
        var devices = config.devices ?? []
        let model = config.activeModel

        if let index = devices.firstIndex(where: { $0.matches(active, model: model) }) {
            devices[index].layout = layout.rawValue
            if devices[index].model == nil { devices[index].model = model }
        } else {
            devices.append(DeviceConfig(device: active,
                                        model: model,
                                        name: active.description,
                                        layout: layout.rawValue))
        }
        config.devices = devices
        selectedKey = nil
        persist()
    }

    func refreshDevices() {
        syncDetectedDevices()
    }

    // MARK: - Profile

    var activeProfile: Profile {
        config.allProfiles.first { $0.id == activeProfileID } ?? config.defaultProfile
    }

    var statusText: String {
        switch status {
        case .notApplied:
            return t("Chưa áp dụng", "Not applied")
        case .noDevice:
            return t("Chưa thấy bàn phím nào — cắm bàn phím vào nhé",
                     "No keyboard found — plug one in")
        case .applied(let profile, let count, let deviceCount):
            let devices = deviceCount == 1
                ? t("1 bàn phím", "1 keyboard")
                : t("\(deviceCount) bàn phím", "\(deviceCount) keyboards")
            return t("\(profile) · \(count) phím · \(devices)",
                     "\(profile) · \(count) keys · \(devices)")
        case .disabled:
            return t("Đang tắt", "Disabled")
        case .configWriteFailed(let message):
            return t("Không ghi được config: \(message)",
                     "Couldn't write config: \(message)")
        case .failed(let message):
            return t("Lỗi: \(message)", "Error: \(message)")
        }
    }

    var deviceLabel: String {
        config.device?.description ?? t("chưa thấy bàn phím", "keyboard not found")
    }

    func setLanguage(_ language: Language) {
        guard language != self.language else { return }
        self.language = language
        UserDefaults.standard.set(language.rawValue, forKey: Self.languageKey)
    }

    // MARK: - Guide

    var hasSeenGuide: Bool {
        UserDefaults.standard.bool(forKey: Self.guideKey)
    }

    /// Lần đầu mở cửa sổ bàn phím thì tự hiện hướng dẫn.
    func presentGuideIfNeeded() {
        guard !hasSeenGuide else { return }
        isShowingGuide = true
    }

    func openGuide() {
        isShowingGuide = true
    }

    func markGuideSeen() {
        UserDefaults.standard.set(true, forKey: Self.guideKey)
        isShowingGuide = false
    }

    // MARK: - Sharing

    var presets: [ProfilePreset] { Presets.all }

    func exportData(profile: Profile? = nil) throws -> Data {
        let chosen = profile ?? activeProfile
        return try ProfileTransfer.data(for: chosen, keyboard: config.activeModel)
    }

    @discardableResult
    func importProfile(data: Data) throws -> Profile {
        let incoming = try ProfileTransfer.profile(from: data)
        let unique = ProfileTransfer.withUniqueID(incoming, existing: config.allProfiles)

        var profiles = config.allProfiles
        profiles.append(unique)
        config.profiles = profiles
        config.mappings = nil
        activeProfileID = unique.id
        persist()
        apply()
        return unique
    }

    @discardableResult
    func importProfile(fileURL: URL) throws -> Profile {
        try importProfile(data: try Data(contentsOf: fileURL))
    }

    /// Áp preset vào profile cùng id; nếu chưa có thì thêm mới.
    func applyPreset(_ preset: ProfilePreset) {
        var profiles = config.allProfiles
        if let index = profiles.firstIndex(where: { $0.id == preset.id }) {
            profiles[index].name = preset.title
            profiles[index].mappings = preset.mappings
        } else {
            profiles.append(Profile(id: preset.id,
                                    name: preset.title,
                                    autoFor: [],
                                    mappings: preset.mappings))
        }
        config.profiles = profiles
        config.mappings = nil
        activeProfileID = preset.id
        persist()
        apply()
    }

    // MARK: - Profile management

    var canDeleteProfile: Bool { config.allProfiles.count > 1 }

    func renameProfile(id: String, to name: String) {
        let trimmed = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(60))
        guard !trimmed.isEmpty,
              let index = config.profiles?.firstIndex(where: { $0.id == id })
        else { return }
        config.profiles?[index].name = trimmed
        persist()
    }

    func duplicateProfile(id: String) {
        guard let original = config.allProfiles.first(where: { $0.id == id }) else { return }
        var copy = ProfileTransfer.withUniqueID(
            Profile(id: original.id,
                    name: original.name,
                    autoFor: original.autoFor,
                    mappings: original.mappings),
            existing: config.allProfiles
        )
        copy.name = "\(original.name) copy"
        // Không nhân bản rule app để tránh hai profile cùng tranh một app.
        copy.autoFor = []

        var profiles = config.allProfiles
        let insertAt = (profiles.firstIndex(where: { $0.id == id }) ?? profiles.count - 1) + 1
        profiles.insert(copy, at: insertAt)
        config.profiles = profiles
        config.mappings = nil
        activeProfileID = copy.id
        persist()
        apply()
    }

    func deleteProfile(id: String) {
        let profiles = config.allProfiles
        guard profiles.count > 1,
              let index = profiles.firstIndex(where: { $0.id == id })
        else { return }

        var updated = profiles
        updated.remove(at: index)
        config.profiles = updated
        config.mappings = nil
        if config.defaultProfileID == id {
            config.defaultProfileID = nil
        }
        if activeProfileID == id {
            activeProfileID = config.fallbackProfile.id
        }
        persist()
        apply()
    }

    func setDefaultProfile(id: String) {
        guard config.allProfiles.contains(where: { $0.id == id }) else { return }
        config.defaultProfileID = id
        persist()
    }

    func isDefaultProfile(_ id: String) -> Bool {
        config.fallbackProfile.id == id
    }

    func selectProfile(_ id: String) {
        activeProfileID = id
        apply()
    }

    /// Bundle id của app đang phía trước → đổi profile tương ứng.
    func syncProfile(with bundleID: String?) {
        let match = config.profile(matchingBundleID: bundleID)
            ?? config.fallbackProfile
        guard match.id != activeProfileID else { return }
        activeProfileID = match.id
        apply()
    }

    private func noteForeign(_ app: NSRunningApplication?) {
        guard let app, let id = app.bundleIdentifier,
              id != Bundle.main.bundleIdentifier else { return }
        lastForeignApp = AppRef(id: id, name: app.localizedName ?? id)
    }

    /// Gắn profile hiện tại với app vừa dùng: mở app đó là tự đổi.
    func linkLastForeignApp() {
        guard let app = lastForeignApp,
              let index = config.profiles?.firstIndex(where: { $0.id == activeProfileID })
        else { return }
        if config.profiles?[index].autoFor.contains(app.id) != true {
            config.profiles?[index].autoFor.append(app.id)
        }
        persist()
        apply()
    }

    func unlink(bundleID: String) {
        guard let index = config.profiles?.firstIndex(where: { $0.id == activeProfileID })
        else { return }
        config.profiles?[index].autoFor.removeAll { $0 == bundleID }
        persist()
    }

    private func observeFrontmostApp() {
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            Task { @MainActor in
                guard let self else { return }
                self.noteForeign(app)
                self.syncProfile(with: app?.bundleIdentifier)
            }
        }
    }

    private func startWatchingDevices() {
        let watcher = DeviceWatcher(
            matching: nil,
            onAttach: { [weak self] device in
                Task { @MainActor in self?.handleAttach(device) }
            },
            onDetach: { [weak self] _ in
                Task { @MainActor in self?.handleDetach() }
            }
        )
        self.watcher = watcher
        watcher.start()
    }

    private func handleAttach(_ device: HIDDevice) {
        scheduleDeviceSync()
    }

    private func handleDetach() {
        scheduleDeviceSync()
    }

    /// Gom nhiều sự kiện HID (mỗi bàn phím phát nhiều service) rồi dò lại một lần.
    private func scheduleDeviceSync() {
        pendingDeviceSync?.cancel()
        pendingDeviceSync = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            self?.syncDetectedDevices()
        }
    }

    /// Bàn phím vừa cắm được tự thêm vào danh sách với layout đoán được.
    private func syncDetectedDevices() {
        let detected = HIDDevices.uniqueKeyboards()
        availableDevices = detected

        var entries = config.devices ?? []
        var changed = false

        for device in detected {
            let friendly = Self.friendlyName(for: device)
            let modelName = Self.modelName(for: device)
            if let index = entries.firstIndex(where: { $0.matches(device) }) {
                if entries[index].model == nil || entries[index].model == device.product
                    || entries[index].model == device.label {
                    entries[index].model = modelName
                    changed = true
                }
                // Nâng tên chung chung ("SONiX USB DEVICE") thành tên dễ đọc.
                if entries[index].name.isEmpty || entries[index].name == device.label,
                   entries[index].name != friendly {
                    entries[index].name = friendly
                    changed = true
                }
                continue
            }
            entries.append(DeviceConfig(
                device: device.id,
                model: modelName,
                name: friendly,
                layout: Layouts.detect(product: device.product,
                                       manufacturer: device.manufacturer,
                                       vendorID: device.vendorID,
                                       productID: device.productID).rawValue
            ))
            changed = true
        }

        let activeConnected = Self.isConnected(device: config.device,
                                               model: config.activeModel,
                                               in: detected)
        if !activeConnected,
           let preferred = Self.preferredDevice(in: detected, config: config) {
            config.device = preferred.id
            config.activeModel = Self.modelName(for: preferred)
            changed = true
        } else if config.activeModel == nil,
                  let active = config.device,
                  let match = detected.first(where: { active.matches($0.id) }) {
            config.activeModel = Self.modelName(for: match)
            changed = true
        }

        if changed { config.devices = entries }
        detectedDevice = config.device.flatMap { active in
            detected.first { active.matches($0.id) }?.id
        } ?? Self.preferredDevice(in: detected, config: config)?.id

        if changed { persist() }
        apply()
    }

    // MARK: - Remap

    /// Key nào trên bàn phím đang gửi usage gì.
    func destination(for key: LayoutKey) -> UInt32? {
        activeProfile.destination(for: key.usage)
    }

    /// Keyboard Lab sees the usage after hidutil on some systems; map it back to
    /// the physical key so "press to select" still highlights the right cap.
    func sourceUsage(forReportedUsage usage: UInt32) -> UInt32 {
        for mapping in activeProfile.mappings {
            guard KeyCodes.code(for: mapping.to) == usage,
                  let source = KeyCodes.code(for: mapping.from) else { continue }
            return source
        }
        return usage
    }

    func setMapping(source: UInt32, to destination: UInt32?) {
        guard source != 0,
              let index = config.profiles?.firstIndex(where: { $0.id == activeProfileID })
        else { return }

        var mappings = config.profiles?[index].mappings ?? []
        mappings.removeAll { KeyCodes.code(for: $0.from) == source }
        if let destination, destination != source {
            mappings.append(KeyMapping(from: Self.canonicalName(source),
                                       to: Self.canonicalName(destination)))
        }
        config.profiles?[index].mappings = mappings
        persist()
        apply()
    }

    func apply() {
        guard ready else { return }

        let connected = availableDevices
        var targets: [DeviceID] = []
        for entry in config.enabledDevices {
            for device in connected where entry.matches(device) {
                if !targets.contains(where: { $0 == device.id }) {
                    targets.append(device.id)
                }
            }
        }
        // Config cũ chỉ có `device`, chưa có `devices`.
        if targets.isEmpty,
           let legacy = config.device,
           connected.contains(where: { legacy.matches($0.id) }) {
            targets = [legacy]
        }
        guard !targets.isEmpty else {
            status = .noDevice
            return
        }

        do {
            let resolved = try KeymapResolver.resolve(activeProfile.mappings)
            if enabled {
                for target in targets {
                    _ = try HIDUtil.apply(resolved, matching: target)
                }
            } else {
                for target in targets {
                    _ = try HIDUtil.reset(matching: target)
                }
            }
            status = enabled
                ? .applied(profile: activeProfile.name,
                           count: resolved.count,
                           deviceCount: targets.count)
                : .disabled
        } catch {
            status = .failed(String(describing: error))
        }
    }

    private func persist() {
        do {
            try config.save(to: Self.configURL)
        } catch {
            status = .configWriteFailed(String(describing: error))
        }
    }

    // MARK: - Helpers

    private static func canonicalName(_ usage: UInt32) -> String {
        KeyCodes.name(for: usage) ?? String(format: "0x%02X", usage)
    }

    static func modelName(for device: HIDDevice) -> String {
        let product = device.product.trimmingCharacters(in: .whitespacesAndNewlines)
        let label = device.label.trimmingCharacters(in: .whitespacesAndNewlines)
        let generic = ["", "usb device", "keyboard", "usb keyboard", "hid keyboard", "device"]
        // Generic product strings need the manufacturer ("SONiX USB DEVICE"),
        // branded ones stay stable ("K68 BT5.0").
        if generic.contains(product.lowercased()), !label.isEmpty {
            return label
        }
        return product.isEmpty ? label : product
    }

    private static func modelMatches(_ model: String, _ device: HIDDevice) -> Bool {
        model.caseInsensitiveCompare(device.product) == .orderedSame
            || model.caseInsensitiveCompare(device.label) == .orderedSame
    }

    private static func isConnected(device: DeviceID?,
                                    model: String?,
                                    in detected: [HIDDevice]) -> Bool {
        guard let device else { return false }
        if let model, !model.isEmpty {
            return detected.contains {
                device.matches($0.id) && modelMatches(model, $0)
            }
        }
        return detected.contains { device.matches($0.id) }
    }

    private static func preferredDevice(in detected: [HIDDevice],
                                        config: KeymapConfig) -> HIDDevice? {
        if let active = config.device,
           let model = config.activeModel, !model.isEmpty,
           let exact = detected.first(where: {
               active.matches($0.id) && modelMatches(model, $0)
           }) {
            return exact
        }
        if let active = config.device,
           let match = detected.first(where: { active.matches($0.id) }) {
            return match
        }
        return detected.first { $0.product.localizedCaseInsensitiveContains("K68") }
            ?? detected.first { $0.product.localizedCaseInsensitiveContains("EK387") }
            ?? detected.first
    }

    /// Bổ sung entry cho bàn phím đang dùng, giữ entry cũ. Không tự thêm mọi
    /// thiết bị HID: chuột chơi game cũng có thể khai báo một keyboard collection.
    private static func migrateDevices(_ config: inout KeymapConfig,
                                       detected: [HIDDevice]) {
        var entries = config.devices ?? []

        func ensure(_ device: HIDDevice) {
            if let index = entries.firstIndex(where: { $0.matches(device) }) {
                if entries[index].model == nil || entries[index].model == device.product
                    || entries[index].model == device.label {
                    entries[index].model = modelName(for: device)
                }
                return
            }
            entries.append(DeviceConfig(
                device: device.id,
                model: modelName(for: device),
                name: friendlyName(for: device),
                layout: Layouts.detect(product: device.product,
                                       manufacturer: device.manufacturer,
                                       vendorID: device.vendorID,
                                       productID: device.productID).rawValue
            ))
        }

        detected.forEach(ensure)

        if let legacy = config.device,
           !entries.contains(where: { $0.device.matches(legacy) }) {
            let match = detected.first { legacy.matches($0.id) }
            entries.append(DeviceConfig(
                device: legacy,
                model: match.map(modelName(for:)),
                name: match.map(friendlyName(for:)) ?? legacy.description,
                layout: Layouts.detect(product: match?.product ?? "",
                                       manufacturer: match?.manufacturer ?? "",
                                       vendorID: legacy.vendorID,
                                       productID: legacy.productID).rawValue
            ))
        }

        if config.device == nil {
            config.device = entries.first { entry in
                detected.contains { entry.device.matches($0.id) }
            }?.device
        }
        if config.activeModel == nil,
           let active = config.device,
           let match = detected.first(where: { active.matches($0.id) }) {
            config.activeModel = modelName(for: match)
        }

        config.devices = entries
    }

    /// Tên dễ đọc cho vài board đã gặp; còn lại dùng tên HID.
    static func friendlyName(for device: HIDDevice) -> String {
        switch String(format: "%04X:%04X", device.vendorID, device.productID) {
        case "9AEA:1029": return "Ziyoulang K68"
        case "0C45:7644": return "Edra EK387 Pro"
        default: return device.label.isEmpty ? device.id.description : device.label
        }
    }

    /// Cấu hình đầu tiên: Cmd sát Space, `` ` `` một phím, và khi vào game thì
    /// nhường chỗ đó lại cho Alt.
    static func seedConfig(detected: [HIDDevice] = HIDDevices.uniqueKeyboards()) -> KeymapConfig {
        let devices = detected.map { device in
            DeviceConfig(device: device.id,
                         model: modelName(for: device),
                         name: friendlyName(for: device),
                         layout: Layouts.detect(product: device.product,
                                                manufacturer: device.manufacturer,
                                                vendorID: device.vendorID,
                                                productID: device.productID).rawValue)
        }
        let active = devices.first(where: { $0.device.vendorID == 0x9AEA }) ?? devices.first
        return KeymapConfig(
            name: "MacKey68",
            device: active?.device,
            activeModel: active?.model,
            defaultProfileID: "mac",
            devices: devices,
            mappings: nil,
            profiles: [
                Profile(
                    id: "mac",
                    name: "macOS",
                    autoFor: [],
                    mappings: [
                        KeyMapping(from: "LeftAlt", to: "LeftGUI"),
                        KeyMapping(from: "LeftGUI", to: "LeftAlt"),
                    ]
                ),
                Profile(
                    id: "league",
                    name: "League of Legends",
                    autoFor: ["com.riotgames."],
                    mappings: [
                        KeyMapping(from: "CapsLock", to: "Grave"),
                    ]
                ),
            ]
        )
    }
}
