// SPDX-License-Identifier: GPL-3.0-or-later
import SwiftUI
import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        let launchedByAgent = ProcessInfo.processInfo.environment["MACKEY_AGENT"] == "1"
            || CommandLine.arguments.contains("--agent")
        let wantsBoard = CommandLine.arguments.contains("--board")
        let wantsLab = CommandLine.arguments.contains("--lab")
        let showsBoard = wantsBoard || wantsLab || !launchedByAgent

        // Không có icon trên Dock khi chỉ chạy nền; khi mở cửa sổ thì thành app thường
        // để macOS cho phép đưa cửa sổ ra trước.
        NSApp.setActivationPolicy(showsBoard ? .regular : .accessory)

        // Bản cài bằng DMG: lần đầu mở thì tự đăng ký chạy khi đăng nhập.
        if !launchedByAgent {
            LoginItem.installIfNeededForInstalledApp()
        }

        // Mở từ Launchpad/Finder thì hiện luôn bàn phím. Agent nền thì im lặng.
        if showsBoard {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                BoardWindowController.shared.show(model: AppModel.shared)
            }
            if wantsLab {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    AppModel.shared.isShowingLab = true
                }
            }
            // Lần hai sau khi app đã ổn định: macOS hay trì hoãn việc activate app mới.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                BoardWindowController.shared.show(model: AppModel.shared)
            }
        }
    }

    /// Bấm lại icon app khi nó đang chạy (Launchpad/Finder) → hiện bàn phím.
    func applicationShouldHandleReopen(_ sender: NSApplication,
                                       hasVisibleWindows flag: Bool) -> Bool {
        BoardWindowController.shared.show(model: AppModel.shared)
        return true
    }

    /// `open "mackey68://board"` hoạt động cả khi app đã chạy sẵn.
    /// `mackey68://import?url=https://…` tải và nhập một profile được chia sẻ.
    func application(_ application: NSApplication, open urls: [URL]) {
        guard let link = urls.first(where: { $0.scheme?.lowercased() == "mackey68" }) else {
            return
        }

        if link.host?.lowercased() == "import" {
            importProfile(from: link)
            return
        }

        if link.host?.lowercased() == "lab" {
            let model = AppModel.shared
            BoardWindowController.shared.show(model: model)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                model.isShowingLab = true
            }
            return
        }

        // Chờ app khởi động xong rồi mới đưa cửa sổ ra trước.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            BoardWindowController.shared.show(model: AppModel.shared)
        }
    }

    private func importProfile(from link: URL) {
        let model = AppModel.shared
        BoardWindowController.shared.show(model: model)

        let components = URLComponents(url: link, resolvingAgainstBaseURL: false)
        let target = components?.queryItems?.first { $0.name == "url" }?.value
        guard let target,
              let url = URL(string: target),
              url.scheme?.lowercased() == "https" else {
            presentImportError("Link phải có dạng mackey68://import?url=https://…")
            return
        }

        URLSession.shared.dataTask(with: url) { data, _, error in
            DispatchQueue.main.async {
                if let error {
                    self.presentImportError(error.localizedDescription)
                    return
                }
                guard let data else {
                    self.presentImportError("Không tải được file profile.")
                    return
                }
                do {
                    _ = try model.importProfile(data: data)
                } catch {
                    self.presentImportError(error.localizedDescription)
                }
            }
        }.resume()
    }

    private func presentImportError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "MacKey68"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

@main
struct MacKey68App: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var model = AppModel.shared

    var body: some Scene {
        MenuBarExtra {
            MenuContent(model: model)
        } label: {
            Image(systemName: "keyboard")
        }
        .menuBarExtraStyle(.menu)
    }
}

struct MenuContent: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Text(model.statusText)

        Divider()

        Picker(model.t("Hồ sơ", "Profile"), selection: Binding(
            get: { model.activeProfileID },
            set: { model.selectProfile($0) }
        )) {
            ForEach(model.config.allProfiles) { profile in
                Text(profile.name).tag(profile.id)
            }
        }

        Toggle(model.t("Bật remap", "Enable remap"), isOn: $model.enabled)
        Toggle(model.t("Tự chạy khi đăng nhập", "Launch at login"),
               isOn: $model.launchesAtLogin)

        Picker(model.t("Ngôn ngữ", "Language"), selection: Binding(
            get: { model.language },
            set: { model.setLanguage($0) }
        )) {
            ForEach(Language.allCases) { language in
                Text(language.menuLabel).tag(language)
            }
        }

        Divider()

        Button(model.t("Mở bàn phím…", "Open keyboard…")) {
            BoardWindowController.shared.show(model: model)
        }
        Button(model.t("Hướng dẫn…", "Guide…")) {
            BoardWindowController.shared.show(model: model)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                model.openGuide()
            }
        }
        Button(model.t("Áp dụng lại", "Reapply")) { model.apply() }
        Button(model.t("Kiểm tra cập nhật…", "Check for Updates…")) {
            Updater.checkForUpdates()
        }
        Button(model.t("Giới thiệu MacKey68…", "About MacKey68…")) {
            showAbout()
        }

        Divider()

        Button(model.t("Thoát MacKey68", "Quit MacKey68")) { NSApp.terminate(nil) }
    }

    private func showAbout() {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let alert = NSAlert()
        alert.messageText = "MacKey68 \(version)"
        alert.informativeText = model.t(
            """
            Công cụ remap bàn phím mã nguồn mở cho macOS.
            Không liên kết, không được bảo trợ bởi Logitech, Razer, Apple, Ziyoulang, \
            Keychron, Akko, FL-Esports hay bất kỳ hãng bàn phím nào. Tên sản phẩm và \
            thương hiệu thuộc về chủ sở hữu tương ứng và chỉ được dùng để mô tả khả năng \
            tương thích.

            Giấy phép GPL-3.0-or-later. Không có bảo hành.
            """,
            """
            Open-source keyboard remapper for macOS.
            Not affiliated with, endorsed by, or sponsored by Logitech, Razer, Apple, \
            Ziyoulang, Keychron, Akko, FL-Esports or any other keyboard vendor. Product \
            names and trademarks belong to their respective owners and are used only to \
            describe compatibility.

            GPL-3.0-or-later. No warranty.
            """
        )
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
