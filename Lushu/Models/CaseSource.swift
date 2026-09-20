import Foundation

enum SourceOrigin: String, Codable, Hashable {
    case anxiaFolder
    case importedFiles
    case importedFolder

    var title: String {
        switch self {
        case .anxiaFolder: return "案匣 / iCloud"
        case .importedFiles: return "导入文件"
        case .importedFolder: return "导入文件夹"
        }
    }

    var symbolName: String {
        switch self {
        case .anxiaFolder: return "externaldrive.connected.to.line.below"
        case .importedFiles: return "doc.badge.arrow.up"
        case .importedFolder: return "folder.badge.plus"
        }
    }
}

struct CaseSource: Identifiable, Hashable, Codable {
    var id: UUID
    var title: String
    var origin: SourceOrigin
    var locationCaption: String
    var materials: [MaterialItem]
    var isSample: Bool
    var lastOpenedAt: Date

    var includedCount: Int { materials.filter(\.included).count }

    var displaySubtitle: String {
        "\(origin.title) · \(includedCount) 份材料"
    }
}
