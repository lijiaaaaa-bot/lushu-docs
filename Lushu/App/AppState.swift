import Combine
import SwiftUI

enum WorkspaceFocus: String, Hashable {
    case materials
    case manuscript
}

@MainActor
final class AppState: ObservableObject {
    @Published var sources: [CaseSource] = []
    @Published var selectedSourceID: CaseSource.ID?
    @Published var selectedMaterialID: MaterialItem.ID?
    @Published var selectedKind: DocumentKind = .summary
    @Published var drafts: [UUID: DraftDocument] = [:]
    @Published var searchText: String = ""
    @Published var focus: WorkspaceFocus = .materials
    @Published var workstation: WorkstationStage = .importMaterials
    @Published var showOnboarding: Bool = true
    @Published var showExportSheet: Bool = false
    @Published var showSettings: Bool = false
    @Published var showUIFirstBanner: Bool = true
    @Published var showHiddenCitations: Bool = false
    @Published var toast: String?
    @Published var isGenerating: Bool = false
    @Published var isStructuring: Bool = false
    @Published var previewMode: Bool = true
    @Published var lastStructureMessage: String?

    let packStore = CasePackStore()
    let corpus = LegalCorpus()
    private var generator: DocumentGenerator { DocumentGenerator(corpus: corpus) }

    var selectedSource: CaseSource? {
        sources.first(where: { $0.id == selectedSourceID })
    }

    var currentDraft: DraftDocument {
        guard let id = selectedSourceID else {
            return DraftDocument.blankSummary(caseTitle: "未选择案件")
        }
        return drafts[id] ?? DraftDocument.blankSummary(caseTitle: selectedSource?.title ?? "未选择案件")
    }

    var visibleSources: [CaseSource] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return sources }
        return sources.filter {
            $0.title.localizedCaseInsensitiveContains(query)
                || $0.locationCaption.localizedCaseInsensitiveContains(query)
        }
    }

    var visibleMaterials: [MaterialItem] {
        guard let source = selectedSource else { return [] }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return source.materials }
        return source.materials.filter {
            $0.filename.localizedCaseInsensitiveContains(query)
                || $0.relativePath.localizedCaseInsensitiveContains(query)
        }
    }

    var unfiledMaterials: [MaterialItem] { visibleMaterials.filter { !$0.included } }
    var rawMaterials: [MaterialItem] { visibleMaterials.filter { $0.included && $0.layer == .raw } }
    var structuredMaterials: [MaterialItem] { visibleMaterials.filter { $0.included && $0.layer == .structured } }

    init(
        seedSamples: Bool = false,
        seedDrafts: Bool = false,
        seedFocus: WorkspaceFocus = .materials
    ) {
        if seedSamples {
            loadSamples()
        }
        if seedDrafts, let source = selectedSource {
            do {
                try preparePack(source)
                _ = try runStructuring(on: source, lock: true)
                try generateFromStructuredInputs()
            } catch {
                flash(error.localizedDescription)
            }
        }
        if seedSamples {
            focus = seedFocus
            if seedFocus == .manuscript {
                workstation = .document
            }
        }
    }

    func loadSamples() {
        let samples = [SampleData.laborDispute(), SampleData.houseContract()]
        sources = samples
        selectedSourceID = samples.first?.id
        showOnboarding = false
        focus = .materials
        workstation = .importMaterials
        for sample in samples {
            drafts[sample.id] = DraftDocument.blankSummary(caseTitle: sample.title)
            try? preparePack(sample)
        }
    }

    func chooseAnxiaFolder() {
        ingestDemoSource(SampleData.laborDispute(), note: "已载入案匣示例。真实选文件夹与书签下一轮接入。")
    }

    func importFiles() {
        ingestDemoSource(
            rewritten(SampleData.houseContract(), origin: .importedFiles, caption: "导入 · 所选文件"),
            note: "已载入导入文件示例。系统多选下一轮接入。"
        )
    }

    func importFolder() {
        ingestDemoSource(
            SampleData.houseContract(),
            note: "已载入导入文件夹示例。系统选文件夹下一轮接入。"
        )
    }

    func selectSource(_ id: CaseSource.ID) {
        selectedSourceID = id
        selectedMaterialID = nil
        focus = .materials
        workstation = .importMaterials
        if drafts[id] == nil, let source = sources.first(where: { $0.id == id }) {
            drafts[id] = DraftDocument.blankSummary(caseTitle: source.title)
            try? preparePack(source)
        }
    }

    func removeSource(_ id: CaseSource.ID) {
        sources.removeAll { $0.id == id }
        drafts[id] = nil
        if selectedSourceID == id {
            selectedSourceID = sources.first?.id
            selectedMaterialID = nil
        }
        if sources.isEmpty {
            showOnboarding = true
            focus = .materials
            workstation = .importMaterials
        }
    }

    func chooseKind(_ kind: DocumentKind) {
        if kind.isAvailable {
            selectedKind = kind
            workstation = .document
            return
        }
        flash("「\(kind.title)」为后续文书类型，本轮仅开放材料总结。")
    }

    func setWorkstation(_ stage: WorkstationStage) {
        workstation = stage
        switch stage {
        case .importMaterials, .structure:
            focus = .materials
        case .document:
            focus = .manuscript
            showHiddenCitations = false
        case .provenance:
            focus = .manuscript
            showHiddenCitations = true
        }
    }

    func pickMaterials() {
        setWorkstation(.importMaterials)
        if sources.isEmpty {
            showOnboarding = true
        }
    }

    func structureSelectedCase() {
        guard let source = selectedSource else {
            flash("请先导入材料。")
            setWorkstation(.importMaterials)
            return
        }
        setWorkstation(.structure)
        isStructuring = true
        Task {
            do {
                try preparePack(source)
                let result = try runStructuring(on: source, lock: true)
                lastStructureMessage = result.job.message
                flash(result.job.message ?? "已写出真表。")
            } catch {
                flash(error.localizedDescription)
            }
            isStructuring = false
        }
    }

    func composeDocument() {
        guard selectedSource != nil else {
            flash("请先选材料。")
            pickMaterials()
            return
        }
        if !selectedKind.isAvailable {
            flash("「\(selectedKind.title)」尚未开放生稿。")
            selectedKind = .summary
        }
        setWorkstation(.document)
        do {
            try generateFromStructuredInputs()
        } catch let error as DocumentGenerationError {
            flash(error.localizedDescription)
            if case .unstructuredInputsRejected = error {
                setWorkstation(.structure)
            }
        } catch {
            flash(error.localizedDescription)
        }
    }

    func exportDocument() {
        if currentDraft.isBlank {
            flash("请先成文书，再导出。")
            return
        }
        showExportSheet = true
    }

    func openStructuredWorkbook(_ item: MaterialItem) {
        guard item.tableStatus == .realWorkbook else {
            flash("此件还是待结构化，没有可打开的真表。")
            return
        }
        flash("将打开 \(item.workbookRelativePath ?? item.relativePath)。系统打开下一轮接入。")
    }

    func revealProvenance() {
        setWorkstation(.provenance)
        if currentDraft.citations.isEmpty {
            flash("本稿未绑定 LegalCitation。法索语料未接入前，不写入条文。")
        }
    }

    func tryAttachDemoCitation() {
        let bogus = LegalCitation(
            lawID: "prc.civil-code",
            lawTitle: "中华人民共和国民法典",
            articleNum: "0",
            quote: "",
            sourceSpan: SourceSpan(start: 0, end: 0, unit: .articleOffset)
        )
        guard let sourceID = selectedSourceID, var draft = drafts[sourceID] else { return }
        do {
            try generator.bindCitation(bogus, to: &draft)
            drafts[sourceID] = draft
        } catch {
            flash(error.localizedDescription)
        }
    }

    func requestLLMPolish() {
        flash("大模型润色将读取钥匙串中的密钥。本轮不接线，本地摘要仍可用。")
        showSettings = true
    }

    func updateSection(id: DraftSection.ID, body: String) {
        guard let sourceID = selectedSourceID, var draft = drafts[sourceID] else { return }
        if let index = draft.sections.firstIndex(where: { $0.id == id }) {
            draft.sections[index].body = body
            drafts[sourceID] = draft
        }
    }

    func flash(_ message: String) {
        toast = message
        Task {
            try? await Task.sleep(nanoseconds: 3_200_000_000)
            if toast == message {
                toast = nil
            }
        }
    }

    private func structuredInputs(for source: CaseSource) -> StructuredCaseInputs {
        let tables: [StructuredTableRef] = source.materials.compactMap { item in
            guard item.tableStatus == .realWorkbook else { return nil }
            let filename = item.filename
            let url = packStore.tableURL(source.pack, filename: filename)
            return StructuredTableRef(
                id: item.id,
                filename: filename,
                relativePath: item.workbookRelativePath ?? item.relativePath,
                fileURL: url,
                schema: item.tableSchema ?? TableSchema(sheetName: "表1", columns: []),
                isLocked: item.tableLocked
            )
        }
        return StructuredCaseInputs(
            caseTitle: source.title,
            metadata: ["origin": source.origin.title],
            tables: tables,
            texts: source.locatedTexts
        )
    }

    private func generateFromStructuredInputs() throws {
        guard let source = selectedSource else {
            throw DocumentGenerationError.unstructuredInputsRejected
        }
        let inputs = structuredInputs(for: source)
        let draft = try generator.generate(kind: selectedKind, inputs: inputs)
        drafts[source.id] = draft
        try? packStore.writeDraft(source.pack, draft: draft)
        previewMode = true
        focus = .manuscript
        workstation = .document
        flash("已根据结构化案件包生成本地摘要。未写入任何法条。")
    }

    @discardableResult
    private func runStructuring(on source: CaseSource, lock: Bool) throws -> TableStructuringResult {
        let pending = source.materials.filter { $0.tableStatus == .pendingStructure }
        guard let first = pending.first else {
            if source.materials.contains(where: { $0.tableStatus == .realWorkbook }) {
                let existing = source.materials.first { $0.tableStatus == .realWorkbook }!
                let url = packStore.tableURL(source.pack, filename: existing.filename)
                return TableStructuringResult(
                    job: TableStructuringJob(
                        id: UUID(),
                        packID: source.pack.id,
                        input: .workbook(relativePath: existing.relativePath),
                        suggestedFilename: existing.filename,
                        status: .locked,
                        outputRelativePath: existing.workbookRelativePath,
                        schema: existing.tableSchema,
                        locked: true,
                        message: "已有锁定真表。"
                    ),
                    workbookURL: url,
                    schema: existing.tableSchema ?? TableSchema(sheetName: "表1", columns: [])
                )
            }
            throw DocumentGenerationError.unstructuredInputsRejected
        }

        let job = TableStructuringJob(
            id: UUID(),
            packID: source.pack.id,
            input: .pdfRegion(relativePath: first.relativePath, page: 1, note: "示例框选"),
            suggestedFilename: suggestedWorkbookName(from: first.filename),
            status: .pending,
            outputRelativePath: nil,
            schema: nil,
            locked: false,
            message: nil
        )
        let service = TableStructuringService(store: packStore)
        var result = try service.run(job, pack: source.pack)
        if lock {
            result = service.lock(result)
        }
        apply(result, to: source.id, replacing: first.id)
        writeLocatorTexts(for: source.id)
        return result
    }

    private func apply(_ result: TableStructuringResult, to sourceID: UUID, replacing rawID: UUID) {
        guard let index = sources.firstIndex(where: { $0.id == sourceID }) else { return }
        if let raw = sources[index].materials.firstIndex(where: { $0.id == rawID }) {
            sources[index].materials[raw].tableStatus = .pendingStructure
        }
        let structured = MaterialItem(
            filename: result.workbookURL.lastPathComponent,
            kind: .xlsx,
            byteCount: (try? result.workbookURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0,
            relativePath: result.job.outputRelativePath ?? result.workbookURL.lastPathComponent,
            included: true,
            layer: .structured,
            tableStatus: .realWorkbook,
            workbookRelativePath: result.job.outputRelativePath,
            tableSchema: result.schema,
            tableLocked: result.job.locked
        )
        sources[index].materials.removeAll { $0.filename == structured.filename && $0.layer == .structured }
        sources[index].materials.append(structured)
    }

    private func writeLocatorTexts(for sourceID: UUID) {
        guard let index = sources.firstIndex(where: { $0.id == sourceID }) else { return }
        let source = sources[index]
        let blocks: [LocatedTextBlock] = source.materials.filter { $0.layer == .raw && $0.included }.map { item in
            LocatedTextBlock(
                id: UUID(),
                locator: MaterialLocator(
                    packID: source.pack.id,
                    relativePath: item.relativePath,
                    page: item.kind == .pdf ? 1 : nil,
                    startOffset: 0,
                    endOffset: 0
                ),
                text: "已定位材料：\(item.filename)"
            )
        }
        sources[index].locatedTexts = blocks
        try? packStore.writeTextBlocks(source.pack, filename: "blocks.jsonl", blocks: blocks)
        try? packStore.writeCitations(source.pack, citations: [])
    }

    private func suggestedWorkbookName(from filename: String) -> String {
        let stem = (filename as NSString).deletingPathExtension
        return "\(stem).xlsx"
    }

    private func preparePack(_ source: CaseSource) throws {
        try packStore.createSkeleton(source.pack)
        for item in source.materials where item.layer == .raw {
            try packStore.writeRawPlaceholder(source.pack, filename: item.filename)
        }
    }

    private func ingestDemoSource(_ source: CaseSource, note: String) {
        var incoming = source
        incoming.id = UUID()
        incoming.pack = CasePack.make(id: incoming.id, title: incoming.title)
        incoming.lastOpenedAt = Date()
        sources.insert(incoming, at: 0)
        drafts[incoming.id] = DraftDocument.blankSummary(caseTitle: incoming.title)
        try? preparePack(incoming)
        selectedSourceID = incoming.id
        selectedMaterialID = nil
        focus = .materials
        workstation = .importMaterials
        showOnboarding = false
        flash(note)
    }

    private func rewritten(_ source: CaseSource, origin: SourceOrigin, caption: String) -> CaseSource {
        var copy = source
        copy.origin = origin
        copy.locationCaption = caption
        return copy
    }
}
