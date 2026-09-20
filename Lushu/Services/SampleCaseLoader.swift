import Foundation

/// 海天×阜外停车场费用材料。bundled 子集；完整原件在 iCloud Drive「材料」。
enum SampleCaseLoader {
    static let caseTitle = "海天×阜外停车场费用材料"
    static let iCloudFolderName = "材料"
    static let iCloudPath = "/Users/lijia/Library/Mobile Documents/com~apple~CloudDocs/材料"
    static let excludedFromRepo = ["合同.pdf", "审计 PDF"]

    static func developmentDirectory(filePath: String = #filePath) -> URL {
        URL(fileURLWithPath: filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Resources/SampleCase/haitian-parking", isDirectory: true)
    }

    static func resolveDirectory() throws -> URL {
        let candidates = [
            Bundle.main.resourceURL?.appendingPathComponent("Resources/SampleCase/haitian-parking"),
            Bundle.main.resourceURL?.appendingPathComponent("SampleCase/haitian-parking"),
            Bundle.main.url(forResource: "2026年1月份到12月份阜外医院职工停车信息表", withExtension: "xlsx", subdirectory: "Resources/SampleCase/haitian-parking")?.deletingLastPathComponent(),
            Bundle.main.url(forResource: "2026年1月份到12月份阜外医院职工停车信息表", withExtension: "xlsx", subdirectory: "SampleCase/haitian-parking")?.deletingLastPathComponent(),
            developmentDirectory()
        ]
        for url in candidates.compactMap({ $0 }) {
            if isSampleDirectory(url) { return url }
        }
        throw SampleCaseError.bundleMissing
    }

    static func isSampleDirectory(_ url: URL) -> Bool {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(atPath: url.path) else { return false }
        let xlsx = files.filter { $0.lowercased().hasSuffix(".xlsx") && !$0.hasPrefix("._") }
        let docx = files.filter { $0.lowercased().hasSuffix(".docx") && !$0.hasPrefix("._") }
        return xlsx.count >= 5 && docx.count >= 1
    }

    static func loadHaitianParking(into store: CasePackStore) throws -> CaseSource {
        let directory = try resolveDirectory()
        let id = UUID(uuidString: "A3333333-3333-3333-3333-333333333333") ?? UUID()
        let pack = CasePack.make(id: id, title: caseTitle)
        try store.createSkeleton(pack)

        let fm = FileManager.default
        let urls = try fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles])
            .filter { !$0.lastPathComponent.hasPrefix("._") }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }

        var materials: [MaterialItem] = []
        var texts: [LocatedTextBlock] = []

        for url in urls {
            let name = url.lastPathComponent
            if shouldSkipForBundle(name) { continue }
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            switch MaterialKind.from(filename: name) {
            case .xlsx:
                let dest = store.tableURL(pack, filename: name)
                try store.copyReplacing(from: url, to: dest)
                let schema = OfficeDocument.peekXLSXSchema(from: dest)
                let relative = "\(CasePackLayout.structuredTables)/\(name)"
                materials.append(
                    MaterialItem(
                        filename: name,
                        kind: .xlsx,
                        byteCount: size,
                        relativePath: relative,
                        included: true,
                        layer: .structured,
                        tableStatus: .realWorkbook,
                        workbookRelativePath: relative,
                        tableSchema: schema,
                        tableLocked: true
                    )
                )
            case .docx:
                let dest = store.subdirectory(pack, CasePackLayout.raw).appendingPathComponent(name)
                try store.copyReplacing(from: url, to: dest)
                let relative = "\(CasePackLayout.raw)/\(name)"
                materials.append(
                    MaterialItem(
                        filename: name,
                        kind: .docx,
                        byteCount: size,
                        relativePath: relative,
                        included: true,
                        layer: .raw,
                        tableStatus: .notTable
                    )
                )
                let extracted = try OfficeDocument.extractDOCX(from: dest)
                texts.append(
                    LocatedTextBlock(
                        id: UUID(),
                        locator: MaterialLocator(
                            packID: pack.id,
                            relativePath: relative,
                            page: nil,
                            startOffset: 0,
                            endOffset: extracted.count
                        ),
                        text: extracted
                    )
                )
            default:
                continue
            }
        }

        guard materials.contains(where: { $0.tableStatus == .realWorkbook }) else {
            throw SampleCaseError.bundleMissing
        }

        try store.writeTextBlocks(pack, filename: "blocks.jsonl", blocks: texts)
        try store.writeCitations(pack, citations: [])

        return CaseSource(
            id: id,
            title: caseTitle,
            origin: .anxiaFolder,
            locationCaption: "示例子集 · 完整原件：iCloud Drive「\(iCloudFolderName)」",
            materials: materials,
            locatedTexts: texts,
            pack: pack,
            isSample: true,
            lastOpenedAt: Date()
        )
    }

    static func shouldSkipForBundle(_ filename: String) -> Bool {
        let lower = filename.lowercased()
        if lower.hasSuffix(".pdf") { return true }
        if filename.contains("合同") { return true }
        if filename.contains("审计") { return true }
        if filename == "source.txt" { return true }
        return false
    }
}

enum SampleCaseError: LocalizedError {
    case bundleMissing

    var errorDescription: String? {
        switch self {
        case .bundleMissing:
            return "未找到 Resources/SampleCase/haitian-parking。可改选 iCloud Drive「材料」。"
        }
    }
}
