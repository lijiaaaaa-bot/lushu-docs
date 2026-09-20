import XCTest
@testable import Lushu

final class LegalCorpusTests: XCTestCase {
    func testLooksUpCriminalLawArticleOneFromCorpusFile() throws {
        let (corpus, raw) = try loadCorpusAndRawChunks()
        let fileChunk = try XCTUnwrap(raw.first { $0.id == "刑法/第一条" })
        let lookedUp = try corpus.lookup(lawID: "刑法", articleNum: "第一条")
        let byID = try corpus.lookup(articleID: "刑法/第一条")
        let byArabic = try corpus.lookup(lawID: "刑法", articleNum: "1")

        XCTAssertEqual(lookedUp.text, fileChunk.text)
        XCTAssertEqual(byID.text, fileChunk.text)
        XCTAssertEqual(byArabic.text, fileChunk.text)
        XCTAssertFalse(lookedUp.text.isEmpty)
    }

    func testLooksUpCivilCodeGeneralPrinciplesArticleOneFromCorpusFile() throws {
        let (corpus, raw) = try loadCorpusAndRawChunks()
        let fileChunk = try XCTUnwrap(raw.first { $0.id == "总则/第一条" })
        let lookedUp = try corpus.lookup(lawID: "总则", articleNum: "第一条")
        let byArabic = try corpus.lookup(lawID: "总则", articleNum: "1")

        XCTAssertEqual(lookedUp.text, fileChunk.text)
        XCTAssertEqual(byArabic.text, fileChunk.text)
        XCTAssertEqual(fileChunk.lawTitle, "中华人民共和国民法典")
        XCTAssertTrue(fileChunk.heading.contains("基本规定"))
    }

    func testUnknownArticleDoesNotInventText() {
        let corpus = try? LegalCorpus.load(directory: Self.corpusDirectory())
        XCTAssertNotNil(corpus)
        XCTAssertThrowsError(try corpus?.lookup(lawID: "刑法", articleNum: "第零条")) { error in
            guard case LegalCorpusError.articleNotInCorpus = error as? LegalCorpusError else {
                return XCTFail("expected articleNotInCorpus, got \(error)")
            }
        }
    }

    func testHiddenCitationQuoteMustBeSubstring() throws {
        let corpus = try LegalCorpus.load(directory: Self.corpusDirectory())
        let chunk = try corpus.lookup(articleID: "刑法/第一条")
        var ok = try corpus.makeHiddenCitation(articleID: "刑法/第一条")
        XCTAssertEqual(ok.display, .hidden)
        try corpus.validate(ok)

        ok.quote = "这不是语料里的句子"
        XCTAssertFalse(chunk.text.contains(ok.quote))
        XCTAssertThrowsError(try corpus.validate(ok))
    }

    private func loadCorpusAndRawChunks() throws -> (LegalCorpus, [LegalChunk]) {
        let directory = Self.corpusDirectory()
        let corpus = try LegalCorpus.load(directory: directory)
        let data = try Data(contentsOf: directory.appendingPathComponent("laws_chunks.json"))
        let raw = try JSONDecoder().decode([LegalChunk].self, from: data)
        return (corpus, raw)
    }

    private static func corpusDirectory(filePath: String = #filePath) -> URL {
        URL(fileURLWithPath: filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Lushu/Resources/LegalKnowledge", isDirectory: true)
    }
}
