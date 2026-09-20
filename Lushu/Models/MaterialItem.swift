import Foundation

enum MaterialKind: String, Codable, Hashable {
    case txt
    case markdown
    case pdf
    case docx
    case other

    var displayName: String {
        switch self {
        case .txt: return "TXT"
        case .markdown: return "MD"
        case .pdf: return "PDF"
        case .docx: return "DOCX"
        case .other: return "其他"
        }
    }

    var isParseSupported: Bool {
        switch self {
        case .txt, .markdown, .pdf, .docx: return true
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

    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(byteCount))
    }

    var statusLabel: String {
        if !included { return "未纳入" }
        return kind.isParseSupported ? "可读取" : "仅列名"
    }
}
