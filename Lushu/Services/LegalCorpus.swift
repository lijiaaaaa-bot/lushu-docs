import Foundation

enum LegalDomain: String, Codable {
    case civil
    case civilInterpretation
    case criminal
    case criminalInterpretation
    case unknown
}

struct LawManifest: Identifiable, Hashable, Codable {
    var id: String
    var title: String
    var domain: LegalDomain
}

struct LegalChunk: Identifiable, Hashable, Codable {
    var id: String
    var lawID: String
    var lawTitle: String
    var category: String
    var articleNum: String
    var heading: String
    var text: String

    enum CodingKeys: String, CodingKey {
        case id
        case lawID = "law_id"
        case lawTitle = "law_title"
        case category
        case articleNum = "article_num"
        case heading
        case text
    }
}

struct CorpusManifest: Hashable, Codable {
    var corpusVersion: String
    var parentCorpusVersion: String
    var builtFor: String
    var scope: String
    var lawCount: Int
    var chunkCount: Int
    var lawIDs: [String]

    enum CodingKeys: String, CodingKey {
        case corpusVersion = "corpus_version"
        case parentCorpusVersion = "parent_corpus_version"
        case builtFor = "built_for"
        case scope
        case lawCount = "law_count"
        case chunkCount = "chunk_count"
        case lawIDs = "law_ids"
    }
}

enum LegalCorpusError: LocalizedError {
    case bundleMissing
    case lawOutOfScope(String)
    case articleNotInCorpus(lawID: String, articleNum: String)
    case quoteMismatch
    case refusedToInvent

    var errorDescription: String? {
        switch self {
        case .bundleMissing:
            return "未找到 Resources/LegalKnowledge 语料。拒绝编造条文。"
        case .lawOutOfScope(let id):
            return "法律 \(id) 不在本轮子集范围（民法典各编 / 刑法及修正案 / 相关司法解释）。"
        case .articleNotInCorpus(let lawID, let articleNum):
            return "语料中没有 \(lawID) \(articleNum)。不得编造。"
        case .quoteMismatch:
            return "摘录不是语料原文的连续子串。"
        case .refusedToInvent:
            return "律书不编造法条。只引用 LegalKnowledge 子集中的原文。"
        }
    }
}

/// 法索 / LiJiaKit LegalKnowledge 子集加载器。只返回包内原文，查找失败则报错。
struct LegalCorpus {
    var manifest: CorpusManifest
    private var chunksByID: [String: LegalChunk]
    private var chunksByLawArticle: [String: LegalChunk]
    private var scopedLawIDs: Set<String>

    var isKnowledgeLinked: Bool { !chunksByID.isEmpty }
    var chunkCount: Int { chunksByID.count }

    static var empty: LegalCorpus {
        LegalCorpus(
            manifest: CorpusManifest(
                corpusVersion: "missing",
                parentCorpusVersion: "",
                builtFor: "lushu-docs",
                scope: "",
                lawCount: 0,
                chunkCount: 0,
                lawIDs: []
            ),
            chunksByID: [:],
            chunksByLawArticle: [:],
            scopedLawIDs: []
        )
    }

    static let scopedLaws: [LawManifest] = [
        LawManifest(id: "民法典", title: "中华人民共和国民法典", domain: .civil),
        LawManifest(id: "总则", title: "中华人民共和国民法典 · 总则编", domain: .civil),
        LawManifest(id: "刑法", title: "中华人民共和国刑法", domain: .criminal)
    ]

    static func loadPreferred() -> LegalCorpus {
        if let bundled = try? bundled() { return bundled }
        if let local = try? load(directory: developmentDirectory()) { return local }
        return .empty
    }

    static func developmentDirectory(filePath: String = #filePath) -> URL {
        URL(fileURLWithPath: filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Resources/LegalKnowledge", isDirectory: true)
    }

    static func bundled() throws -> LegalCorpus {
        let directory = try resolveBundleDirectory()
        return try load(directory: directory)
    }

    static func load(directory: URL) throws -> LegalCorpus {
        let manifestURL = directory.appendingPathComponent("corpus_manifest.json")
        let chunksURL = directory.appendingPathComponent("laws_chunks.json")
        guard FileManager.default.fileExists(atPath: manifestURL.path),
              FileManager.default.fileExists(atPath: chunksURL.path)
        else {
            throw LegalCorpusError.bundleMissing
        }
        let decoder = JSONDecoder()
        let manifest = try decoder.decode(CorpusManifest.self, from: Data(contentsOf: manifestURL))
        let chunks = try decoder.decode([LegalChunk].self, from: Data(contentsOf: chunksURL))
        return LegalCorpus(manifest: manifest, chunks: chunks)
    }

    init(manifest: CorpusManifest, chunks: [LegalChunk]) {
        self.manifest = manifest
        scopedLawIDs = Set(manifest.lawIDs)
        var byID: [String: LegalChunk] = [:]
        var byPair: [String: LegalChunk] = [:]
        for chunk in chunks {
            byID[chunk.id] = chunk
            let lawKeys = Set([chunk.lawID, chunk.lawTitle])
            for lawKey in lawKeys {
                for articleKey in ArticleNumber.variants(chunk.articleNum) {
                    byPair[LegalCorpus.pairKey(lawKey, articleKey)] = chunk
                }
            }
        }
        chunksByID = byID
        chunksByLawArticle = byPair
    }

    private init(
        manifest: CorpusManifest,
        chunksByID: [String: LegalChunk],
        chunksByLawArticle: [String: LegalChunk],
        scopedLawIDs: Set<String>
    ) {
        self.manifest = manifest
        self.chunksByID = chunksByID
        self.chunksByLawArticle = chunksByLawArticle
        self.scopedLawIDs = scopedLawIDs
    }

    func isInScope(lawID: String) -> Bool {
        if scopedLawIDs.contains(lawID) { return true }
        if chunksByLawArticle[Self.pairKey(lawID, "第一条")] != nil { return true }
        if chunksByID.values.contains(where: { $0.lawID == lawID || $0.lawTitle == lawID }) {
            return true
        }
        return false
    }

    func lookup(articleID: String) throws -> LegalChunk {
        if let chunk = chunksByID[articleID] {
            return chunk
        }
        if articleID.contains("/") {
            let parts = articleID.split(separator: "/", maxSplits: 1).map(String.init)
            if parts.count == 2 {
                return try lookup(lawID: parts[0], articleNum: parts[1])
            }
        }
        throw LegalCorpusError.articleNotInCorpus(lawID: articleID, articleNum: "")
    }

    func lookup(lawID: String, articleNum: String) throws -> LegalChunk {
        for variant in ArticleNumber.variants(articleNum) {
            if let chunk = chunksByLawArticle[Self.pairKey(lawID, variant)] {
                return chunk
            }
        }
        if isInScope(lawID: lawID) {
            throw LegalCorpusError.articleNotInCorpus(lawID: lawID, articleNum: articleNum)
        }
        throw LegalCorpusError.lawOutOfScope(lawID)
    }

    func articleText(lawID: String, articleNum: String) throws -> String {
        try lookup(lawID: lawID, articleNum: articleNum).text
    }

    func validate(_ citation: LegalCitation) throws {
        let chunk: LegalChunk
        if citation.lawID.contains("/") {
            chunk = try lookup(articleID: citation.lawID)
        } else {
            chunk = try lookup(lawID: citation.lawID, articleNum: citation.articleNum)
        }
        let quote = citation.quote.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !quote.isEmpty, chunk.text.contains(quote) else {
            throw LegalCorpusError.quoteMismatch
        }
        if citation.sourceSpan.end <= citation.sourceSpan.start {
            throw LegalCorpusError.quoteMismatch
        }
        let span = citation.sourceSpan
        if span.unit == .articleOffset {
            let chars = Array(chunk.text)
            guard span.start >= 0, span.end <= chars.count else {
                throw LegalCorpusError.quoteMismatch
            }
            let slice = String(chars[span.start..<span.end])
            if !chunk.text.contains(slice), slice != quote {
                throw LegalCorpusError.quoteMismatch
            }
        }
    }

    func makeHiddenCitation(articleID: String) throws -> LegalCitation {
        let chunk = try lookup(articleID: articleID)
        return LegalCitation(
            lawID: chunk.lawID,
            lawTitle: chunk.lawTitle,
            articleNum: chunk.articleNum,
            articleTitle: chunk.heading.isEmpty ? nil : chunk.heading,
            quote: chunk.text,
            sourceSpan: SourceSpan(start: 0, end: chunk.text.count, unit: .articleOffset),
            display: .hidden
        )
    }

    private static func pairKey(_ lawID: String, _ articleNum: String) -> String {
        "\(lawID)\u{1f}\(articleNum)"
    }

    private static func resolveBundleDirectory() throws -> URL {
        let bundle = Bundle.main
        let candidates = [
            bundle.resourceURL?.appendingPathComponent("Resources/LegalKnowledge"),
            bundle.resourceURL?.appendingPathComponent("LegalKnowledge"),
            bundle.url(forResource: "laws_chunks", withExtension: "json", subdirectory: "Resources/LegalKnowledge")?.deletingLastPathComponent(),
            bundle.url(forResource: "laws_chunks", withExtension: "json", subdirectory: "LegalKnowledge")?.deletingLastPathComponent(),
            bundle.url(forResource: "laws_chunks", withExtension: "json")?.deletingLastPathComponent()
        ]
        for url in candidates.compactMap({ $0 }) {
            if FileManager.default.fileExists(atPath: url.appendingPathComponent("laws_chunks.json").path) {
                return url
            }
        }
        throw LegalCorpusError.bundleMissing
    }
}

enum ArticleNumber {
    static func variants(_ raw: String) -> [String] {
        let compact = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "　", with: "")
        var values: Set<String> = [raw, compact]
        var core = compact
        if core.hasPrefix("第") { core.removeFirst() }
        if core.hasSuffix("条") { core.removeLast() }
        values.insert(core)
        values.insert("第\(core)条")
        if let arabic = Int(core) {
            let chinese = toChinese(arabic)
            values.insert("\(arabic)")
            values.insert("第\(arabic)条")
            values.insert(chinese)
            values.insert("第\(chinese)条")
        }
        if let arabic = fromChinese(core) {
            values.insert("\(arabic)")
            values.insert("第\(arabic)条")
            values.insert("第\(core)条")
        }
        return Array(values)
    }

    static func toChinese(_ value: Int) -> String {
        let digits = ["零", "一", "二", "三", "四", "五", "六", "七", "八", "九"]
        if value <= 0 { return "\(value)" }
        if value < 10 { return digits[value] }
        if value == 10 { return "十" }
        if value < 20 { return "十" + digits[value % 10] }
        if value < 100 {
            let tens = value / 10
            let ones = value % 10
            return digits[tens] + "十" + (ones == 0 ? "" : digits[ones])
        }
        if value < 1000 {
            let hundreds = value / 100
            let rest = value % 100
            var text = digits[hundreds] + "百"
            if rest == 0 { return text }
            if rest < 10 { return text + "零" + digits[rest] }
            return text + toChinese(rest)
        }
        return "\(value)"
    }

    static func fromChinese(_ raw: String) -> Int? {
        let map: [Character: Int] = [
            "零": 0, "一": 1, "二": 2, "三": 3, "四": 4,
            "五": 5, "六": 6, "七": 7, "八": 8, "九": 9
        ]
        if raw.isEmpty { return nil }
        if raw == "十" { return 10 }
        if let only = map[raw.first!], raw.count == 1 { return only }
        if raw.contains("百") || raw.contains("千") { return nil }
        if raw.hasPrefix("十"), raw.count == 2, let ones = map[raw.last!] {
            return 10 + ones
        }
        if raw.hasSuffix("十"), raw.count == 2, let tens = map[raw.first!] {
            return tens * 10
        }
        if raw.count == 3, raw[raw.index(raw.startIndex, offsetBy: 1)] == "十",
           let tens = map[raw.first!], let ones = map[raw.last!] {
            return tens * 10 + ones
        }
        return nil
    }
}
