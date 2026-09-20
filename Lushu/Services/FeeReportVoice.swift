import Foundation

/// 测算报告只保留律师会寄给医院的函件正文。系统/产品口吻一律剔除。
enum FeeReportVoice {
    static let bannedPhrases = [
        "任务卡", "结构化", "本地组装", "已锁定", "未入库", "不编造", "不假装",
        "已粘贴", "转写", "汇总页", "不编行", "已写明", "DeepSeek", "润色稿",
        "抬头与背景", "测算步骤：", "本稿", "案件包", "委托对照范围",
        "未接模型", "仅转写", "有则用之"
    ]

    static func containsBanned(_ text: String) -> [String] {
        bannedPhrases.filter { text.contains($0) }
    }

    static func sanitize(_ text: String, dropMarkdownHeadings: Bool = false) -> String {
        let dropIfContains = ["测算步骤：", "小时用电量（千瓦）"]
        let lines = text.components(separatedBy: .newlines).compactMap { line -> String? in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if dropMarkdownHeadings, trimmed.hasPrefix("#") { return nil }
            if dropIfContains.contains(where: { trimmed.contains($0) }) { return nil }
            return line
        }
        var joined = lines.joined(separator: "\n")
        for phrase in bannedPhrases {
            joined = joined.replacingOccurrences(of: phrase, with: "")
        }
        while joined.contains("  ") {
            joined = joined.replacingOccurrences(of: "  ", with: " ")
        }
        return joined
            .replacingOccurrences(of: "（）", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func letterDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月d日"
        return formatter.string(from: date)
    }
}
