import SwiftUI
import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        let launchedByAgent = ProcessInfo.processInfo.environment["MACKEY_AGENT"] == "1"
            || CommandLine.arguments.contains("--agent")
        let wantsBoard = CommandLine.arguments.contains("--board")
        let showsBoard = wantsBoard || !launchedByAgent

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
    func application(_ application: NSApplication, open urls: [URL]) {
        guard urls.contains(where: { $0.scheme?.lowercased() == "mackey68" }) else { return }
        // Chờ app khởi động xong rồi mới đưa cửa sổ ra trước.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            BoardWindowController.shared.show(model: AppModel.shared)
        }
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
        Button(model.t("Áp dụng lại", "Reapply")) { model.apply() }

        Divider()

        Button(model.t("Thoát MacKey68", "Quit MacKey68")) { NSApp.terminate(nil) }
    }
}
