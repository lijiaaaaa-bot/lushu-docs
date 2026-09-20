import Foundation

/// 从职工停车信息表「汇总」页读取已填金额。空月不补，不估数。
struct ParkingYearLedger: Hashable {
    var year: Int
    var filename: String
    var yearTotal: Decimal?
    var monthAmounts: [(label: String, amount: Decimal)]
    var reportedAmount: Decimal?
    var note: String

    static func == (lhs: ParkingYearLedger, rhs: ParkingYearLedger) -> Bool {
        lhs.year == rhs.year
            && lhs.filename == rhs.filename
            && lhs.yearTotal == rhs.yearTotal
            && lhs.reportedAmount == rhs.reportedAmount
            && lhs.note == rhs.note
            && lhs.monthAmounts.map(\.label) == rhs.monthAmounts.map(\.label)
            && lhs.monthAmounts.map(\.amount) == rhs.monthAmounts.map(\.amount)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(year)
        hasher.combine(filename)
        hasher.combine(yearTotal)
        hasher.combine(reportedAmount)
        hasher.combine(note)
    }
}

enum ParkingLedgerReader {
    static func read(tables: [StructuredTableRef]) -> [ParkingYearLedger] {
        tables
            .compactMap { table -> ParkingYearLedger? in
                guard let year = BriefCardParser.year(in: table.filename) else { return nil }
                return read(year: year, filename: table.filename, url: table.fileURL)
            }
            .sorted { $0.year < $1.year }
    }

    static func read(year: Int, filename: String, url: URL) -> ParkingYearLedger {
        let rows = OfficeDocument.readXLSXSheetRows(from: url, preferredSheet: "汇总")
        let amountIndex = amountColumnIndex(in: rows)
        let monthIndex = monthColumnIndex(in: rows)

        var yearTotal: Decimal?
        var months: [(String, Decimal)] = []
        for row in rows {
            let month = monthIndex.flatMap { row.indices.contains($0) ? row[$0] : nil } ?? ""
            let amount = amountIndex.flatMap { row.indices.contains($0) ? ReportNumber.decimal(row[$0]) : nil }
            if month.contains("年度合计") {
                yearTotal = amount
                continue
            }
            if month.contains("小计") || month.contains("合计") { continue }
            if let amount, isMonthRow(month) {
                months.append((monthLabel(month, year: year, index: months.count), amount))
            }
        }

        let monthSum: Decimal? = months.isEmpty ? nil : months.map(\.1).reduce(0, +)
        let reported = yearTotal ?? monthSum
        return ParkingYearLedger(
            year: year,
            filename: filename,
            yearTotal: yearTotal,
            monthAmounts: months,
            reportedAmount: reported,
            note: note(year: year, yearTotal: yearTotal, months: months)
        )
    }

    private static func amountColumnIndex(in rows: [[String]]) -> Int? {
        if let header = rows.first(where: { $0.contains(where: { $0 == "金额" || $0.contains("金额") }) }) {
            if let exact = header.firstIndex(of: "金额") { return exact }
            return header.firstIndex(where: { $0.contains("金额") && !$0.contains("电费") && !$0.contains("管理") })
        }
        return 2
    }

    private static func monthColumnIndex(in rows: [[String]]) -> Int? {
        if let header = rows.first(where: { $0.contains(where: { $0.contains("月份") }) }) {
            return header.firstIndex(where: { $0.contains("月份") })
        }
        return 1
    }

    private static func isMonthRow(_ month: String) -> Bool {
        if month.isEmpty { return false }
        if month.contains("小计") || month.contains("合计") { return false }
        if month.contains("年") && month.contains("月") { return true }
        if Decimal(string: month) != nil { return true }
        return false
    }

    private static func monthLabel(_ raw: String, year: Int, index: Int) -> String {
        if raw.contains("月") { return raw }
        if let serial = Double(raw), serial > 40000 {
            return "\(year)年\(index + 1)月"
        }
        return raw
    }

    private static func note(year: Int, yearTotal: Decimal?, months: [(String, Decimal)]) -> String {
        if let yearTotal, year < 2026 {
            if year == 2022, months.count == 11 {
                return "\(year)年2月至12月（2022年1月无停车记录）"
            }
            return "\(year)年1月至12月"
        }
        if yearTotal == nil, !months.isEmpty {
            if year == 2026, months.count == 7 {
                return "2026年1月至7月（8月起数据待确认）"
            }
            return "\(year)年1月至\(months.count)月"
        }
        if yearTotal == nil, months.isEmpty {
            return "\(year)年金额待确认"
        }
        return "\(year)年"
    }
}

enum ReportNumber {
    static func decimal(_ raw: String) -> Decimal? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "，", with: "")
            .replacingOccurrences(of: "元", with: "")
        if trimmed.isEmpty { return nil }
        if let value = Decimal(string: trimmed) { return value }
        if let value = Double(trimmed), value.isFinite {
            return Decimal(value)
        }
        return nil
    }

    static func money(_ value: Decimal, decimals: Int = 2) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = decimals
        formatter.maximumFractionDigits = decimals
        formatter.groupingSeparator = ","
        return formatter.string(from: value as NSDecimalNumber) ?? "\(value)"
    }

    static func plain(_ value: Decimal, decimals: Int = 2) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = decimals
        formatter.usesGroupingSeparator = false
        return formatter.string(from: value as NSDecimalNumber) ?? "\(value)"
    }
}
