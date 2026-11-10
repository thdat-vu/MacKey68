import Foundation
import AppKit
import Combine
import MacKeyKit

/// Nguồn sự thật của app: config, profile đang bật, và việc ghi xuống hidutil.
struct AppRef: Equatable {
    var id: String
    var name: String
}

/// Trạng thái remap, giữ dạng cấu trúc để đổi ngôn ngữ không phải áp lại.
enum Status: Equatable {
    case notApplied
    case noDevice
    case applied(profile: String, count: Int, device: String)
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

    @Published private(set) var config: KeymapConfig
    @Published private(set) var activeProfileID: String
    @Published private(set) var status: Status = .notApplied
    @Published private(set) var detectedDevice: DeviceID?
    @Published var selectedKey: LayoutKey?
    /// App không phải MacKey68 vừa được kích hoạt, dùng cho nút "gắn profile".
    @Published private(set) var lastForeignApp: AppRef?
    /// Ngôn ngữ giao diện (VI/EN).
    @Published private(set) var language: Language

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

    let layout = Layouts.k68

    private var workspaceObserver: NSObjectProtocol?
    private var watcher: DeviceWatcher?
    private var ready = false

    init() {
        let stored = UserDefaults.standard.string(forKey: Self.languageKey)
        self.language = Language(rawValue: stored ?? "") ?? .vi

        let loaded = (try? KeymapConfig.load(from: Self.configURL)) ?? Self.seedConfig()
        var config = loaded
        // Luôn chuẩn hoá về dạng profiles để phần sửa key có chỗ ghi.
        if config.profiles == nil || config.profiles?.isEmpty == true {
            config.profiles = config.allProfiles
            config.mappings = nil
        }
        self.config = config
        self.activeProfileID = config.defaultProfile.id
        self.detectedDevice = Self.detectDevice() ?? config.device
        if config.device == nil, let detected = detectedDevice {
            self.config.device = detected
        }

        ready = true
        persist()
        apply()
        noteForeign(NSWorkspace.shared.frontmostApplication)
        observeFrontmostApp()
        startWatchingDevices()
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
            return t("Chưa thấy bàn phím — cắm K68 vào nhé",
                     "Keyboard not found — plug in the K68")
        case .applied(let profile, let count, let device):
            return t("\(profile) · \(count) phím · \(device)",
                     "\(profile) · \(count) keys · \(device)")
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

    func selectProfile(_ id: String) {
        activeProfileID = id
        apply()
    }

    /// Bundle id của app đang phía trước → đổi profile tương ứng.
    func syncProfile(with bundleID: String?) {
        let match = config.profile(matchingBundleID: bundleID)
            ?? config.allProfiles.first { $0.autoFor.isEmpty }
            ?? config.defaultProfile
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
        // Profile này không còn là profile "mặc định" nếu nó đã gắn với app.
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
        let watcher = DeviceWatcher(matching: nil) { [weak self] device in
            Task { @MainActor in self?.handleAttach(device) }
        }
        self.watcher = watcher
        watcher.start()
    }

    private func handleAttach(_ device: HIDDevice) {
        guard config.device?.matches(device.id) == true
                || (config.device == nil && device.product.localizedCaseInsensitiveContains("K68"))
        else { return }
        if config.device == nil {
            config.device = device.id
            persist()
        }
        detectedDevice = device.id
        apply()
    }

    // MARK: - Remap

    /// Key nào trên bàn phím đang gửi usage gì.
    func destination(for key: LayoutKey) -> UInt32? {
        activeProfile.destination(for: key.usage)
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

        guard let device = config.device else {
            status = .noDevice
            return
        }

        do {
            if enabled {
                let resolved = try KeymapResolver.resolve(activeProfile.mappings)
                _ = try HIDUtil.apply(resolved, matching: device)
                status = .applied(profile: activeProfile.name,
                                  count: resolved.count,
                                  device: device.description)
            } else {
                _ = try HIDUtil.reset(matching: device)
                status = .disabled
            }
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

    private static func detectDevice() -> DeviceID? {
        HIDDevices.uniqueKeyboards()
            .first { $0.product.localizedCaseInsensitiveContains("K68") }?
            .id
    }

    /// Cấu hình đầu tiên: Cmd sát Space, `` ` `` một phím, và khi vào game thì
    /// nhường chỗ đó lại cho Alt.
    static func seedConfig() -> KeymapConfig {
        KeymapConfig(
            name: "K68",
            device: detectDevice(),
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
