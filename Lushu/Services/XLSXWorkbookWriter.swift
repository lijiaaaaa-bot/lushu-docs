import Foundation

struct XLSXSheet: Hashable {
    var name: String
    var headers: [String]
    var rows: [[String]]
}

/// 写出可打开的 OOXML .xlsx（STORE zip）。最终表工件必须是工作簿，不是碎文本。
enum XLSXWorkbookWriter {
    static func write(sheets: [XLSXSheet], to url: URL) throws {
        precondition(!sheets.isEmpty, "xlsx 至少一张表")
        let entries = try packageEntries(sheets: sheets)
        let zip = ZipStoreWriter.data(from: entries)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try zip.write(to: url, options: .atomic)
    }

    private static func packageEntries(sheets: [XLSXSheet]) throws -> [(String, Data)] {
        var strings: [String] = []
        var index: [String: Int] = [:]
        func intern(_ value: String) -> Int {
            if let existing = index[value] { return existing }
            let next = strings.count
            strings.append(value)
            index[value] = next
            return next
        }

        for sheet in sheets {
            for header in sheet.headers { _ = intern(header) }
            for row in sheet.rows {
                for cell in row { _ = intern(cell) }
            }
        }

        var files: [(String, Data)] = [
            ("[Content_Types].xml", Data(contentTypes(sheetCount: sheets.count).utf8)),
            ("_rels/.rels", Data(rootRels.utf8)),
            ("xl/workbook.xml", Data(workbookXML(sheets: sheets).utf8)),
            ("xl/_rels/workbook.xml.rels", Data(workbookRels(sheetCount: sheets.count).utf8)),
            ("xl/styles.xml", Data(stylesXML.utf8)),
            ("xl/sharedStrings.xml", Data(sharedStringsXML(strings).utf8))
        ]
        for (offset, sheet) in sheets.enumerated() {
            files.append((
                "xl/worksheets/sheet\(offset + 1).xml",
                Data(worksheetXML(sheet, intern: intern).utf8)
            ))
        }
        return files
    }

    private static func contentTypes(sheetCount: Int) -> String {
        var overrides = """
        <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
        <Override PartName="/xl/sharedStrings.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml"/>
        <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
        """
        for i in 1...sheetCount {
            overrides += "<Override PartName=\"/xl/worksheets/sheet\(i).xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/>"
        }
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
        <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
        <Default Extension="xml" ContentType="application/xml"/>
        \(overrides)
        </Types>
        """
    }

    private static let rootRels = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
    <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
    </Relationships>
    """

    private static func workbookXML(sheets: [XLSXSheet]) -> String {
        let sheetsXML = sheets.enumerated().map { index, sheet in
            "<sheet name=\"\(xml(sheet.name))\" sheetId=\"\(index + 1)\" r:id=\"rId\(index + 1)\"/>"
        }.joined()
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
        <sheets>\(sheetsXML)</sheets>
        </workbook>
        """
    }

    private static func workbookRels(sheetCount: Int) -> String {
        var rels = (1...sheetCount).map { i in
            "<Relationship Id=\"rId\(i)\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet\" Target=\"worksheets/sheet\(i).xml\"/>"
        }.joined()
        rels += "<Relationship Id=\"rId\(sheetCount + 1)\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/sharedStrings\" Target=\"sharedStrings.xml\"/>"
        rels += "<Relationship Id=\"rId\(sheetCount + 2)\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles\" Target=\"styles.xml\"/>"
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        \(rels)
        </Relationships>
        """
    }

    private static let stylesXML = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
    <fonts count="1"><font><sz val="11"/><name val="Calibri"/></font></fonts>
    <fills count="1"><fill><patternFill patternType="none"/></fill></fills>
    <borders count="1"><border/></borders>
    <cellXfs count="1"><xf/></cellXfs>
    </styleSheet>
    """

    private static func sharedStringsXML(_ strings: [String]) -> String {
        let items = strings.map { "<si><t>\(xml($0))</t></si>" }.joined()
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" count="\(strings.count)" uniqueCount="\(strings.count)">
        \(items)
        </sst>
        """
    }

    private static func worksheetXML(_ sheet: XLSXSheet, intern: (String) -> Int) -> String {
        var rowsXML = "<row r=\"1\">"
        for (col, header) in sheet.headers.enumerated() {
            rowsXML += "<c r=\"\(cellName(col, 1))\" t=\"s\"><v>\(intern(header))</v></c>"
        }
        rowsXML += "</row>"
        for (rowIndex, row) in sheet.rows.enumerated() {
            let r = rowIndex + 2
            rowsXML += "<row r=\"\(r)\">"
            for (col, value) in row.enumerated() where col < sheet.headers.count {
                rowsXML += "<c r=\"\(cellName(col, r))\" t=\"s\"><v>\(intern(value))</v></c>"
            }
            rowsXML += "</row>"
        }
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
        <sheetData>\(rowsXML)</sheetData>
        </worksheet>
        """
    }

    private static func cellName(_ col: Int, _ row: Int) -> String {
        var n = col
        var letters = ""
        repeat {
            letters = String(UnicodeScalar(65 + (n % 26))!) + letters
            n = n / 26 - 1
        } while n >= 0
        return "\(letters)\(row)"
    }

    private static func xml(_ raw: String) -> String {
        raw
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}

enum ZipStoreWriter {
    static func data(from files: [(String, Data)]) -> Data {
        var locals = Data()
        var centrals = Data()
        var offset: UInt32 = 0
        for (path, payload) in files {
            let name = Data(path.utf8)
            let crc = CRC32.hash(payload)
            let size = UInt32(payload.count)
            var local = Data()
            local.appendUInt32(0x04034b50)
            local.appendUInt16(20)
            local.appendUInt16(0)
            local.appendUInt16(0)
            local.appendUInt16(0)
            local.appendUInt16(0)
            local.appendUInt32(crc)
            local.appendUInt32(size)
            local.appendUInt32(size)
            local.appendUInt16(UInt16(name.count))
            local.appendUInt16(0)
            local.append(name)
            local.append(payload)
            locals.append(local)

            var central = Data()
            central.appendUInt32(0x02014b50)
            central.appendUInt16(20)
            central.appendUInt16(20)
            central.appendUInt16(0)
            central.appendUInt16(0)
            central.appendUInt16(0)
            central.appendUInt16(0)
            central.appendUInt32(crc)
            central.appendUInt32(size)
            central.appendUInt32(size)
            central.appendUInt16(UInt16(name.count))
            central.appendUInt16(0)
            central.appendUInt16(0)
            central.appendUInt16(0)
            central.appendUInt16(0)
            central.appendUInt32(0)
            central.appendUInt32(offset)
            central.append(name)
            centrals.append(central)
            offset += UInt32(local.count)
        }
        var end = Data()
        end.appendUInt32(0x06054b50)
        end.appendUInt16(0)
        end.appendUInt16(0)
        end.appendUInt16(UInt16(files.count))
        end.appendUInt16(UInt16(files.count))
        end.appendUInt32(UInt32(centrals.count))
        end.appendUInt32(offset)
        end.appendUInt16(0)
        var out = Data()
        out.append(locals)
        out.append(centrals)
        out.append(end)
        return out
    }
}

private enum CRC32 {
    static func hash(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in data {
            let idx = Int((crc ^ UInt32(byte)) & 0xFF)
            crc = table[idx] ^ (crc >> 8)
        }
        return crc ^ 0xFFFF_FFFF
    }

    private static let table: [UInt32] = (0..<256).map { i in
        var c = UInt32(i)
        for _ in 0..<8 {
            if c & 1 == 1 {
                c = 0xEDB8_8320 ^ (c >> 1)
            } else {
                c >>= 1
            }
        }
        return c
    }
}

private extension Data {
    mutating func appendUInt16(_ value: UInt16) {
        var little = value.littleEndian
        Swift.withUnsafeBytes(of: &little) { append(contentsOf: $0) }
    }

    mutating func appendUInt32(_ value: UInt32) {
        var little = value.littleEndian
        Swift.withUnsafeBytes(of: &little) { append(contentsOf: $0) }
    }
}
