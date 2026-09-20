import Foundation

struct LightingZone: Hashable {
    var name: String
    var lampCount: Int?
    var installReading: Decimal?
    var copyReading: Decimal?
    var kWh: Decimal?
    var watts: Decimal?
}

enum LightingMeasurementParser {
    static func zones(in text: String) -> [LightingZone] {
        let blocks = text.components(separatedBy: "后勤保障部确认签字")
        var zones: [LightingZone] = []
        for block in blocks {
            guard let name = firstMatch(#"(负[一二]层[^\n]{0,20}电[房费][^\n]{0,12})"#, in: block)
                    ?? firstMatch(#"(负[一二]层[^\n]{2,24})"#, in: block)
            else { continue }
            let lamps = intMatch(#"(\d+)\s*个灯"#, in: block)
            let watts = decimalMatch(#"每个灯\s*(\d+(?:\.\d+)?)\s*瓦"#, in: block)
                ?? decimalMatch(#"故每个灯\s*(\d+(?:\.\d+)?)\s*瓦"#, in: block)
            let kWh = decimalMatch(#"用电合计\s*(\d+(?:\.\d+)?)\s*度"#, in: block)
            let install = decimalMatch(#"安装表度数\s*(\d+(?:\.\d+)?)"#, in: block)
            let copy = decimalMatch(#"抄表度数\s*(\d+(?:\.\d+)?)"#, in: block)
            if lamps == nil && watts == nil && kWh == nil { continue }
            zones.append(
                LightingZone(
                    name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                    lampCount: lamps,
                    installReading: install,
                    copyReading: copy,
                    kWh: kWh,
                    watts: watts
                )
            )
        }
        return zones
    }

    static func averageWatts(of zones: [LightingZone]) -> Decimal? {
        let values = zones.compactMap(\.watts)
        guard !values.isEmpty else { return nil }
        var raw = values.reduce(0, +) / Decimal(values.count)
        var rounded = Decimal()
        NSDecimalRound(&rounded, &raw, 2, .plain)
        return rounded
    }

    private static func firstMatch(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..<text.endIndex, in: text)),
              let range = Range(match.range(at: 1), in: text)
        else { return nil }
        return String(text[range])
    }

    private static func intMatch(_ pattern: String, in text: String) -> Int? {
        firstMatch(pattern, in: text).flatMap(Int.init)
    }

    private static func decimalMatch(_ pattern: String, in text: String) -> Decimal? {
        firstMatch(pattern, in: text).flatMap(ReportNumber.decimal)
    }
}

enum BriefFacts {
    static func addressee(in text: String) -> String? {
        if let labeled = firstMatch(#"致\s*([^\n，。]{2,20})"#, in: text) {
            return labeled.replacingOccurrences(of: "：", with: "").trimmingCharacters(in: .whitespaces)
        }
        if text.contains("河南省人民医院") { return "河南省人民医院" }
        return nil
    }

    static func reportTitle(in text: String, fallback: String) -> String {
        if let titled = firstMatch(#"(关于[^《\n]{8,40}报告)"#, in: text) {
            return titled
        }
        return fallback
    }

    static func contractClauses(in text: String) -> [String] {
        var items: [String] = []
        let pattern = try? NSRegularExpression(pattern: #"《合同》第[^。\n]{2,80}。"#)
        let ns = NSRange(text.startIndex..<text.endIndex, in: text)
        pattern?.enumerateMatches(in: text, range: ns) { match, _, _ in
            guard let match, let range = Range(match.range, in: text) else { return }
            items.append(String(text[range]))
        }
        return items
    }

    static func referencePrice(in text: String) -> Decimal? {
        if let labeled = BriefCardParser.statedNumber(in: text, labels: ["参考电价P", "参考电价", "电价P", "电价"]) {
            return ReportNumber.decimal(labeled)
        }
        return decimalMatch(#"P\s*[=＝:：为是]\s*(\d+(?:\.\d+)?)"#, in: text)
    }

    static func lampCounts(in text: String) -> (b1: Int?, b2: Int?, total: Int?) {
        let b1 = intMatch(#"负一层[^\n]{0,12}?(\d+)\s*个"#, in: text)
        let b2 = intMatch(#"负二层[^\n]{0,12}?(\d+)\s*个"#, in: text)
        let total = intMatch(#"全场灯数N\s*[=＝:：为是]?\s*(\d+)"#, in: text)
            ?? intMatch(#"两层照明灯共计\s*(\d+)"#, in: text)
            ?? intMatch(#"灯共计\s*(\d+)"#, in: text)
        let summed = (b1 != nil && b2 != nil) ? (b1! + b2!) : nil
        return (b1, b2, total ?? summed)
    }

    static func allowsPriorYearEstimate(in text: String) -> Bool {
        (text.contains("2018") || text.contains("2021"))
            && (text.contains("参照") || text.contains("月均摊") || text.contains("按月均") || text.contains("估算"))
    }

    static func electricityPeriods(in text: String) -> [ElectricityPeriod] {
        var periods: [ElectricityPeriod] = []
        let pattern = try? NSRegularExpression(
            pattern: #"(20\d{2}年\d{1,2}月\d{1,2}日)\s*至\s*(20\d{2}年\d{1,2}月\d{1,2}日)(?:[^\n]{0,20}?(\d+)\s*天)?"#
        )
        let ns = NSRange(text.startIndex..<text.endIndex, in: text)
        pattern?.enumerateMatches(in: text, range: ns) { match, _, _ in
            guard let match,
                  let a = Range(match.range(at: 1), in: text),
                  let b = Range(match.range(at: 2), in: text)
            else { return }
            let days: Int?
            if match.range(at: 3).location != NSNotFound, let d = Range(match.range(at: 3), in: text) {
                days = Int(text[d])
            } else {
                days = nil
            }
            periods.append(ElectricityPeriod(startText: String(text[a]), endText: String(text[b]), statedDays: days))
        }
        return periods
    }

    private static func firstMatch(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..<text.endIndex, in: text)),
              let range = Range(match.range(at: 1), in: text)
        else { return nil }
        return String(text[range])
    }

    private static func intMatch(_ pattern: String, in text: String) -> Int? {
        firstMatch(pattern, in: text).flatMap(Int.init)
    }

    private static func decimalMatch(_ pattern: String, in text: String) -> Decimal? {
        firstMatch(pattern, in: text).flatMap(ReportNumber.decimal)
    }
}

struct ElectricityPeriod: Hashable {
    var startText: String
    var endText: String
    var statedDays: Int?
}
