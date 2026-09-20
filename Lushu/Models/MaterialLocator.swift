import Foundation

/// 与案匣 MaterialKnowledge 对齐：材料块必须能回到原件位置。
struct MaterialLocator: Codable, Hashable {
    var packID: UUID
    var relativePath: String
    var page: Int?
    var startOffset: Int?
    var endOffset: Int?
}

struct LocatedTextBlock: Identifiable, Codable, Hashable {
    var id: UUID
    var locator: MaterialLocator
    var text: String
}
