import Foundation

/// 文书类型扩展点。当前仅 `summary` 可用；起诉状 / 答辩状占位，后续同一仓库演进。
enum DocumentKind: String, CaseIterable, Identifiable, Codable, Hashable {
    case summary
    case complaint
    case answer

    var id: String { rawValue }

    var title: String {
        switch self {
        case .summary: return "材料总结"
        case .complaint: return "起诉状"
        case .answer: return "答辩状"
        }
    }

    var latin: String {
        switch self {
        case .summary: return "SUMMARY"
        case .complaint: return "COMPLAINT"
        case .answer: return "ANSWER"
        }
    }

    var subtitle: String {
        switch self {
        case .summary: return "清单、要点、时间线、争议与待办。本轮可撰稿。"
        case .complaint: return "后续模板。界面已预留，生稿未开放。"
        case .answer: return "后续模板。界面已预留，生稿未开放。"
        }
    }

    var isAvailable: Bool { self == .summary }

    var symbolName: String {
        switch self {
        case .summary: return "doc.text"
        case .complaint: return "doc.badge.plus"
        case .answer: return "doc.badge.ellipsis"
        }
    }
}
