import XCTest
@testable import Lushu

final class SampleCaseTests: XCTestCase {
    func testBundledSubsetHasFiveWorkbooksAndOneDocx() throws {
        let directory = SampleCaseLoader.developmentDirectory()
        let files = try FileManager.default.contentsOfDirectory(atPath: directory.path)
            .filter { !$0.hasPrefix("._") && $0 != "source.txt" }
        let xlsx = files.filter { $0.lowercased().hasSuffix(".xlsx") }
        let docx = files.filter { $0.lowercased().hasSuffix(".docx") }
        let pdf = files.filter { $0.lowercased().hasSuffix(".pdf") }

        XCTAssertEqual(xlsx.count, 5)
        XCTAssertEqual(docx.count, 1)
        XCTAssertTrue(pdf.isEmpty, "合同.pdf / 审计件不得入库")
        XCTAssertFalse(files.contains(where: { $0.contains("合同") }))
        XCTAssertFalse(files.contains(where: { $0.contains("审计") }))
    }

    func testLoadCopiesWorkbooksAndExtractsDocxText() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("LushuSampleCase-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let store = CasePackStore(rootURL: tmp)
        let source = try SampleCaseLoader.loadHaitianParking(into: store)

        XCTAssertEqual(source.title, "海天×阜外停车场费用材料")
        XCTAssertEqual(source.materials.filter { $0.tableStatus == .realWorkbook }.count, 5)
        XCTAssertEqual(source.materials.filter { $0.kind == .docx }.count, 1)
        XCTAssertTrue(source.locationCaption.contains("材料"))

        for item in source.materials where item.tableStatus == .realWorkbook {
            let url = store.tableURL(source.pack, filename: item.filename)
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), item.filename)
            let header = try Data(contentsOf: url).prefix(2)
            XCTAssertEqual(Array(header), [0x50, 0x4B], "\(item.filename) 必须是真实 xlsx/zip")
            XCTAssertFalse(item.tableSchema?.columns.isEmpty ?? true)
        }

        let docx = try XCTUnwrap(source.materials.first { $0.kind == .docx })
        let rawURL = store.subdirectory(source.pack, CasePackLayout.raw)
            .appendingPathComponent(docx.filename)
        XCTAssertTrue(FileManager.default.fileExists(atPath: rawURL.path))

        let extract = try XCTUnwrap(source.locatedTexts.first?.text)
        XCTAssertTrue(extract.contains("负一层 西直梯电房"))
        XCTAssertTrue(extract.contains("6.21瓦"))
        XCTAssertFalse(extract.hasPrefix("已定位材料："))

        let home = MaterialItem.homeVisible(source.materials)
        XCTAssertEqual(home.filter { $0.kind == .xlsx }.count, 5)
        XCTAssertEqual(home.filter { $0.filename.contains("2026") && $0.filename.contains("停车信息") }.count, 1)
        XCTAssertEqual(home.first { $0.filename.contains("2026") && $0.filename.contains("停车信息") }?.tableStatus, .realWorkbook)
        XCTAssertFalse(home.contains { $0.kind == .xlsx && $0.layer == .raw })
        XCTAssertEqual(home.filter { $0.kind == .docx }.count, 1)
        XCTAssertNotEqual(home.first { $0.kind == .docx }?.logicalKey, home.first { $0.filename.contains("2026") && $0.kind == .xlsx }?.logicalKey)
    }

    func testHomeVisibleDropsRawWhenStructuredWorkbookExists() {
        let raw = MaterialItem(
            filename: "2026年1月份到12月份阜外医院职工停车信息表.xlsx",
            kind: .xlsx,
            byteCount: 10,
            relativePath: "raw/2026年1月份到12月份阜外医院职工停车信息表.xlsx",
            layer: .raw,
            tableStatus: .notTable
        )
        let real = MaterialItem(
            filename: "2026年1月份到12月份阜外医院职工停车信息表.xlsx",
            kind: .xlsx,
            byteCount: 10,
            relativePath: "structured/tables/2026年1月份到12月份阜外医院职工停车信息表.xlsx",
            layer: .structured,
            tableStatus: .realWorkbook
        )
        let lighting = MaterialItem(
            filename: "2026.9.16停车场照明用电测算表-新.docx",
            kind: .docx,
            byteCount: 10,
            relativePath: "raw/2026.9.16停车场照明用电测算表-新.docx",
            layer: .raw,
            tableStatus: .notTable
        )
        let visible = MaterialItem.homeVisible([raw, real, lighting])
        XCTAssertEqual(visible.count, 2)
        XCTAssertTrue(visible.contains { $0.tableStatus == .realWorkbook })
        XCTAssertFalse(visible.contains { $0.id == raw.id })
        XCTAssertTrue(visible.contains { $0.kind == .docx })
        XCTAssertEqual(raw.logicalKey, real.logicalKey)
        XCTAssertNotEqual(lighting.logicalKey, real.logicalKey)
    }

    func testDownloadSavePlanPrefersDocx() throws {
        let draft = DraftDocument.blankSummary(caseTitle: "海天×阜外")
        var filled = draft
        filled.sections[0].body = "只列真表，不编法条。"
        filled.generatedAt = Date()
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("LushuExport-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        let docx = tmp.appendingPathComponent("report.docx")
        let md = tmp.appendingPathComponent("report.md")
        try filled.markdown.write(to: md, atomically: true, encoding: .utf8)
        try DOCXDocumentWriter.write(filled, to: docx)

        let plan = DocumentExport.savePlan(docx: docx, markdown: md, draft: filled)
        XCTAssertEqual(plan.ext, "docx")
        XCTAssertTrue(plan.filename.hasSuffix(".docx"))
        XCTAssertEqual(DocumentExport.resolvedDestination(URL(fileURLWithPath: "/tmp/报告"), preferredExtension: "docx").pathExtension, "docx")
        XCTAssertTrue(ZipArchive.hasEntry(named: "word/document.xml", in: docx))
    }

    func testResolveDirectoryAcceptsFlattenedResourcesLayout() throws {
        let source = SampleCaseLoader.developmentDirectory()
        XCTAssertTrue(SampleCaseLoader.isSampleDirectory(source))

        let flat = FileManager.default.temporaryDirectory
            .appendingPathComponent("LushuFlatResources-\(UUID().uuidString)", isDirectory: true)
        let nestedRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("LushuNestedResources-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: flat)
            try? FileManager.default.removeItem(at: nestedRoot)
        }
        try FileManager.default.createDirectory(at: flat, withIntermediateDirectories: true)
        let nested = nestedRoot.appendingPathComponent("SampleCase/haitian-parking", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)

        let files = try FileManager.default.contentsOfDirectory(at: source, includingPropertiesForKeys: nil)
            .filter {
                let ext = $0.pathExtension.lowercased()
                return ext == "xlsx" || ext == "docx"
            }
        XCTAssertGreaterThanOrEqual(files.filter { $0.pathExtension.lowercased() == "xlsx" }.count, 5)
        XCTAssertGreaterThanOrEqual(files.filter { $0.pathExtension.lowercased() == "docx" }.count, 1)
        for file in files {
            try FileManager.default.copyItem(at: file, to: flat.appendingPathComponent(file.lastPathComponent))
            try FileManager.default.copyItem(at: file, to: nested.appendingPathComponent(file.lastPathComponent))
        }

        let resolvedFlat = try SampleCaseLoader.resolveDirectory(
            resourceURL: flat,
            includeDevelopmentFallback: false
        )
        XCTAssertTrue(SampleCaseLoader.isSampleDirectory(resolvedFlat))
        XCTAssertEqual(resolvedFlat.standardizedFileURL.path, flat.standardizedFileURL.path)

        let resolvedNested = try SampleCaseLoader.resolveDirectory(
            resourceURL: nestedRoot,
            includeDevelopmentFallback: false
        )
        XCTAssertTrue(SampleCaseLoader.isSampleDirectory(resolvedNested))
        XCTAssertEqual(resolvedNested.standardizedFileURL.path, nested.standardizedFileURL.path)
    }

    func testDocxExtractorMatchesFileAndDoesNotInvent() throws {
        let directory = try SampleCaseLoader.resolveDirectory()
        let docx = try XCTUnwrap(
            FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
                .first { $0.pathExtension.lowercased() == "docx" }
        )
        let text = try OfficeDocument.extractDOCX(from: docx)
        XCTAssertTrue(text.contains("停车场"))
        XCTAssertTrue(text.contains("后勤保障部确认签字"))
        XCTAssertThrowsError(try OfficeDocument.extractText(from: directory.appendingPathComponent("no-such.pdf")))
    }
}
