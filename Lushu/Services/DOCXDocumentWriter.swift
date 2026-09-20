import Foundation

/// 写出可打开的 OOXML .docx（STORE zip）。首页生成后优先提供此文件，不在对话里展开正文。
/// 管道表写成 `w:tbl`，标题/章节用独立段落，落款右对齐。无模型时同样出真表。
enum DOCXDocumentWriter {
    static func write(_ draft: DraftDocument, to url: URL) throws {
        let entries = packageEntries(draft)
        let zip = ZipStoreWriter.data(from: entries)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try zip.write(to: url, options: .atomic)
    }

    static func documentXML(for draft: DraftDocument) -> String {
        documentXML(draft)
    }

    private static func packageEntries(_ draft: DraftDocument) -> [(String, Data)] {
        [
            ("[Content_Types].xml", Data(contentTypes.utf8)),
            ("_rels/.rels", Data(rootRels.utf8)),
            ("word/_rels/document.xml.rels", Data(documentRels.utf8)),
            ("word/styles.xml", Data(stylesXML.utf8)),
            ("word/document.xml", Data(documentXML(draft).utf8))
        ]
    }

    private static let contentTypes = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
    <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
    <Default Extension="xml" ContentType="application/xml"/>
    <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
    <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
    </Types>
    """

    private static let rootRels = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
    <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
    </Relationships>
    """

    private static let documentRels = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
    <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
    </Relationships>
    """

    private static let stylesXML = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
    <w:style w:type="paragraph" w:default="1" w:styleId="Normal"><w:name w:val="Normal"/></w:style>
    <w:style w:type="paragraph" w:styleId="Title"><w:name w:val="Title"/><w:pPr><w:jc w:val="center"/><w:spacing w:before="240" w:after="200"/></w:pPr><w:rPr><w:b/><w:sz w:val="32"/><w:szCs w:val="32"/></w:rPr></w:style>
    <w:style w:type="paragraph" w:styleId="Heading1"><w:name w:val="heading 1"/><w:pPr><w:outlineLvl w:val="0"/><w:spacing w:before="280" w:after="120"/></w:pPr><w:rPr><w:b/><w:sz w:val="24"/><w:szCs w:val="24"/></w:rPr></w:style>
    <w:style w:type="paragraph" w:styleId="Heading2"><w:name w:val="heading 2"/><w:pPr><w:outlineLvl w:val="1"/><w:spacing w:before="160" w:after="80"/></w:pPr><w:rPr><w:b/><w:sz w:val="21"/><w:szCs w:val="21"/></w:rPr></w:style>
    </w:styles>
    """

    private static func documentXML(_ draft: DraftDocument) -> String {
        var blocks = [titleParagraph(draft.title)]
        if let generatedAt = draft.generatedAt, shouldShowStamp(draft.generatorLabel) {
            blocks.append(metaParagraph("\(draft.generatorLabel) · \(stamp(generatedAt))"))
        }
        for section in draft.sections {
            blocks.append(headingParagraph(section.heading))
            blocks.append(contentsOf: bodyBlocks(section.body, heading: section.heading))
        }
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:body>
        \(blocks.joined())
        </w:body>
        </w:document>
        """
    }

    private static func shouldShowStamp(_ label: String) -> Bool {
        let banned = ["结构化", "任务卡", "本地组装", "未接模型"]
        return !banned.contains(where: { label.contains($0) })
    }

    private static func bodyBlocks(_ body: String, heading: String) -> [String] {
        let lines = body.components(separatedBy: .newlines)
        var blocks: [String] = []
        var index = 0
        var seenSummary = false
        while index < lines.count {
            if isTableRow(lines[index]) {
                var rows: [String] = []
                while index < lines.count && isTableRow(lines[index]) {
                    if !isTableSeparator(lines[index]) {
                        rows.append(lines[index])
                    }
                    index += 1
                }
                if !rows.isEmpty {
                    blocks.append(tableXML(rows))
                }
                continue
            }
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("综上") {
                seenSummary = true
            }
            if isSubheading(trimmed) {
                blocks.append(subheadingParagraph(trimmed))
            } else if isSignatureLine(trimmed, heading: heading, afterSummary: seenSummary) {
                blocks.append(signatureParagraph(trimmed))
            } else {
                blocks.append(paragraph(line))
            }
            index += 1
        }
        return blocks
    }

    static func isTableRow(_ line: String) -> Bool {
        let cells = tableCells(line)
        return cells.count >= 2
    }

    static func tableCells(_ line: String) -> [String] {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.contains("|") else { return [] }
        if isTableSeparator(trimmed) { return [] }
        return trimmed
            .split(separator: "|", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private static func isTableSeparator(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let compact = trimmed.replacingOccurrences(of: "|", with: "")
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
        return compact.isEmpty && trimmed.contains("-")
    }

    private static func isSubheading(_ line: String) -> Bool {
        line.hasPrefix("（一）") || line.hasPrefix("（二）") || line.hasPrefix("（三）")
            || line.hasPrefix("(一)") || line.hasPrefix("(二)")
    }

    private static func isSignatureLine(_ line: String, heading: String, afterSummary: Bool) -> Bool {
        guard !line.isEmpty else { return false }
        let inConclusion = heading.contains("结论") || heading.contains("落款")
        guard inConclusion, afterSummary || line.contains("公司") else { return false }
        if line.contains("公司") { return true }
        if line.hasPrefix("（") && line.hasSuffix("）") && line.count < 48 { return true }
        return false
    }

    private static func tableXML(_ rows: [String]) -> String {
        let parsed = rows.map(tableCells).filter { !$0.isEmpty }
        guard let columns = parsed.map(\.count).max(), columns > 0 else { return "" }
        let width = max(1200, 9000 / columns)
        let grid = (0..<columns).map { _ in "<w:gridCol w:w=\"\(width)\"/>" }.joined()
        let trs = parsed.enumerated().map { index, cells in
            rowXML(cells, columns: columns, header: index == 0, width: width)
        }.joined()
        return """
        <w:tbl>
        <w:tblPr>
        <w:tblStyle w:val="TableGrid"/>
        <w:tblW w:w="5000" w:type="pct"/>
        <w:tblBorders>
        <w:top w:val="single" w:sz="4" w:space="0" w:color="2A2118"/>
        <w:left w:val="single" w:sz="4" w:space="0" w:color="2A2118"/>
        <w:bottom w:val="single" w:sz="4" w:space="0" w:color="2A2118"/>
        <w:right w:val="single" w:sz="4" w:space="0" w:color="2A2118"/>
        <w:insideH w:val="single" w:sz="4" w:space="0" w:color="2A2118"/>
        <w:insideV w:val="single" w:sz="4" w:space="0" w:color="2A2118"/>
        </w:tblBorders>
        <w:tblLook w:val="04A0" w:firstRow="1"/>
        </w:tblPr>
        <w:tblGrid>\(grid)</w:tblGrid>
        \(trs)
        </w:tbl>
        """
    }

    private static func rowXML(_ cells: [String], columns: Int, header: Bool, width: Int) -> String {
        var padded = cells
        while padded.count < columns { padded.append("") }
        let tcs = padded.prefix(columns).map { cell in
            let runProps = header ? "<w:rPr><w:b/></w:rPr>" : ""
            return """
            <w:tc>
            <w:tcPr><w:tcW w:w="\(width)" w:type="dxa"/></w:tcPr>
            <w:p><w:r>\(runProps)<w:t xml:space="preserve">\(escape(cell))</w:t></w:r></w:p>
            </w:tc>
            """
        }.joined()
        return "<w:tr>\(tcs)</w:tr>"
    }

    private static func titleParagraph(_ text: String) -> String {
        """
        <w:p>
        <w:pPr><w:pStyle w:val="Title"/><w:jc w:val="center"/><w:spacing w:before="240" w:after="200"/></w:pPr>
        <w:r><w:rPr><w:b/><w:sz w:val="32"/><w:szCs w:val="32"/></w:rPr><w:t xml:space="preserve">\(escape(text))</w:t></w:r>
        </w:p>
        """
    }

    private static func headingParagraph(_ text: String) -> String {
        """
        <w:p>
        <w:pPr><w:pStyle w:val="Heading1"/><w:spacing w:before="280" w:after="120"/></w:pPr>
        <w:r><w:rPr><w:b/><w:sz w:val="24"/><w:szCs w:val="24"/></w:rPr><w:t xml:space="preserve">\(escape(text))</w:t></w:r>
        </w:p>
        """
    }

    private static func subheadingParagraph(_ text: String) -> String {
        """
        <w:p>
        <w:pPr><w:pStyle w:val="Heading2"/><w:spacing w:before="160" w:after="80"/></w:pPr>
        <w:r><w:rPr><w:b/><w:sz w:val="21"/><w:szCs w:val="21"/></w:rPr><w:t xml:space="preserve">\(escape(text))</w:t></w:r>
        </w:p>
        """
    }

    private static func signatureParagraph(_ text: String) -> String {
        """
        <w:p>
        <w:pPr><w:jc w:val="right"/><w:spacing w:before="200"/></w:pPr>
        <w:r><w:t xml:space="preserve">\(escape(text))</w:t></w:r>
        </w:p>
        """
    }

    private static func metaParagraph(_ text: String) -> String {
        """
        <w:p>
        <w:pPr><w:jc w:val="right"/><w:spacing w:after="160"/></w:pPr>
        <w:r><w:rPr><w:sz w:val="18"/><w:szCs w:val="18"/><w:color w:val="6F675C"/></w:rPr><w:t xml:space="preserve">\(escape(text))</w:t></w:r>
        </w:p>
        """
    }

    private static func paragraph(_ text: String, bold: Bool = false) -> String {
        let runProps = bold ? "<w:rPr><w:b/></w:rPr>" : ""
        return "<w:p><w:r>\(runProps)<w:t xml:space=\"preserve\">\(escape(text))</w:t></w:r></w:p>"
    }

    private static func escape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private static func stamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月d日 HH:mm"
        return formatter.string(from: date)
    }
}
