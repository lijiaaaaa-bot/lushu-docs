import Foundation

enum TableJobInput: Hashable {
    case pdfRegion(relativePath: String, page: Int, note: String)
    case workbook(relativePath: String)
    case image(relativePath: String)

    var displayName: String {
        switch self {
        case .pdfRegion(let path, let page, _):
            return "\(path) · 第\(page)页"
        case .workbook(let path), .image(let path):
            return path
        }
    }
}

enum TableJobStatus: String, Codable {
    case pending
    case wroteWorkbook
    case awaitingHeaderLock
    case locked
    case failed
}

/// 表结构化工位。最终产物必须是真实 .xlsx，禁止把碎行文本当作表。
struct TableStructuringJob: Identifiable, Hashable {
    var id: UUID
    var packID: UUID
    var input: TableJobInput
    var suggestedFilename: String
    var status: TableJobStatus
    var outputRelativePath: String?
    var schema: TableSchema?
    var locked: Bool
    var message: String?
}

struct TableStructuringResult: Hashable {
    var job: TableStructuringJob
    var workbookURL: URL
    var schema: TableSchema
}
