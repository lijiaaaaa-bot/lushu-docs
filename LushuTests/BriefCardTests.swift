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
        XCTAssertTrue(card.requiredSections.contains(where: { $0.contains("电费") }))
        XCTAssertTrue(card.requiredSections.contains(where: { $0.contains("测算依据") }))
        XCTAssertFalse(card.missingFacts.contains("电价P"))
        XCTAssertFalse(card.missingFacts.contains("全场灯数N"))
        XCTAssertFalse(card.calculationRules.isEmpty)
        XCTAssertTrue(card.chips.contains("乙方"))
        XCTAssertEqual(card.requiredSections.filter { $0.contains("职工停车") }.count, 1)
        XCTAssertEqual(card.requiredSections.count, 4)
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
        let lighting = "负一层 西直梯电房  （13个灯）\n每个灯6.21瓦\n后勤保障部确认签字"
        let inputs = StructuredCaseInputs(
            caseTitle: "海天×阜外停车场费用材料",
            metadata: [:],
            tables: [
                tableRef("2022年1月份到12月份阜外医院职工停车信息表.xlsx"),
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
        let headings = draft.sections.map(\.heading)

        XCTAssertTrue(draft.title.contains("测算"))
        XCTAssertTrue(headings.contains(where: { $0.contains("测算依据") }))
        XCTAssertTrue(headings.contains(where: { $0.contains("停车场电费") }))
        XCTAssertTrue(headings.contains(where: { $0.contains("职工停车费") }))
        XCTAssertTrue(headings.contains(where: { $0.contains("测算结论") }))
        XCTAssertTrue(body.contains("乙方"))
        XCTAssertTrue(body.contains("6.21瓦"))
        XCTAssertTrue(body.contains("2018年停车信息表"))
        XCTAssertFalse(body.contains("根据刑法"))
        XCTAssertFalse(body.contains("0.85元"))
        XCTAssertFalse(body.contains("行业经验"))
        XCTAssertFalse(body.contains("本稿不代算、不估数"))
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
    func testHomeTopicsIncludeInboxAndSelectedSample() throws {
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
        XCTAssertEqual(seeded.homeMessages.last(where: { $0.role == .assistant })?.action, .offerGenerate)
        XCTAssertFalse(seeded.homeMessages.contains { $0.text.contains("材料清单") })
        let seededUser = try XCTUnwrap(seeded.homeMessages.first(where: { $0.role == .user }))
        XCTAssertFalse(seededUser.attachmentIDs.isEmpty)
        XCTAssertFalse(seeded.homeMessages.contains { $0.role == .assistant && !$0.attachmentIDs.isEmpty })
        XCTAssertGreaterThanOrEqual(seeded.homeMaterials.count, 5)

        seeded.startNewConversation()
        XCTAssertEqual(seeded.selectedTopicID, AppState.homeInboxID)
        seeded.selectTopic(seeded.sources[0].id)
        XCTAssertEqual(seeded.selectedTopicID, seeded.sources[0].id)
    }

    @MainActor
    func testHomeGenerateShowsFollowUpsWithoutInventedTotals() {
        let seeded = AppState(seedHomeSample: true)
        seeded.generateFromHome()
        let document = seeded.homeMessages.last(where: { $0.action == .downloadDraft })
        XCTAssertNotNil(document)
        XCTAssertGreaterThanOrEqual(document?.followUps.count ?? 0, 2)
        XCTAssertLessThanOrEqual(document?.followUps.count ?? 0, 3)
        XCTAssertFalse(document?.followUps.joined().contains("0.85") ?? true)
        XCTAssertFalse(seeded.currentDraft.isBlank)
        XCTAssertFalse(seeded.currentDraft.plainText.contains("0.85元"))
        XCTAssertFalse(seeded.currentDraft.chatPreviewSections.contains(where: { $0.heading.contains("清单") }))
        XCTAssertTrue(seeded.homeMessages.contains { $0.role == .user && !$0.attachmentIDs.isEmpty })
        XCTAssertFalse(seeded.homeMessages.contains { $0.role == .assistant && !$0.attachmentIDs.isEmpty })
        let caption = HomeDownloadLabel.caption(for: seeded.currentDraft)
        XCTAssertTrue(caption.hasPrefix("DOCX · "))
        XCTAssertTrue(caption.contains(seeded.currentDraft.kind.title))
        XCTAssertFalse(caption.contains("0.85"))
        let sized = HomeDownloadLabel.caption(for: seeded.currentDraft, byteCount: 12_288)
        XCTAssertTrue(sized.contains("DOCX"))
        XCTAssertTrue(sized.contains(seeded.currentDraft.kind.title))
        XCTAssertFalse(HomeDownloadLabel.caption(for: seeded.currentDraft, byteCount: 0).contains("Zero"))
    }

    func testRelatedQuestionsStayGrounded() {
        let brief = BriefCardParser.parse(SampleCaseLoader.embeddedExampleBrief, caseID: UUID())
        let tables = [
            tableRef("2022年1月份到12月份阜外医院职工停车信息表.xlsx"),
            tableRef("2026年1月份到12月份阜外医院职工停车信息表.xlsx")
        ]
        let inputs = StructuredCaseInputs(
            caseTitle: "海天×阜外停车场费用材料",
            metadata: [:],
            tables: tables,
            texts: []
        )
        let questions = BriefCardParser.relatedQuestions(card: brief, inputs: inputs)
        XCTAssertGreaterThanOrEqual(questions.count, 2)
        XCTAssertLessThanOrEqual(questions.count, 3)
        XCTAssertFalse(questions.joined().contains("0.85"))
        XCTAssertFalse(questions.joined().contains("行业经验"))
        XCTAssertTrue(questions.contains(where: { $0.contains("电价") || $0.contains("停车") }))
        let reply = BriefCardParser.followUpAcknowledge(questions[0], card: brief, inputs: inputs)
        XCTAssertFalse(reply.contains("0.85"))
        XCTAssertFalse(reply.contains("行业经验"))
    }

    @MainActor
    func testLoadSamplesAttachesFilesToExistingInboxUser() {
        let state = AppState()
        state.briefComposerText = SampleCaseLoader.embeddedExampleBrief
        state.sendHomeMessage()
        XCTAssertTrue(state.homeMessages.contains { $0.role == .user && $0.attachmentIDs.isEmpty })
        state.loadSamples(enterWorkspace: false)
        XCTAssertTrue(state.homeMessages.contains { $0.role == .user && !$0.attachmentIDs.isEmpty })
        XCTAssertFalse(state.homeMessages.contains { $0.role == .assistant && !$0.attachmentIDs.isEmpty })
    }

    @MainActor
    func testRelatedQuestionKeepsBriefCard() {
        let seeded = AppState(seedHomeSample: true)
        seeded.generateFromHome()
        let before = seeded.currentBriefCard
        let question = "先只写已入库年份的停车费部分。"
        seeded.sendRelatedQuestion(question)
        XCTAssertEqual(seeded.currentBriefCard?.sourceMessage, before?.sourceMessage)
        XCTAssertEqual(seeded.homeMessages.last(where: { $0.role == .user })?.text, question)
        XCTAssertEqual(seeded.homeMessages.filter({ $0.role == .user && !$0.attachmentIDs.isEmpty }).count, 1)
        XCTAssertFalse(seeded.homeMessages.last?.text.contains("0.85") ?? true)
    }

    func testBriefChatMessageDecodesLegacyPayload() throws {
        let json = """
        {"id":"00000000-0000-4000-8000-000000000002","role":"user","text":"乙方要点","createdAt":0}
        """
        let message = try JSONDecoder().decode(BriefChatMessage.self, from: Data(json.utf8))
        XCTAssertEqual(message.text, "乙方要点")
        XCTAssertTrue(message.attachmentIDs.isEmpty)
        XCTAssertTrue(message.followUps.isEmpty)
        XCTAssertEqual(HomeMaterialLabel.cardTitle("电缆采购合同最新.pdf"), "电缆采购合同最新.pdf")
        XCTAssertTrue(HomeMaterialLabel.cardTitle("2022年1月份到12月份阜外医院职工停车信息表.xlsx").hasSuffix(".xlsx"))
    }

    func testExampleBriefFileMatchesEmbeddedSeed() throws {
        let file = SampleCaseLoader.exampleBrief()
        XCTAssertTrue(file.contains("乙方"))
        XCTAssertTrue(file.contains("2018"))
        XCTAssertTrue(file.contains("电价P"))
        XCTAssertTrue(file.contains("0.65"))
        XCTAssertTrue(file.contains("第九条第七款"))
        XCTAssertTrue(SampleCaseLoader.isLetterFormBrief(file))
        XCTAssertTrue(FeeReportBuilder.isFeeReport(
            brief: BriefCardParser.parse(file, caseID: UUID()),
            kind: .customReport
        ))
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
