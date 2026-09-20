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
