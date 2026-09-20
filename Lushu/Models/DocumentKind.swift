import Foundation

/// 文书类型扩展点。`summary` / `customReport` 共用撰稿对话。起诉状 / 答辩状仅占位，不另做第二套用法。
enum DocumentKind: String, CaseIterable, Identifiable, Codable, Hashable {
    case summary
    case customReport
    case complaint
    case answer

    var id: String { rawValue }

    var title: String {
        switch self {
        case .summary: return "材料总结"
        case .customReport: return "专项报告"
        case .complaint: return "起诉状"
        case .answer: return "答辩状"
        }
    }

    var latin: String {
        switch self {
        case .summary: return "SUMMARY"
        case .customReport: return "REPORT"
        case .complaint: return "COMPLAINT"
        case .answer: return "ANSWER"
        }
    }

    var subtitle: String {
        switch self {
        case .summary: return "清单、要点、时间线、争议与待办。可按任务卡组稿。"
        case .customReport: return "长要点驱动的专项报告。章节来自任务卡，只填结构化材料。"
        case .complaint: return "后续模板。界面已预留，生稿未开放。"
        case .answer: return "后续模板。界面已预留，生稿未开放。"
        }
    }

    var isAvailable: Bool {
        switch self {
        case .summary, .customReport: return true
        case .complaint, .answer: return false
        }
    }

    var symbolName: String {
        switch self {
        case .summary: return "doc.text"
        case .customReport: return "doc.plaintext"
        case .complaint: return "doc.badge.plus"
        case .answer: return "doc.badge.ellipsis"
        }
    }
}
