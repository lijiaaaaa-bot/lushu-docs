import Foundation

/// 案件包落盘约定。文书工序只读 structured/，raw/ 只读。
struct CasePack: Identifiable, Codable, Hashable {
    var id: UUID
    var folderName: String

    var rawPath: String { "\(folderName)/\(CasePackLayout.raw)" }
    var tablesPath: String { "\(folderName)/\(CasePackLayout.structuredTables)" }
    var textsPath: String { "\(folderName)/\(CasePackLayout.structuredTexts)" }
    var citationsPath: String { "\(folderName)/\(CasePackLayout.citations)" }
    var draftsPath: String { "\(folderName)/\(CasePackLayout.drafts)" }

    static func make(id: UUID = UUID(), title: String) -> CasePack {
        let slug = title
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: " ", with: "-")
        return CasePack(id: id, folderName: "CasePacks/\(id.uuidString)/\(slug)")
    }
}

enum CasePackLayout {
    static let raw = "raw"
    static let structuredTables = "structured/tables"
    static let structuredTexts = "structured/texts"
    static let citations = "citations"
    static let drafts = "drafts"

    static let allRelative: [String] = [
        raw,
        structuredTables,
        structuredTexts,
        citations,
        drafts
    ]
}
