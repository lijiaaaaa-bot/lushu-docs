import Foundation

/// 文书生成的唯一输入。禁止把原始 PDF 字节直接送进生成器。
struct StructuredCaseInputs: Hashable {
    var caseTitle: String
    var metadata: [String: String]
    var tables: [StructuredTableRef]
    var texts: [LocatedTextBlock]

    var hasStructuredPayload: Bool {
        !tables.isEmpty || !texts.isEmpty
    }

    var lockedTables: [StructuredTableRef] {
        tables.filter(\.isLocked)
    }
}

struct StructuredTableRef: Identifiable, Hashable {
    var id: UUID
    var filename: String
    var relativePath: String
    var fileURL: URL
    var schema: TableSchema
    var isLocked: Bool
}

struct TableSchema: Codable, Hashable {
    var sheetName: String
    var columns: [TableColumn]
}

struct TableColumn: Codable, Hashable, Identifiable {
    var id: UUID
    var name: String
    var typeHint: String

    init(id: UUID = UUID(), name: String, typeHint: String = "string") {
        self.id = id
        self.name = name
        self.typeHint = typeHint
    }
}

enum DocumentGenerationError: LocalizedError {
    case unstructuredInputsRejected
    case noLockedTable
    case citationRejected(String)

    var errorDescription: String? {
        switch self {
        case .unstructuredInputsRejected:
            return "文书只吃结构化案件包。请先完成表结构化工位，勿把原始 PDF 送进生成器。"
        case .noLockedTable:
            return "尚无锁定的真表。请在结构化工位产出 .xlsx 并锁定表头。"
        case .citationRejected(let message):
            return message
        }
    }
}
