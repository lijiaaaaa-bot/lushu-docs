import Foundation

/// 剧本工厂式工位。下游只吃上游锁定结果。
enum WorkstationStage: Int, CaseIterable, Identifiable, Hashable {
    case importMaterials
    case structure
    case document
    case provenance

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .importMaterials: return "导入"
        case .structure: return "结构化"
        case .document: return "文书"
        case .provenance: return "溯源"
        }
    }
}
