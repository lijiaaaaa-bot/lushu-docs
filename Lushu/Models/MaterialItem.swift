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
}
