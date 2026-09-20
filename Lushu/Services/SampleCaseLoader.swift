import Foundation

/// 海天×阜外停车场费用材料。bundled 子集；完整原件在 iCloud Drive「材料」。
enum SampleCaseLoader {
    static let caseTitle = "海天×阜外停车场费用材料"
    static let iCloudFolderName = "材料"
    static let iCloudPath = "/Users/lijia/Library/Mobile Documents/com~apple~CloudDocs/材料"
    static let excludedFromRepo = ["合同.pdf", "审计 PDF"]

    /// 源码旁的示例子集。`#filePath` 必须写在函数体内：默认参数会在调用点展开，
    /// 从 `LushuTests` 调用会错指到仓库根下不存在的 `Resources/SampleCase/haitian-parking`。
    static func developmentDirectory() -> URL {
        let sourceFile = URL(fileURLWithPath: #filePath)
        var dir = sourceFile.deletingLastPathComponent()
        for _ in 0..<8 {
            let besideModule = dir.appendingPathComponent("Resources/SampleCase/haitian-parking", isDirectory: true)
            if isSampleDirectory(besideModule) { return besideModule }
            let underLushu = dir.appendingPathComponent("Lushu/Resources/SampleCase/haitian-parking", isDirectory: true)
            if isSampleDirectory(underLushu) { return underLushu }
            let parent = dir.deletingLastPathComponent()
            if parent.path == dir.path { break }
            dir = parent
        }
        return sourceFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Resources/SampleCase/haitian-parking", isDirectory: true)
    }

    static let workbookResourceName = "2026年1月份到12月份阜外医院职工停车信息表"

    static func resolveDirectory() throws -> URL {
        try resolveDirectory(resourceURL: Bundle.main.resourceURL, bundle: .main)
    }

    /// 同时接受：`SampleCase/haitian-parking` 子目录，以及 Xcode 打成扁平 `Contents/Resources/*.xlsx`。
    static func resolveDirectory(
        resourceURL: URL?,
        bundle: Bundle = .main,
        includeDevelopmentFallback: Bool = true
    ) throws -> URL {
        for url in sampleDirectoryCandidates(
            resourceURL: resourceURL,
            bundle: bundle,
            includeDevelopmentFallback: includeDevelopmentFallback
        ) {
            if isSampleDirectory(url) { return url }
        }
        throw SampleCaseError.bundleMissing
    }

    static func sampleDirectoryCandidates(
        resourceURL: URL?,
        bundle: Bundle = .main,
        includeDevelopmentFallback: Bool = true
    ) -> [URL] {
        var candidates: [URL] = []
        if let resourceURL {
            candidates.append(contentsOf: [
                resourceURL.appendingPathComponent("Resources/SampleCase/haitian-parking", isDirectory: true),
                resourceURL.appendingPathComponent("SampleCase/haitian-parking", isDirectory: true),
                resourceURL.appendingPathComponent("haitian-parking", isDirectory: true),
                resourceURL
            ])
        }

        let nested = [
            "Resources/SampleCase/haitian-parking",
            "SampleCase/haitian-parking",
            "haitian-parking"
        ]
        for subdirectory in nested {
            if let file = bundle.url(
                forResource: workbookResourceName,
                withExtension: "xlsx",
                subdirectory: subdirectory
            ) {
                candidates.append(file.deletingLastPathComponent())
            }
        }
        if let flat = bundle.url(forResource: workbookResourceName, withExtension: "xlsx") {
            candidates.append(flat.deletingLastPathComponent())
        }
        if includeDevelopmentFallback {
            candidates.append(developmentDirectory())
        }

        var seen = Set<String>()
        return candidates.filter { url in
            let path = url.standardizedFileURL.path
            guard !seen.contains(path) else { return false }
            seen.insert(path)
            return true
        }
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
        if filename == "example-brief.txt" { return true }
        return false
    }

    static func exampleBrief() -> String {
        var urls: [URL] = []
        if let resolved = try? resolveDirectory() {
            urls.append(resolved.appendingPathComponent("example-brief.txt"))
        }
        urls.append(developmentDirectory().appendingPathComponent("example-brief.txt"))
        for url in urls {
            if let text = try? String(contentsOf: url, encoding: .utf8) {
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if isLetterFormBrief(trimmed) { return trimmed }
            }
        }
        return embeddedExampleBrief
    }

    /// 首页「示例」必须吃函件体要点，旧库存式 brief 会掉进 briefDriven 清单稿。
    static func isLetterFormBrief(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return trimmed.contains("测算依据")
            && (trimmed.contains("停车场电费") || trimmed.contains("参考电价"))
    }

    /// 文件缺失时的回退，与 example-brief.txt 同文，避免演示中断。
    static let embeddedExampleBrief = """
    请按乙方（海天）立场，起草《关于阜外华中心血管病医院地下停车场项目停车场电费及职工停车费测算的报告》，致河南省人民医院。

    文书目的：对合作期间乙方应缴纳的停车场电费、以及甲方应向乙方支付的职工停车费进行测算，形成可提交专项报告。

    请包含以下部分：
    1. 测算依据
    2. 停车场电费
    3. 职工停车费
    4. 测算结论

    合同约定（仅用下列已粘贴条款，不得另造条文）：
    - 《合同》第九条第七款约定：职工停车收费按3元/车/天封顶计算。
    - 《合同》第九条第八款约定：乙方自主经营、独立核算，发生的水、电等能源费用按照相关收费标准和计量数据，由乙方自行缴纳。
    - 《合同》第十条约定：乙方承担停车场运营的各项成本，包括管理人员的工资、电费、水费、设备维修费、税费等。

    计算规则：
    - 停车费以各年「职工停车信息表」汇总页「金额」列为准；有年度合计用年度合计，2026年年度合计未填则只加总已填月份，不得补空月。
    - 2018–2021年停车表不在案件包内：参照2022–2025年已确认汇总合计按48个月月均摊、再按40个月估算（方法已写明，方可估算）。
    - 照明按《2026.9.16停车场照明用电测算表》四区实测灯具功率平均后外推。负一层照明灯2596个，负二层照明灯1809个。参考电价P=0.65元/度，须注明「参考电价，最终以双方确认为准」。
    - 电费测算区间：2018年9月1日至2021年7月20日共932天；2022年2月8日至2026年9月20日共1690天。每日按24小时。

    额外约束：
    - 不引用未粘贴的合同条款，不编造法条。
    - 合同.pdf、审计件未入库，事实依据只列已入库测算表与停车信息表。
    """
}

enum SampleCaseError: LocalizedError {
    case bundleMissing

    var errorDescription: String? {
        switch self {
        case .bundleMissing:
            return "未找到示例案件材料（扁平 Resources 或 SampleCase/haitian-parking）。可改选 iCloud Drive「材料」。"
        }
    }
}
