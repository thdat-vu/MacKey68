// SPDX-License-Identifier: GPL-3.0-or-later
import SwiftUI
import MacKeyKit

struct LayerEditorView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    let layerID: String

    private var layer: Layer? {
        model.layers.first { $0.id == layerID }
    }

    private var keyChoices: [String] {
        KeyCodes.allNames
            .filter { MacKeyCodes.code(for: $0) != nil }
            .sorted()
    }

    private var unmappedChoices: [String] {
        guard let layer else { return keyChoices }
        let used = Set(layer.mappings.compactMap { KeyCodes.code(for: $0.from) })
        return keyChoices.filter {
            guard let code = KeyCodes.code(for: $0) else { return false }
            return !used.contains(code)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
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
                    Text(layer?.name ?? model.t("Layer", "Layer"))
                        .font(.title3.weight(.semibold))
                    Text(model.t("Chỉnh trigger và mapping của layer.",
                                 "Edit the layer trigger and mappings."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(model.t("Khôi phục mặc định", "Reset to default")) {
                    model.resetLayer(id: layerID)
                }
                .disabled(layer == nil)
            }

            Divider()

            if let layer {
                HStack(spacing: 10) {
                    Text(model.t("Giữ phím", "Hold key"))
                        .font(.callout)
                    Menu {
                        ForEach(keyChoices, id: \.self) { name in
                            Button(name) {
                                model.updateLayerTrigger(id: layerID, trigger: name)
                            }
                        }
                    } label: {
                        Text(layer.trigger)
                            .font(.system(.callout, design: .monospaced))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.primary.opacity(0.08)))
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()

                    Spacer()

                    Menu {
                        ForEach(unmappedChoices, id: \.self) { name in
                            Button(name) {
                                model.addLayerMapping(id: layerID, source: name)
                            }
                        }
                    } label: {
                        Label(model.t("Thêm phím", "Add key"), systemImage: "plus")
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .disabled(unmappedChoices.isEmpty)
                }

                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(layer.mappings, id: \.from) { mapping in
                            HStack(spacing: 10) {
                                Text(mapping.from)
                                    .font(.system(.callout, design: .monospaced))
                                    .frame(width: 150, alignment: .leading)

                                Image(systemName: "arrow.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Menu {
                                    ForEach(keyChoices, id: \.self) { name in
                                        Button(name) {
                                            model.setLayerMapping(id: layerID,
                                                                  source: mapping.from,
                                                                  target: name)
                                        }
                                    }
                                } label: {
                                    Text(mapping.to)
                                        .font(.system(.callout, design: .monospaced))
                                        .foregroundStyle(Color.accentColor)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(Capsule().fill(Color.accentColor.opacity(0.12)))
                                }
                                .menuStyle(.borderlessButton)
                                .fixedSize()

                                Spacer()

                                Button {
                                    model.removeLayerMapping(id: layerID, source: mapping.from)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                                .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.primary.opacity(0.04)))
                        }
                    }
                }

                Text(model.t(
                    "Khi layer bật, trigger chỉ dùng để giữ layer; mapping hidutil của trigger tạm dừng. Các phím không có trong danh sách vẫn hoạt động bình thường.",
                    "While the layer is on, the trigger only holds the layer; its hidutil remap is paused. Keys not listed here keep working normally."
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(model.t("Layer không còn tồn tại.", "This layer no longer exists."))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
            HStack {
                Spacer()
                Button(model.t("Đóng", "Close")) { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(22)
        .frame(width: 680, height: 560)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
