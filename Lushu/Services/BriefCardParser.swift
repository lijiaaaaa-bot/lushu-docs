import Foundation

/// 把长要点收成 BriefCard。只抽用户已写明的字段，不补数字、不补法条。
enum BriefCardParser {
    static func parse(_ raw: String, caseID: UUID, existing: BriefCard? = nil) -> BriefCard {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        var card = existing ?? BriefCard(caseID: caseID)
        card.caseID = caseID
        card.sourceMessage = text
        card.updatedAt = Date()
        if text.isEmpty { return card }

        card.stance = stance(in: text)
        card.documentPurpose = purpose(in: text)
        card.requiredSections = sections(in: text)
        card.calculationRules = rules(in: text)
        card.yearsScope = years(in: text)
        card.extraConstraints = constraints(in: text)
        card.missingFacts = missingFacts(in: text)
        return card
    }

    static func acknowledge(_ card: BriefCard, inputs: StructuredCaseInputs? = nil) -> String {
        var lines: [String] = [
            "已更新本案件任务卡（不是通用问答）。",
            "立场：\(card.stance.title)。",
            "目的：\(card.documentPurpose.isEmpty ? "未写明" : card.documentPurpose)。",
            "年份/范围：\(card.yearsScope.isEmpty ? "未写明" : card.yearsScope)。"
        ]
        if !card.requiredSections.isEmpty {
            lines.append("章节：\(card.requiredSections.joined(separator: "、"))。")
        }
        if !card.calculationRules.isEmpty {
            lines.append("计算口径只采用你写下的规则，律书不另推公式。")
        }
        var gaps = card.missingFacts
        if let inputs {
            gaps.append(contentsOf: yearGaps(requested: card.yearsScope, tables: inputs.tables))
        }
        gaps = unique(gaps)
        if gaps.isEmpty {
            lines.append("任务卡未点名缺数。生成时仍只填结构化材料里已有的原文/真表，缺则列缺口。")
        } else {
            lines.append("已登记缺口（不得编造）：\(gaps.joined(separator: "、"))。")
        }
        lines.append("点「生成文书」将按任务卡组装章节；不会写入未校验法条，也不会估 电价P 或台账金额。")
        return lines.joined(separator: "\n")
    }

    static func yearGaps(requested: String, tables: [StructuredTableRef]) -> [String] {
        let wanted = parseYearList(requested)
        guard !wanted.isEmpty else { return [] }
        let have = Set(tables.compactMap { year(in: $0.filename) })
        return wanted.filter { !have.contains($0) }.map { "\($0)年停车信息表" }
    }

    static func years(in text: String) -> String {
        let values = parseYearList(text)
        guard let first = values.first, let last = values.last else { return "" }
        if first == last { return "\(first)年" }
        return "\(first)–\(last)"
    }

    static func parseYearList(_ text: String) -> [Int] {
        let regex = try? NSRegularExpression(pattern: #"20\d{2}"#)
        let ns = NSRange(text.startIndex..<text.endIndex, in: text)
        var years = Set<Int>()
        regex?.enumerateMatches(in: text, range: ns) { match, _, _ in
            guard let match, let range = Range(match.range, in: text), let year = Int(text[range]) else { return }
            years.insert(year)
        }
        if let rangeMatch = text.range(of: #"20\d{2}\s*[—–\-至到]\s*20\d{2}"#, options: .regularExpression) {
            let token = String(text[rangeMatch])
            let bounds = isolatedYears(in: token)
            if bounds.count >= 2, let lo = bounds.min(), let hi = bounds.max(), hi >= lo, hi - lo <= 20 {
                years.formUnion(lo...hi)
            }
        }
        return years.sorted()
    }

    private static func isolatedYears(in text: String) -> [Int] {
        let regex = try? NSRegularExpression(pattern: #"20\d{2}"#)
        let ns = NSRange(text.startIndex..<text.endIndex, in: text)
        var years: [Int] = []
        regex?.enumerateMatches(in: text, range: ns) { match, _, _ in
            guard let match, let range = Range(match.range, in: text), let year = Int(text[range]) else { return }
            years.append(year)
        }
        return years
    }

    static func year(in filename: String) -> Int? {
        parseYearList(filename).first
    }

    private static func stance(in text: String) -> BriefStance {
        if text.contains("乙方") { return .defendant }
        if text.contains("甲方") { return .plaintiff }
        if text.contains("中立") { return .neutral }
        return .neutral
    }

    private static func purpose(in text: String) -> String {
        if let labeled = labeledBlock(in: text, headings: ["文书目的", "目的"]) {
            return firstSentence(labeled)
        }
        if text.contains("专项报告") { return "停车场费用专项报告" }
        if text.contains("材料总结") { return "材料总结" }
        if text.contains("报告") { return "费用报告" }
        return "材料总结"
    }

    private static func sections(in text: String) -> [String] {
        if let block = labeledBlock(in: text, headings: ["请包含以下部分", "请包含", "章节"]) {
            let items = listItems(in: block)
            if !items.isEmpty { return items }
        }
        var found: [String] = []
        let candidates = ["立场与范围", "停车费", "照明用电测算", "计算口径", "待补材料", "案件概要", "事实要点"]
        for item in candidates where text.contains(item) {
            found.append(item)
        }
        return unique(found)
    }

    private static func rules(in text: String) -> [String] {
        if let block = labeledBlock(in: text, headings: ["计算规则", "计算口径"]) {
            let items = listItems(in: block)
            if !items.isEmpty { return items }
        }
        return []
    }

    private static func constraints(in text: String) -> [String] {
        if let block = labeledBlock(in: text, headings: ["额外约束", "约束"]) {
            let items = listItems(in: block)
            if !items.isEmpty { return items }
        }
        return []
    }

    private static func missingFacts(in text: String) -> [String] {
        var gaps: [String] = []
        let mentionsPrice = text.contains("电价") || text.contains("电价P") || text.contains("P×") || text.contains("P ×")
        let mentionsCount = text.contains("全场灯数") || text.contains("灯数N") || text.contains("灯数 N")
        let priceGiven = statedNumber(in: text, labels: ["电价P", "电价"]) != nil
        let countGiven = statedNumber(in: text, labels: ["全场灯数N", "全场灯数", "灯数N"]) != nil
        let missingCue = text.contains("没有") || text.contains("未给") || text.contains("缺") || text.contains("未知")

        if mentionsPrice && (!priceGiven || missingCue && text.contains("电价")) {
            if !priceGiven { gaps.append("电价P") }
        }
        if mentionsCount && (!countGiven || missingCue && (text.contains("灯数") || text.contains("全场"))) {
            if !countGiven { gaps.append("全场灯数N") }
        }
        if text.contains("合同.pdf") && (text.contains("未入库") || text.contains("未读")) {
            gaps.append("合同.pdf")
        }
        if text.contains("审计") && (text.contains("未入库") || text.contains("未读")) {
            gaps.append("审计件")
        }
        return unique(gaps)
    }

    static func statedNumber(in text: String, labels: [String]) -> String? {
        for label in labels {
            let pattern = NSRegularExpression.escapedPattern(for: label) + #"\s*[=:：为是]?\s*(\d+(?:\.\d+)?)"#
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..<text.endIndex, in: text)),
               let range = Range(match.range(at: 1), in: text) {
                return String(text[range])
            }
        }
        return nil
    }

    private static func labeledBlock(in text: String, headings: [String]) -> String? {
        for heading in headings {
            guard let start = text.range(of: heading) else { continue }
            let rest = text[start.upperBound...]
            let nextHead = rest.range(of: #"\n[^\n]{2,12}[：:]"#, options: .regularExpression)
            let block = nextHead.map { String(rest[..<$0.lowerBound]) } ?? String(rest)
            let trimmed = block.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        return nil
    }

    private static func listItems(in block: String) -> [String] {
        block.components(separatedBy: .newlines)
            .map { line in
                var item = line.trimmingCharacters(in: .whitespacesAndNewlines)
                item = item.replacingOccurrences(of: #"^[\-\*\d\.、）)\s]+"#, with: "", options: .regularExpression)
                return item
            }
            .filter { $0.count >= 2 && $0.count < 80 }
    }

    private static func firstSentence(_ text: String) -> String {
        let line = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty && $0 != "：" && $0 != ":" }
            ?? text
        return String(line.prefix(80))
            .trimmingCharacters(in: CharacterSet(charactersIn: "：: "))
    }

    private static func unique(_ items: [String]) -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        for item in items where seen.insert(item).inserted {
            out.append(item)
        }
        return out
    }
}
