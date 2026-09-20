import XCTest
@testable import Lushu

final class HaitianFeeReportTests: XCTestCase {
    func testDevelopmentDirectoryFindsLushuSampleCase() {
        let directory = SampleCaseLoader.developmentDirectory()
        XCTAssertTrue(SampleCaseLoader.isSampleDirectory(directory), directory.path)
        XCTAssertTrue(
            directory.path.contains("Lushu/Resources/SampleCase/haitian-parking")
                || directory.path.contains("Resources/SampleCase/haitian-parking"),
            directory.path
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.appendingPathComponent("example-brief.txt").path))
    }

    func testExampleBriefIsLetterFormSoFeeReportBuilderRuns() {
        let text = SampleCaseLoader.exampleBrief()
        XCTAssertTrue(SampleCaseLoader.isLetterFormBrief(text))
        let card = BriefCardParser.parse(text, caseID: UUID())
        XCTAssertTrue(FeeReportBuilder.isFeeReport(brief: card, kind: .customReport))
        XCTAssertFalse(text.contains("材料总结口径"))
        XCTAssertFalse(text.contains("不得自行估数或凑整"))
    }

    func testParkingLedgersMatchGoldYearTotals() throws {
        let directory = SampleCaseLoader.developmentDirectory()
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension.lowercased() == "xlsx" && !$0.lastPathComponent.hasPrefix("._") }
        XCTAssertEqual(files.count, 5)

        let tables = files.map { url in
            StructuredTableRef(
                id: UUID(),
                filename: url.lastPathComponent,
                relativePath: "structured/tables/\(url.lastPathComponent)",
                fileURL: url,
                schema: OfficeDocument.peekXLSXSchema(from: url),
                isLocked: true
            )
        }
        let ledgers = ParkingLedgerReader.read(tables: tables)
        let byYear = Dictionary(uniqueKeysWithValues: ledgers.map { ($0.year, $0) })

        XCTAssertEqual(byYear[2022]?.reportedAmount, Decimal(561930))
        XCTAssertEqual(byYear[2023]?.reportedAmount, Decimal(751350))
        XCTAssertEqual(byYear[2024]?.reportedAmount, Decimal(865794))
        XCTAssertEqual(byYear[2025]?.reportedAmount, Decimal(927147))
        XCTAssertEqual(byYear[2026]?.reportedAmount, Decimal(579123))
        XCTAssertNil(byYear[2026]?.yearTotal)
        XCTAssertTrue(byYear[2026]?.note.contains("未填") == true)
    }

    func testLightingZonesParseFourMeasuredRooms() throws {
        let directory = SampleCaseLoader.developmentDirectory()
        let docx = try XCTUnwrap(
            FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
                .first { $0.pathExtension.lowercased() == "docx" }
        )
        let text = try OfficeDocument.extractDOCX(from: docx)
        let zones = LightingMeasurementParser.zones(in: text)
        XCTAssertEqual(zones.count, 4)
        XCTAssertTrue(zones.contains { $0.watts == Decimal(string: "6.21") })
        XCTAssertTrue(zones.contains { $0.watts == Decimal(string: "7.43") })
        XCTAssertTrue(zones.contains { $0.watts == Decimal(string: "4.4") })
        XCTAssertTrue(zones.contains { $0.watts == Decimal(string: "5.38") })
    }

    func testSampleGenerateIsLetterFormWithRealTotals() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("LushuFeeReport-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let store = CasePackStore(rootURL: tmp)
        let source = try SampleCaseLoader.loadHaitianParking(into: store)
        let brief = BriefCardParser.parse(SampleCaseLoader.exampleBrief(), caseID: source.id)
        let inputs = StructuredCaseInputs(
            caseTitle: source.title,
            metadata: [:],
            tables: source.materials.compactMap { item in
                guard item.tableStatus == .realWorkbook else { return nil }
                return StructuredTableRef(
                    id: item.id,
                    filename: item.filename,
                    relativePath: item.relativePath,
                    fileURL: store.tableURL(source.pack, filename: item.filename),
                    schema: item.tableSchema ?? TableSchema(sheetName: "汇总", columns: []),
                    isLocked: true
                )
            },
            texts: source.locatedTexts
        )

        let draft = try DocumentGenerator().generate(kind: .customReport, inputs: inputs, brief: brief)
        let body = draft.plainText
        let headings = draft.sections.map(\.heading)

        XCTAssertTrue(FeeReportBuilder.isFeeReport(brief: brief, kind: .customReport))
        XCTAssertTrue(draft.title.contains("测算"))
        XCTAssertTrue(headings.contains(where: { $0.contains("测算依据") }))
        XCTAssertTrue(headings.contains(where: { $0.contains("停车场电费") }))
        XCTAssertTrue(headings.contains(where: { $0.contains("职工停车费") }))
        XCTAssertTrue(headings.contains(where: { $0.contains("测算结论") }))
        XCTAssertTrue(body.contains("561,930.00") || body.contains("561930"))
        XCTAssertTrue(body.contains("751,350.00") || body.contains("751350"))
        XCTAssertTrue(body.contains("865,794.00") || body.contains("865794"))
        XCTAssertTrue(body.contains("927,147.00") || body.contains("927147"))
        XCTAssertTrue(body.contains("579,123.00") || body.contains("579123"))
        XCTAssertTrue(body.contains("第九条第七款"))
        XCTAssertTrue(body.contains("参考电价"))
        XCTAssertTrue(body.contains("0.65"))
        XCTAssertTrue(body.contains("6.21"))
        XCTAssertTrue(body.contains("2596") || body.contains("4405"))
        XCTAssertFalse(body.contains("本稿不代算、不估数"))
        XCTAssertFalse(body.contains("任务卡 · 结构化组装 · 未接模型"))
        XCTAssertFalse(body.contains("根据刑法"))
        XCTAssertFalse(body.contains("0.85元"))
        XCTAssertFalse(body.contains("行业经验"))

        let dest = tmp.appendingPathComponent("report.docx")
        try DOCXDocumentWriter.write(draft, to: dest)
        let xml = String(data: try ZipArchive.data(named: "word/document.xml", in: dest), encoding: .utf8) ?? ""
        XCTAssertTrue(xml.contains("测算依据"))
        XCTAssertTrue(xml.contains("561"))
        XCTAssertFalse(xml.contains("根据刑法"))
    }

    func testElectricityAmountBlankWhenPriceMissing() {
        let brief = BriefCardParser.parse(
            """
            请按乙方写停车场电费及职工停车费测算报告。
            请包含：测算依据、停车场电费、职工停车费、测算结论。
            负一层照明灯2596个，负二层照明灯1809个。
            """,
            caseID: UUID()
        )
        let lighting = """
        负一层 西直梯电房  （13个灯）
        每个灯6.21瓦
        后勤保障部确认签字
        """
        let draft = FeeReportBuilder.build(
            inputs: StructuredCaseInputs(
                caseTitle: "海天×阜外停车场费用材料",
                metadata: [:],
                tables: [],
                texts: [
                    LocatedTextBlock(
                        id: UUID(),
                        locator: MaterialLocator(packID: UUID(), relativePath: "raw/测算.docx", page: nil, startOffset: 0, endOffset: lighting.count),
                        text: lighting
                    )
                ]
            ),
            brief: brief
        )
        let electricity = draft.sections.first { $0.heading.contains("电费") }?.body ?? ""
        XCTAssertTrue(electricity.contains("6.21"))
        XCTAssertTrue(electricity.contains("电费金额留空") || electricity.contains("待补"))
        XCTAssertFalse(electricity.contains("1055849.97"))
        XCTAssertFalse(electricity.contains("0.85"))
    }

    func testDoesNotInventContractArticles() {
        let brief = BriefCardParser.parse("请按乙方写停车场电费及职工停车费测算报告。", caseID: UUID())
        let draft = FeeReportBuilder.build(
            inputs: StructuredCaseInputs(caseTitle: "海天", metadata: [:], tables: [], texts: []),
            brief: brief
        )
        let basis = draft.sections.first { $0.heading.contains("测算依据") }?.body ?? ""
        XCTAssertTrue(basis.contains("不编造条文号"))
        XCTAssertFalse(basis.contains("第九条第七款"))
    }
}
