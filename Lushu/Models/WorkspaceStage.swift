import Foundation

enum WorkspaceStage: String, CaseIterable, Identifiable, Hashable {
    case materials
    case documentKind
    case draft

    var id: String { rawValue }

    var title: String {
        switch self {
        case .materials: return "材料"
        case .documentKind: return "文书类型"
        case .draft: return "撰稿"
        }
    }

    var shortcutHint: String {
        switch self {
        case .materials: return "⌘1"
        case .documentKind: return "⌘2"
        case .draft: return "⌘3"
        }
    }

    var stepIndex: Int {
        switch self {
        case .materials: return 1
        case .documentKind: return 2
        case .draft: return 3
        }
    }
}
