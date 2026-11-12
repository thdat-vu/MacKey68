// SPDX-License-Identifier: GPL-3.0-or-later
import SwiftUI

/// Popup hướng dẫn 4 bước, hiện lần đầu mở cửa sổ bàn phím và mở lại được từ menu.
struct GuideView: View {
    @EnvironmentObject private var model: AppModel
    @State private var step = 0

    private struct Page {
        let icon: String
        let title: String
        let intro: String
        let bullets: [(String, String)]
    }

    private var pages: [Page] {
        [
            Page(
                icon: "keyboard",
                title: model.t("MacKey68 hoạt động thế nào?",
                               "How MacKey68 works"),
                intro: model.t("Một app nhỏ sống ở menu bar, remap bàn phím ngay trong macOS.",
                               "A small menu-bar app that remaps your keyboard inside macOS."),
                bullets: [
                    ("menubar.rectangle",
                     model.t("App không có cửa sổ chính; mọi thứ nằm ở icon bàn phím trên menu bar.",
                             "There is no main window; everything lives under the keyboard icon in the menu bar.")),
                    ("cpu",
                     model.t("Remap bằng hidutil ở tầng hệ điều hành — không cần phần mềm của hãng.",
                             "Remapping uses hidutil at the OS level — no vendor software needed.")),
                    ("checkmark.circle",
                     model.t("Thay đổi được lưu tự động và áp lại khi cắm lại bàn phím.",
                             "Changes are saved automatically and reapplied when a keyboard is reconnected.")),
                ]
            ),
            Page(
                icon: "cursorarrow.click",
                title: model.t("Đổi chức năng một phím", "Remap a key"),
                intro: model.t("Phím nào cũng đổi được, trừ Fn do firmware giữ.",
                               "Any key can be changed, except Fn which firmware owns."),
                bullets: [
                    ("hand.tap",
                     model.t("Bấm một phím trên hình để chọn, rồi chọn phím đích trong danh sách.",
                             "Click a key on the drawing, then pick the target key from the list.")),
                    ("paintbrush",
                     model.t("Phím đã đổi được tô xanh và vẫn giữ nhãn gốc ở góc để không bị lẫn.",
                             "Remapped keys are highlighted and keep their original label in the corner.")),
                    ("arrow.uturn.backward",
                     model.t("Nút Bỏ đổi trả phím về mặc định; Đóng để bỏ chọn.",
                             "Reset restores the default; Close clears the selection.")),
                    ("exclamationmark.triangle",
                     model.t("hidutil chỉ map phím → phím. Cần Cmd+phím hoặc macro thì dùng Karabiner-Elements.",
                             "hidutil only maps key → key. For Cmd+key or macros, use Karabiner-Elements.")),
                    ("waveform.path.ecg",
                     model.t("Test phím: bấm phím thật để chọn, xem tín hiệu và phát hiện chatter.",
                             "Key Test: press a real key to select it, inspect reports and catch chatter.")),
                ]
            ),
            Page(
                icon: "app.badge",
                title: model.t("Tự đổi profile theo app", "Per-app profiles"),
                intro: model.t("Hai profile mặc định: macOS và League of Legends.",
                               "Two default profiles: macOS and League of Legends."),
                bullets: [
                    ("command",
                     model.t("macOS: phím trái Space là ⌘, Caps Lock giữ nguyên để gõ chữ hoa.",
                             "macOS: the key left of Space is ⌘, Caps Lock stays normal for typing.")),
                    ("gamecontroller",
                     model.t("League of Legends: phím đó thành ⌥, Caps thành ` để khóa tướng.",
                             "League of Legends: that key becomes ⌥, Caps becomes ` for locking the camera.")),
                    ("plus.circle",
                     model.t("Bấm + TênApp để gắn profile với app vừa dùng; mở app đó là tự đổi.",
                             "Click + AppName to link the profile to the last used app; opening it switches automatically.")),
                    ("xmark.circle",
                     model.t("Bấm × cạnh tên app để bỏ gắn; profile không gắn app là mặc định.",
                             "Click × next to an app to unlink; a profile with no apps is the fallback.")),
                ]
            ),
            Page(
                icon: "rectangle.split.3x1",
                title: model.t("Nhiều bàn phím, nhiều layout",
                               "Keyboards and layouts"),
                intro: model.t("68 phím, TKL và full-size đều vẽ được.",
                               "68-key, TKL and full-size boards are all supported."),
                bullets: [
                    ("keyboard.badge.ellipsis",
                     model.t("Chọn bàn phím ở ô Bàn phím; nút ↻ dò lại sau khi cắm/rút.",
                             "Pick a board in the Keyboard field; click ↻ to rescan after plugging one in.")),
                    ("rectangle.3.group",
                     model.t("Layout 68 / TKL / Full đổi hình vẽ; lựa chọn lưu riêng cho từng bàn phím.",
                             "The Layout picker (68 / TKL / Full) changes the drawing and is saved per keyboard.")),
                    ("sparkles",
                     model.t("Edra EK387 Pro (SONiX) được nhận diện là TKL. Đoán sai thì đổi Layout một lần.",
                             "The Edra EK387 Pro (SONiX) is detected as TKL. If a board is guessed wrong, change Layout once.")),
                    ("questionmark.circle",
                     model.t("Mở lại hướng dẫn này bất cứ lúc nào từ menu bar → Hướng dẫn…",
                             "Reopen this guide anytime from the menu bar → Guide…")),
                ]
            ),
        ]
    }

    private var page: Page { pages[min(step, pages.count - 1)] }
    private var isLast: Bool { step >= pages.count - 1 }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            Divider()
            content
            Spacer(minLength: 0)
            footer
        }
        .padding(24)
        .frame(width: 620, height: 430)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.accentColor.opacity(0.14))
                    .frame(width: 46, height: 46)
                Image(systemName: page.icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(page.title)
                    .font(.title2.weight(.semibold))
                Text(page.intro)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Text("\(step + 1) / \(pages.count)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.primary.opacity(0.06)))
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(page.bullets.enumerated()), id: \.offset) { _, bullet in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: bullet.0)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 20)
                        .padding(.top, 1)
                    Text(bullet.1)
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.vertical, 2)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Button(model.t("Đóng", "Close")) { model.markGuideSeen() }
                .keyboardShortcut(.cancelAction)

            Spacer()

            HStack(spacing: 6) {
                ForEach(0..<pages.count, id: \.self) { index in
                    Circle()
                        .fill(index == step ? Color.accentColor : Color.secondary.opacity(0.25))
                        .frame(width: 7, height: 7)
                }
            }

            Spacer()

            if step > 0 {
                Button(model.t("Trước", "Back")) { step -= 1 }
            }

            if isLast {
                Button(model.t("Bắt đầu dùng", "Start using")) { model.markGuideSeen() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            } else {
                Button(model.t("Tiếp", "Next")) { step += 1 }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}
