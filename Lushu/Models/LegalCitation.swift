import Foundation

/// 法条引用。quote 必须是法索语料原文或其连续子串；默认不在稿面展示。
struct LegalCitation: Identifiable, Codable, Hashable {
    var id: UUID
    var lawID: String
    var lawTitle: String
    var articleNum: String
    var articleTitle: String?
    var quote: String
    var sourceSpan: SourceSpan
    var display: CitationDisplay

    init(
        id: UUID = UUID(),
        lawID: String,
        lawTitle: String,
        articleNum: String,
        articleTitle: String? = nil,
        quote: String,
        sourceSpan: SourceSpan,
        display: CitationDisplay = .hidden
    ) {
        self.id = id
        self.lawID = lawID
        self.lawTitle = lawTitle
        self.articleNum = articleNum
        self.articleTitle = articleTitle
        self.quote = quote
        self.sourceSpan = sourceSpan
        self.display = display
    }

    var locatorLabel: String {
        let article = articleNum.contains("条") ? articleNum : "第\(articleNum)条"
        return "\(lawTitle) \(article)"
    }
}

struct SourceSpan: Codable, Hashable {
    enum Unit: String, Codable {
        case corpusOffset
        case articleOffset
    }

    var start: Int
    var end: Int
    var unit: Unit
}

enum CitationDisplay: String, Codable {
    /// 默认：稿面不打断阅读，模型内可打开原文。
    case hidden
    case footnote
    case inline
}
