import Foundation

/// 写出可打开的 OOXML .docx（STORE zip）。首页生成后优先提供此文件，不在对话里展开正文。
enum DOCXDocumentWriter {
    static func write(_ draft: DraftDocument, to url: URL) throws {
        let entries = packageEntries(draft)
        let zip = ZipStoreWriter.data(from: entries)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try zip.write(to: url, options: .atomic)
    }

    private static func packageEntries(_ draft: DraftDocument) -> [(String, Data)] {
        [
            ("[Content_Types].xml", Data(contentTypes.utf8)),
            ("_rels/.rels", Data(rootRels.utf8)),
            ("word/_rels/document.xml.rels", Data(documentRels.utf8)),
            ("word/document.xml", Data(documentXML(draft).utf8))
        ]
    }

    private static let contentTypes = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
    <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
    <Default Extension="xml" ContentType="application/xml"/>
    <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
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
    </Relationships>
    """

    private static func documentXML(_ draft: DraftDocument) -> String {
        var paragraphs = [paragraph(draft.title, bold: true)]
        if let generatedAt = draft.generatedAt {
            paragraphs.append(paragraph("\(draft.generatorLabel) · \(stamp(generatedAt))"))
        }
        for section in draft.sections {
            paragraphs.append(paragraph(section.heading, bold: true))
            for line in section.body.components(separatedBy: .newlines) {
                paragraphs.append(paragraph(line))
            }
        }
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:body>
        \(paragraphs.joined())
        </w:body>
        </w:document>
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
