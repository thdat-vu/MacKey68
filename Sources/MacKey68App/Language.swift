import Foundation

/// Ngôn ngữ giao diện. Lưu trong UserDefaults nên nhớ giữa các lần mở.
enum Language: String, CaseIterable, Identifiable {
    case vi
    case en

    var id: String { rawValue }

    var menuLabel: String {
        switch self {
        case .vi: return "Tiếng Việt"
        case .en: return "English"
        }
    }

    var shortLabel: String {
        switch self {
        case .vi: return "VI"
        case .en: return "EN"
        }
    }
}

extension AppModel {
    /// Chọn chuỗi theo ngôn ngữ đang bật: `model.t("Tiếng Việt", "English")`.
    func t(_ vi: String, _ en: String) -> String {
        language == .vi ? vi : en
    }
}
