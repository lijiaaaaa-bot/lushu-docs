import Foundation

enum LegalDomain: String, Codable {
    case civil
    case civilInterpretation
    case criminal
    case criminalInterpretation
}

/// 法索语料范围清单。此处只有 lawID，没有条文正文。
struct LawManifest: Identifiable, Hashable, Codable {
    var id: String
    var title: String
    var domain: LegalDomain
}

enum LegalCorpusError: LocalizedError {
    case kitNotLinked
    case lawOutOfScope(String)
    case articleNotInCorpus(lawID: String, articleNum: String)
    case quoteMismatch
    case refusedToInvent

    var errorDescription: String? {
        switch self {
        case .kitNotLinked:
            return "法索 / LiJiaKit.LegalKnowledge 尚未接入。拒绝编造条文。"
        case .lawOutOfScope(let id):
            return "法律 \(id) 不在本轮语料范围（民法 / 刑法及相关解释）。"
        case .articleNotInCorpus(let lawID, let articleNum):
            return "语料中没有 \(lawID) 第\(articleNum)条。不得编造。"
        case .quoteMismatch:
            return "摘录不是语料原文的连续子串。"
        case .refusedToInvent:
            return "律书不编造法条。请等待法索语料包。"
        }
    }
}

/// 包裹未来 LiJiaKit LegalKnowledge。未接线前任何条文查询与引用校验都必须失败。
struct LegalCorpus {
    static let scopedLaws: [LawManifest] = [
        LawManifest(id: "prc.civil-code", title: "中华人民共和国民法典", domain: .civil),
        LawManifest(id: "prc.civil-code.interpretations", title: "民法典相关司法解释", domain: .civilInterpretation),
        LawManifest(id: "prc.criminal-law", title: "中华人民共和国刑法", domain: .criminal),
        LawManifest(id: "prc.criminal-law.interpretations", title: "刑法相关司法解释", domain: .criminalInterpretation)
    ]

    var isKnowledgeLinked: Bool { false }

    func isInScope(lawID: String) -> Bool {
        Self.scopedLaws.contains { $0.id == lawID }
    }

    /// 在接入 LiJiaKit 前永不返回条文正文。
    func articleText(lawID: String, articleNum: String) throws -> String {
        guard isInScope(lawID: lawID) else {
            throw LegalCorpusError.lawOutOfScope(lawID)
        }
        if !isKnowledgeLinked {
            throw LegalCorpusError.kitNotLinked
        }
        throw LegalCorpusError.articleNotInCorpus(lawID: lawID, articleNum: articleNum)
    }

    func validate(_ citation: LegalCitation) throws {
        guard isInScope(lawID: citation.lawID) else {
            throw LegalCorpusError.lawOutOfScope(citation.lawID)
        }
        let text = try articleText(lawID: citation.lawID, articleNum: citation.articleNum)
        let quote = citation.quote.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !quote.isEmpty, text.contains(quote) else {
            throw LegalCorpusError.quoteMismatch
        }
        if citation.sourceSpan.end <= citation.sourceSpan.start {
            throw LegalCorpusError.quoteMismatch
        }
    }
}
