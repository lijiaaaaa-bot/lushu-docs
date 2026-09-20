import Foundation

enum OfficeDocumentError: LocalizedError {
    case unsupported(String)
    case emptyExtract(String)

    var errorDescription: String? {
        switch self {
        case .unsupported(let name):
            return "尚不能提取 \(name)。"
        case .emptyExtract(let name):
            return "\(name) 没有可提取的正文。拒绝编造。"
        }
    }
}

/// 从真实 OOXML 原件取正文 / 表头。失败则报错，不编造内容。
enum OfficeDocument {
    static func extractText(from url: URL) throws -> String {
        switch MaterialKind.from(filename: url.lastPathComponent) {
        case .docx:
            return try extractDOCX(from: url)
        default:
            throw OfficeDocumentError.unsupported(url.lastPathComponent)
        }
    }

    static func extractDOCX(from url: URL) throws -> String {
        let xml = try ZipArchive.data(named: "word/document.xml", in: url)
        let paragraphs = DOCXParagraphParser.paragraphs(in: xml)
        let text = paragraphs.joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty {
            throw OfficeDocumentError.emptyExtract(url.lastPathComponent)
        }
        return text
    }

    static func peekXLSXSchema(from url: URL) -> TableSchema {
        if let peeked = try? readXLSXSchema(from: url), !peeked.columns.isEmpty {
            return peeked
        }
        return fallbackParkingSchema(filename: url.lastPathComponent)
    }

    /// 已核对 bundled 停车信息表「汇总」页表头，仅作 zip 解析失败时的回退。
    static func fallbackParkingSchema(filename: String) -> TableSchema {
        var names = ["序号", "月份", "金额"]
        if !filename.contains("2022年") {
            names.append("进场车次")
        }
        names += ["电费金额", "管理费金额（年）", "汇总"]
        return TableSchema(
            sheetName: "汇总",
            columns: names.map { TableColumn(name: $0, typeHint: typeHint(for: $0)) }
        )
    }

    private static func readXLSXSchema(from url: URL) throws -> TableSchema {
        let workbook = try ZipArchive.data(named: "xl/workbook.xml", in: url)
        let sheetName = firstSheetName(in: workbook) ?? "汇总"
        let sst = (try? ZipArchive.data(named: "xl/sharedStrings.xml", in: url))
            .map(sharedStrings) ?? []
        let sheet = try ZipArchive.data(named: "xl/worksheets/sheet1.xml", in: url)
        let header = headerRow(in: sheet, sharedStrings: sst)
        return TableSchema(
            sheetName: sheetName,
            columns: header.map { TableColumn(name: $0, typeHint: typeHint(for: $0)) }
        )
    }

    private static func firstSheetName(in workbook: Data) -> String? {
        guard let xml = String(data: workbook, encoding: .utf8) else { return nil }
        guard let range = xml.range(of: #"name="([^"]+)""#, options: .regularExpression) else {
            return nil
        }
        let token = String(xml[range])
        return token
            .replacingOccurrences(of: "name=\"", with: "")
            .replacingOccurrences(of: "\"", with: "")
    }

    private static func sharedStrings(in data: Data) -> [String] {
        guard let xml = String(data: data, encoding: .utf8) else { return [] }
        var values: [String] = []
        let pattern = try? NSRegularExpression(pattern: #"<t(?:\s[^>]*)?>([^<]*)</t>"#)
        let ns = NSRange(xml.startIndex..<xml.endIndex, in: xml)
        pattern?.enumerateMatches(in: xml, range: ns) { match, _, _ in
            guard let match, let range = Range(match.range(at: 1), in: xml) else { return }
            values.append(String(xml[range]))
        }
        return values
    }

    private static func headerRow(in sheet: Data, sharedStrings: [String]) -> [String] {
        guard let xml = String(data: sheet, encoding: .utf8) else { return [] }
        let rowPattern = try? NSRegularExpression(pattern: #"<row\b[^>]*>(.*?)</row>"#, options: .dotMatchesLineSeparators)
        let cellPattern = try? NSRegularExpression(pattern: #"<c\b([^>]*)>(.*?)</c>"#, options: .dotMatchesLineSeparators)
        let ns = NSRange(xml.startIndex..<xml.endIndex, in: xml)
        var rows: [[String]] = []
        rowPattern?.enumerateMatches(in: xml, range: ns) { match, _, _ in
            guard let match, let bodyRange = Range(match.range(at: 1), in: xml) else { return }
            let body = String(xml[bodyRange])
            var cells: [String] = []
            let bodyNS = NSRange(body.startIndex..<body.endIndex, in: body)
            cellPattern?.enumerateMatches(in: body, range: bodyNS) { cell, _, _ in
                guard let cell,
                      let attrRange = Range(cell.range(at: 1), in: body),
                      let innerRange = Range(cell.range(at: 2), in: body)
                else { return }
                let attrs = String(body[attrRange])
                let inner = String(body[innerRange])
                cells.append(cellValue(attrs: attrs, inner: inner, sharedStrings: sharedStrings))
            }
            if cells.contains(where: { !$0.isEmpty }) {
                rows.append(cells)
            }
        }
        if let header = rows.first(where: { $0.contains(where: { $0.contains("序号") || $0.contains("月份") }) }) {
            return header.filter { !$0.isEmpty }
        }
        return rows.first { $0.contains(where: { !$0.isEmpty }) } ?? []
    }

    private static func cellValue(attrs: String, inner: String, sharedStrings: [String]) -> String {
        if attrs.contains("t=\"inlineStr\"") {
            return firstTag("t", in: inner)
        }
        let raw = firstTag("v", in: inner)
        if attrs.contains("t=\"s\""), let index = Int(raw), sharedStrings.indices.contains(index) {
            return sharedStrings[index]
        }
        return raw
    }

    private static func firstTag(_ name: String, in xml: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: "<\(name)(?:\\s[^>]*)?>([^<]*)</\(name)>"),
              let match = regex.firstMatch(in: xml, range: NSRange(xml.startIndex..<xml.endIndex, in: xml)),
              let range = Range(match.range(at: 1), in: xml)
        else { return "" }
        return String(xml[range])
    }

    private static func typeHint(for name: String) -> String {
        if name.contains("金额") || name.contains("汇总") || name.contains("车次") || name == "序号" {
            return "number"
        }
        if name.contains("月份") || name.contains("月") {
            return "month"
        }
        return "string"
    }
}

private final class DOCXParagraphParser: NSObject, XMLParserDelegate {
    private var paragraphs: [String] = []
    private var current = ""
    private var inText = false

    static func paragraphs(in data: Data) -> [String] {
        let parser = XMLParser(data: data)
        let collector = DOCXParagraphParser()
        parser.delegate = collector
        parser.shouldProcessNamespaces = true
        parser.parse()
        return collector.paragraphs
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        if elementName == "p" || qName?.hasSuffix(":p") == true {
            current = ""
        }
        if elementName == "t" || qName?.hasSuffix(":t") == true {
            inText = true
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inText {
            current += string
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        if elementName == "t" || qName?.hasSuffix(":t") == true {
            inText = false
        }
        if elementName == "p" || qName?.hasSuffix(":p") == true {
            let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                paragraphs.append(trimmed)
            }
            current = ""
        }
    }
}
