// SPDX-License-Identifier: GPL-3.0-or-later
import SwiftUI
import AppKit
import MacKeyKit

struct LayersView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var editingLayer: Layer?
    @State private var editingCombo: Combo?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            Divider()

            if case .denied = model.layerStatus {
                permissionCard
            }

            if case .failed(let message) = model.layerStatus {
                Label(message, systemImage: "exclamationmark.triangle")
                    .font(.callout)
                    .foregroundStyle(.orange)
            }

            HStack {
                Text(model.t("Bật layer khi giữ phím", "Enable hold-to-activate layers"))
                Spacer()
                Button(model.layersEnabled
                       ? model.t("Tắt layer", "Turn layers off")
                       : model.t("Bật layer", "Turn layers on")) {
                    model.setLayersEnabled(!model.layersEnabled)
                }
                .buttonStyle(.borderedProminent)
            }

            Text(model.t(
                "Khi bật, phím kích hoạt (mặc định Caps Lock) chỉ dùng để giữ layer — Caps Lock không còn gõ chữ hoa, và mapping hidutil của phím đó tạm dừng.",
                "While enabled, the trigger key (Caps Lock by default) only activates the layer — Caps Lock no longer types capitals, and its hidutil remap is paused."
            ))
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            layerList
            Spacer(minLength: 0)
            footer
        }
        .padding(22)
        .frame(width: 700, height: 700)
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(item: $editingLayer) { layer in
            LayerEditorView(layerID: layer.id)
                .environmentObject(model)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.accentColor.opacity(0.14))
                    .frame(width: 42, height: 42)
                Image(systemName: "square.3.layers.3d")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(model.t("Layer & combo (beta)", "Layers & combos (beta)"))
                    .font(.title3.weight(.semibold))
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 7, height: 7)
                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if case .denied = model.layerStatus {
                Button(model.t("Thử lại", "Retry")) {
                    model.retryLayers()
                }
            }
        }
    }

    private var layerList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(model.layers) { layer in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Button {
                                model.setLayerEnabled(id: layer.id, enabled: !layer.enabled)
                            } label: {
                                Image(systemName: layer.enabled
                                      ? "checkmark.circle.fill"
                                      : "circle")
                                    .foregroundStyle(layer.enabled ? Color.accentColor : .secondary)
                            }
                            .buttonStyle(.borderless)
                            .help(model.t("Bật/tắt layer này", "Toggle this layer"))

                            VStack(alignment: .leading, spacing: 1) {
                                Text(layer.name).font(.headline)
                                Text(model.t("Giữ \(layer.trigger) · \(layer.mappings.count) phím",
                                             "Hold \(layer.trigger) · \(layer.mappings.count) keys"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button {
                                editingLayer = layer
                            } label: {
                                Label(model.t("Chỉnh", "Edit"), systemImage: "pencil")
                            }
                            .controlSize(.small)
                        }

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 6)],
                                  alignment: .leading, spacing: 4) {
                            ForEach(layer.mappings, id: \.from) { mapping in
                                Text("\(mapping.from) → \(mapping.to)")
                                    .font(.caption.monospaced())
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(Color.primary.opacity(0.06)))
                            }
                        }
                        .padding(.leading, 46)
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.primary.opacity(0.035)))
                }

                Divider()
                combosSection
            }
        }
    }

    private var combosSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Combos").font(.headline)
                Spacer()
                Button(model.combosEnabled
                       ? model.t("Tắt combo", "Turn combos off")
                       : model.t("Bật combo", "Turn combos on")) {
                    model.setCombosEnabled(!model.combosEnabled)
                }
                .controlSize(.small)
                Button {
                    let id = model.addCombo()
                    editingCombo = model.combos.first { $0.id == id }
                } label: {
                    Label(model.t("Thêm combo", "Add combo"), systemImage: "plus")
                }
                .controlSize(.small)
            }

            Text(model.t("Modifier + phím → phím khác. Ví dụ ⌃⌥ + H → LeftArrow.",
                         "Modifier + key → another key. Example ⌃⌥ + H → LeftArrow."))
                .font(.caption)
                .foregroundStyle(.secondary)

            if model.combos.isEmpty {
                Text(model.t("Chưa có combo nào.", "No combos yet."))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            ForEach(model.combos) { combo in
                HStack(spacing: 10) {
                    Button {
                        model.setComboEnabled(id: combo.id, enabled: !combo.enabled)
                    } label: {
                        Image(systemName: combo.enabled ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(combo.enabled ? Color.accentColor : .secondary)
                    }
                    .buttonStyle(.borderless)

                    Text("\(combo.modifierSummary) + \(combo.from)  →  \(combo.to)")
                        .font(.system(.callout, design: .monospaced))
                    Spacer()
                    Button {
                        editingCombo = combo
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .buttonStyle(.borderless)
                    Button {
                        model.deleteCombo(id: combo.id)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(0.04)))
            }
        }
        .padding(.top, 4)
        .sheet(item: $editingCombo) { combo in
            ComboEditorView(comboID: combo.id)
                .environmentObject(model)
        }
    }

    private var permissionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(model.t("Cần quyền Accessibility", "Accessibility permission needed"),
                  systemImage: "lock.shield")
                .font(.headline)
            Text(model.t(
                "Layer dùng event tap để chặn phím khi giữ trigger. Bật MacKey68 trong System Settings → Privacy & Security → Accessibility rồi bấm Thử lại.",
                "Layers use an event tap to intercept keys while the trigger is held. Enable MacKey68 in System Settings → Privacy & Security → Accessibility, then press Retry."
            ))
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            HStack {
                Button(model.t("Mở System Settings", "Open System Settings")) {
                    openAccessibilitySettings()
                }
                Button(model.t("Sao chép đường dẫn app", "Copy app path")) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(Bundle.main.bundlePath, forType: .string)
                }
                Button(model.t("Thử lại", "Retry")) { model.retryLayers() }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color.orange.opacity(0.10)))
    }

    private var footer: some View {
        HStack {
            Button(model.t("Tắt layer", "Turn layers off")) {
                model.setLayersEnabled(false)
            }
            .disabled(!model.layersEnabled)
            Spacer()
            Text(model.t("Chỉ hoạt động khi app đang chạy.",
                         "Only active while the app is running."))
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
            Button(model.t("Đóng", "Close")) { dismiss() }
                .keyboardShortcut(.cancelAction)
        }
    }

    private func openAccessibilitySettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ) else { return }
        NSWorkspace.shared.open(url)
    }

    private var statusText: String {
        switch model.layerStatus {
        case .off:
            return model.t("Đang tắt", "Off")
        case .running:
            return model.t("Đang chạy", "Running")
        case .denied:
            return model.t("Thiếu quyền Accessibility", "Accessibility denied")
        case .failed(let message):
            return model.t("Lỗi: \(message)", "Error: \(message)")
        }
    }

    private var statusColor: Color {
        switch model.layerStatus {
        case .off: return .secondary
        case .running: return .green
        case .denied: return .orange
        case .failed: return .red
        }
    }
}
