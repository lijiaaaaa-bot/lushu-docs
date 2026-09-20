import XCTest
@testable import Lushu

final class BriefCardTests: XCTestCase {
    func testParsesHaitianExampleBrief() {
        let caseID = UUID()
        let card = BriefCardParser.parse(SampleCaseLoader.embeddedExampleBrief, caseID: caseID)

        XCTAssertEqual(card.caseID, caseID)
        XCTAssertEqual(card.stance, .defendant)
        XCTAssertTrue(card.documentPurpose.contains("报告") || card.documentPurpose.contains("停车"))
        XCTAssertTrue(card.yearsScope.contains("2018"))
        XCTAssertTrue(card.yearsScope.contains("2026"))
        XCTAssertTrue(card.requiredSections.contains(where: { $0.contains("停车") }))
        XCTAssertTrue(card.requiredSections.contains(where: { $0.contains("照明") }))
        XCTAssertTrue(card.missingFacts.contains("电价P"))
        XCTAssertTrue(card.missingFacts.contains("全场灯数N"))
        XCTAssertFalse(card.calculationRules.isEmpty)
        XCTAssertTrue(card.chips.contains("乙方"))
        XCTAssertTrue(card.chips.contains(where: { $0.contains("电价P") }))
        XCTAssertEqual(card.requiredSections.filter { $0.contains("停车") }.count, 1)
        XCTAssertEqual(card.requiredSections.filter { $0.contains("计算") }.count, 1)
        XCTAssertEqual(card.requiredSections.count, 5)
        XCTAssertFalse(card.requiredSections.contains(where: { $0.contains("以下") }))
        XCTAssertFalse(card.requiredSections.contains(where: { $0.count > 24 }))
        let preview = BriefCardParser.shortUserPreview(SampleCaseLoader.embeddedExampleBrief, card: card)
        XCTAssertTrue(preview.count < 80)
        XCTAssertFalse(preview.contains("计算规则"))
        let ack = BriefCardParser.shortAcknowledge(card)
        XCTAssertTrue(ack.contains("缺"))
        XCTAssertTrue(ack.count < 80)
    }

    func testYearGapsDoNotInventMissingLedgers() {
        let tables = [
            tableRef("2022年1月份到12月份阜外医院职工停车信息表.xlsx"),
            tableRef("2026年1月份到12月份阜外医院职工停车信息表.xlsx")
        ]
        let gaps = BriefCardParser.yearGaps(requested: "2018–2026", tables: tables)
        XCTAssertTrue(gaps.contains("2018年停车信息表"))
        XCTAssertTrue(gaps.contains("2021年停车信息表"))
        XCTAssertFalse(gaps.contains("2022年停车信息表"))
        XCTAssertFalse(gaps.contains("2026年停车信息表"))
    }

    func testGeneratorFillsFromStructuredDataAndListsGaps() throws {
        let brief = BriefCardParser.parse(SampleCaseLoader.embeddedExampleBrief, caseID: UUID())
        let lighting = "负一层 西直梯电房 每个灯6.21瓦"
        let inputs = StructuredCaseInputs(
            caseTitle: "海天×阜外停车场费用材料",
            metadata: [:],
            tables: [
                tableRef("2022年1月份到12月份阜外医院职工停车信息表.xlsx"),
                tableRef("2023年1月份到12月份阜外医院职工停车信息表.xlsx"),
                tableRef("2024年1月份到12月份阜外医院职工停车信息表.xlsx"),
                tableRef("2025年1月份到12月份阜外医院职工停车信息表.xlsx"),
                tableRef("2026年1月份到12月份阜外医院职工停车信息表.xlsx")
            ],
            texts: [
                LocatedTextBlock(
                    id: UUID(),
                    locator: MaterialLocator(
                        packID: UUID(),
                        relativePath: "raw/2026.9.16停车场照明用电测算表-新.docx",
                        page: nil,
                        startOffset: 0,
                        endOffset: lighting.count
                    ),
                    text: lighting
                )
            ]
        )

        let draft = try DocumentGenerator().generate(kind: .customReport, inputs: inputs, brief: brief)
        let body = draft.sections.map(\.body).joined(separator: "\n")

        XCTAssertTrue(draft.title.contains("海天"))
        XCTAssertTrue(body.contains("乙方"))
        XCTAssertTrue(body.contains("2022年"))
        XCTAssertTrue(body.contains("6.21瓦"))
        XCTAssertTrue(body.contains("电价P"))
        XCTAssertTrue(body.contains("全场灯数N"))
        XCTAssertTrue(body.contains("2018年停车信息表"))
        XCTAssertFalse(body.contains("根据刑法"))
        XCTAssertFalse(body.contains("0.85元"))
        XCTAssertFalse(body.contains("行业经验"))

        let headings = draft.sections.map(\.heading)
        XCTAssertEqual(headings.filter { $0.contains("停车") }.count, 1)
        XCTAssertEqual(headings.filter { $0.contains("计算") }.count, 1)
        XCTAssertEqual(headings.filter { $0.contains("照明") || $0.contains("用电") }.count, 1)
    }

    func testDOCXExportContainsTitleNotInventedStatutes() throws {
        let brief = BriefCardParser.parse(SampleCaseLoader.embeddedExampleBrief, caseID: UUID())
        let inputs = StructuredCaseInputs(
            caseTitle: "海天×阜外停车场费用材料",
            metadata: [:],
            tables: [tableRef("2022年1月份到12月份阜外医院职工停车信息表.xlsx")],
            texts: []
        )
        let draft = try DocumentGenerator().generate(kind: .customReport, inputs: inputs, brief: brief)
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent("LushuDraft-\(UUID().uuidString).docx")
        defer { try? FileManager.default.removeItem(at: dest) }
        try DOCXDocumentWriter.write(draft, to: dest)
        XCTAssertTrue(ZipArchive.hasEntry(named: "word/document.xml", in: dest))
        let xml = String(data: try ZipArchive.data(named: "word/document.xml", in: dest), encoding: .utf8) ?? ""
        XCTAssertTrue(xml.contains("海天"))
        XCTAssertFalse(xml.contains("根据刑法"))
    }

    func testChatIsCaseBound() {
        let a = UUID()
        let b = UUID()
        var chat = CaseBriefChat(caseID: a)
        chat.card = BriefCardParser.parse("请按甲方写材料总结。", caseID: a)
        XCTAssertEqual(chat.caseID, a)
        XCTAssertNotEqual(chat.caseID, b)
        XCTAssertEqual(chat.card.stance, .plaintiff)
        XCTAssertTrue(chat.hasCard)
    }

    @MainActor
    func testHomeTopicsIncludeInboxAndSelectedSample() {
        let empty = AppState()
        XCTAssertEqual(empty.homeTopics.count, 1)
        XCTAssertEqual(empty.selectedTopicID, AppState.homeInboxID)
        XCTAssertTrue(empty.homeTopics.contains { $0.isInbox && $0.title == "新对话" })

        let seeded = AppState(seedHomeSample: true)
        XCTAssertEqual(seeded.homeTopics.count, 2)
        XCTAssertTrue(seeded.homeTopics.contains { $0.isInbox })
        XCTAssertTrue(seeded.homeTopics.contains { $0.title.contains("海天") })
        XCTAssertEqual(seeded.selectedTopicID, seeded.selectedSourceID)
        XCTAssertNotEqual(seeded.selectedTopicID, AppState.homeInboxID)

        seeded.startNewConversation()
        XCTAssertEqual(seeded.selectedTopicID, AppState.homeInboxID)
        seeded.selectTopic(seeded.sources[0].id)
        XCTAssertEqual(seeded.selectedTopicID, seeded.sources[0].id)
    }

    func testExampleBriefFileMatchesEmbeddedSeed() throws {
        let file = SampleCaseLoader.exampleBrief()
        XCTAssertTrue(file.contains("乙方"))
        XCTAssertTrue(file.contains("2018"))
        XCTAssertTrue(file.contains("电价P"))
        XCTAssertTrue(file.contains("全场灯数N"))
    }

    private func tableRef(_ filename: String) -> StructuredTableRef {
        StructuredTableRef(
            id: UUID(),
            filename: filename,
            relativePath: "structured/tables/\(filename)",
            fileURL: URL(fileURLWithPath: "/tmp/\(filename)"),
            schema: TableSchema(
                sheetName: "汇总",
                columns: [
                    TableColumn(name: "序号"),
                    TableColumn(name: "月份"),
                    TableColumn(name: "金额")
                ]
            ),
            isLocked: true
        )
    }
}
