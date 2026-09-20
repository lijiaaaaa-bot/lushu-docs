import Foundation

enum MaterialLayer: String, Codable, Hashable {
    case raw
    case structured
}

enum TableStatus: String, Codable, Hashable {
    case notTable
    case pendingStructure
    case realWorkbook

    var label: String {
        switch self {
        case .notTable: return "文本"
        case .pendingStructure: return "待结构化"
        case .realWorkbook: return "真表"
        }
    }
}

enum MaterialKind: String, Codable, Hashable {
    case txt
    case markdown
    case pdf
    case docx
    case xlsx
    case other

    var displayName: String {
        switch self {
        case .txt: return "TXT"
        case .markdown: return "MD"
        case .pdf: return "PDF"
        case .docx: return "DOCX"
        case .xlsx: return "XLSX"
        case .other: return "其他"
        }
    }

    var isParseSupported: Bool {
        switch self {
        case .txt, .markdown, .pdf, .docx, .xlsx: return true
        case .other: return false
        }
    }

    static func from(filename: String) -> MaterialKind {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "txt": return .txt
        case "md", "markdown": return .markdown
        case "pdf": return .pdf
        case "docx": return .docx
        case "xlsx", "xls": return .xlsx
        default: return .other
        }
    }
}

struct MaterialItem: Identifiable, Hashable, Codable {
    var id: UUID
    var filename: String
    var kind: MaterialKind
    var byteCount: Int
    var relativePath: String
    var included: Bool
    var layer: MaterialLayer
    var tableStatus: TableStatus
    var workbookRelativePath: String?
    var tableSchema: TableSchema?
    var tableLocked: Bool

    init(
        id: UUID = UUID(),
        filename: String,
        kind: MaterialKind,
        byteCount: Int,
        relativePath: String,
        included: Bool = true,
        layer: MaterialLayer = .raw,
        tableStatus: TableStatus = .notTable,
        workbookRelativePath: String? = nil,
        tableSchema: TableSchema? = nil,
        tableLocked: Bool = false
    ) {
        self.id = id
        self.filename = filename
        self.kind = kind
        self.byteCount = byteCount
        self.relativePath = relativePath
        self.included = included
        self.layer = layer
        self.tableStatus = tableStatus
        self.workbookRelativePath = workbookRelativePath
        self.tableSchema = tableSchema
        self.tableLocked = tableLocked
    }

    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(byteCount))
    }

    var statusLabel: String {
        if !included { return "未纳入" }
        if tableStatus != .notTable { return tableStatus.label }
        return layer == .structured ? "已结构化" : "原始"
    }

    /// 首页列表：xlsx 已进 structured/tables 成真表后，不再列出 raw 同名/同逻辑件。
    static func homeVisible(_ items: [MaterialItem]) -> [MaterialItem] {
        let workbookKeys = Set(items.filter { $0.tableStatus == .realWorkbook }.map(\.logicalKey))
        return items.filter { item in
            if item.tableStatus == .realWorkbook { return true }
            if workbookKeys.contains(item.logicalKey) { return false }
            return true
        }
    }

    var logicalKey: String {
        let name = filename.lowercased()
        if let year = BriefCardParser.year(in: filename),
           name.contains("停车") && (name.contains("信息表") || kind == .xlsx) {
            return "parking-\(year)"
        }
        if name.contains("照明") || name.contains("用电") {
            return "lighting"
        }
        return (filename as NSString).deletingPathExtension.lowercased()
    }
}
