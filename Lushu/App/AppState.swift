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
    @Published var briefChats: [UUID: CaseBriefChat] = [:]
    @Published var briefComposerText: String = ""
    @Published var showBriefChat: Bool = true
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
    @Published var openedChunk: LegalChunk?
    @Published var hasDeepSeekKey: Bool = false
    @Published var maskedDeepSeekKey: String?

    /// 尚未挂上 CasePack 时，首页对话暂存在此。挂上案件后并入该案。
    static let homeInboxID = UUID(uuidString: "A0000000-0000-4000-8000-000000000001")!

    let packStore = CasePackStore()
    let corpus: LegalCorpus
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

    var homeMaterials: [MaterialItem] {
        MaterialItem.homeVisible(selectedSource?.materials ?? [])
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

    var currentBriefChat: CaseBriefChat? {
        guard let id = selectedSourceID else { return nil }
        return briefChats[id]
    }

    var currentBriefCard: BriefCard? { currentBriefChat?.card }

    var hasActionableBrief: Bool { currentBriefCard?.isActionable == true }

    var homeChat: CaseBriefChat {
        if let id = selectedSourceID, let chat = briefChats[id] {
            return chat
        }
        return briefChats[Self.homeInboxID] ?? CaseBriefChat(caseID: Self.homeInboxID)
    }

    var homeMessages: [BriefChatMessage] { homeChat.messages }

    var canGenerateFromHome: Bool {
        selectedSource != nil
            && hasActionableBrief
            && !(selectedSource?.materials.isEmpty ?? true)
    }

    init(
        seedSamples: Bool = false,
        seedDrafts: Bool = false,
        seedFocus: WorkspaceFocus = .materials,
        seedHomeSample: Bool = false
    ) {
        corpus = LegalCorpus.loadPreferred()
        refreshDeepSeekKeyStatus()
        briefChats[Self.homeInboxID] = CaseBriefChat(caseID: Self.homeInboxID)
        if seedHomeSample {
            loadSamples(enterWorkspace: false)
            return
        }
        if seedSamples {
            loadSamples(enterWorkspace: true)
        }
        if seedDrafts, selectedSource != nil {
            do {
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

    func loadSamples(enterWorkspace: Bool = false) {
        do {
            let sample = try SampleData.haitianParking(into: packStore)
            sources = [sample]
            selectedSourceID = sample.id
            drafts[sample.id] = DraftDocument.blankSummary(caseTitle: sample.title)
            adoptInboxOrSeedExample(onto: sample)
            selectedKind = .customReport
            showBriefChat = true
            if enterWorkspace {
                revealWorkspace()
            } else {
                showOnboarding = true
            }
            briefComposerText = ""
            flash("已挂上示例子集：\(sample.title)。完整原件在 iCloud Drive「材料」。")
        } catch {
            flash(error.localizedDescription)
        }
    }

    func chooseAnxiaFolder() {
        flash("请选取 iCloud Drive「\(SampleCaseLoader.iCloudFolderName)」：\(SampleCaseLoader.iCloudPath)。完整原件含合同.pdf 与审计件（未入库）。系统选文件夹下一轮接入。")
        appendHomeAssistant("选文件夹下一轮接入。可先点「示例」。")
    }

    func importFiles() {
        flash("可从 iCloud Drive「材料」导入文件。系统多选下一轮接入。大体积合同.pdf / 审计件不要提交进仓库。")
        appendHomeAssistant("导入下一轮接入。可先点「示例」。")
    }

    func importFolder() {
        flash("请选取 iCloud Drive「材料」文件夹。系统选文件夹下一轮接入。")
        appendHomeAssistant("选文件夹下一轮接入。可先点「示例」。")
    }

    func selectSource(_ id: CaseSource.ID) {
        selectedSourceID = id
        selectedMaterialID = nil
        focus = .materials
        workstation = .importMaterials
        briefComposerText = ""
        if drafts[id] == nil, let source = sources.first(where: { $0.id == id }) {
            drafts[id] = DraftDocument.blankSummary(caseTitle: source.title)
            try? preparePack(source)
        }
        if briefChats[id] == nil {
            briefChats[id] = CaseBriefChat(caseID: id)
        }
    }

    func removeSource(_ id: CaseSource.ID) {
        sources.removeAll { $0.id == id }
        drafts[id] = nil
        briefChats[id] = nil
        if selectedSourceID == id {
            selectedSourceID = sources.first?.id
            selectedMaterialID = nil
        }
        if sources.isEmpty {
            selectedSourceID = nil
            returnToHome()
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
        flash("「\(kind.title)」为后续文书类型，本轮开放材料总结与专项报告。")
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
            returnToHome()
        }
    }

    func revealWorkspace() {
        guard !sources.isEmpty else {
            flash("先挂上案件材料，再进工作区。")
            returnToHome()
            return
        }
        showOnboarding = false
        focus = .manuscript
        workstation = .document
        showBriefChat = true
    }

    func returnToHome() {
        showOnboarding = true
        showHiddenCitations = false
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
        downloadGeneratedDocument()
    }

    func downloadGeneratedDocument() {
        guard let source = selectedSource, let draft = drafts[source.id], !draft.isBlank else {
            flash("还没有可下载的文书。")
            return
        }
        do {
            try packStore.writeDraft(source.pack, draft: draft)
            try DocumentExport.saveUserCopy(
                docx: packStore.draftDOCXURL(source.pack, draft: draft),
                markdown: packStore.draftMarkdownURL(source.pack, draft: draft),
                draft: draft
            )
            flash("已提供下载。草稿仍在案件包 drafts/。")
        } catch {
            flash(error.localizedDescription)
        }
    }

    var hasGeneratedDraft: Bool {
        guard selectedSourceID != nil else { return false }
        return !currentDraft.isBlank
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
        if !corpus.isKnowledgeLinked {
            flash("未找到 LegalKnowledge 子集。拒绝编造条文。")
        } else if currentDraft.citations.isEmpty {
            flash("本稿未绑定引用。可在溯源工位打开语料原文，默认不写进稿面。")
        }
    }

    func openCorpusArticle(id: String) {
        do {
            openedChunk = try corpus.lookup(articleID: id)
            setWorkstation(.provenance)
        } catch {
            openedChunk = nil
            flash(error.localizedDescription)
        }
    }

    func bindHiddenCitation(articleID: String) {
        guard let sourceID = selectedSourceID, var draft = drafts[sourceID] else { return }
        do {
            let citation = try corpus.makeHiddenCitation(articleID: articleID)
            try generator.bindCitation(citation, to: &draft)
            drafts[sourceID] = draft
            openedChunk = try corpus.lookup(articleID: articleID)
            flash("已绑定隐藏引用 \(articleID)。稿面不展示，溯源可打开原文。")
        } catch {
            flash(error.localizedDescription)
        }
    }

    func tryAttachDemoCitation() {
        bindHiddenCitation(articleID: "刑法/第一条")
    }

    func refreshDeepSeekKeyStatus() {
        hasDeepSeekKey = APIKeyStore.hasDeepSeekKey()
        maskedDeepSeekKey = APIKeyStore.maskedDeepSeekKey()
    }

    func saveDeepSeekKey(_ raw: String) throws {
        try APIKeyStore.saveDeepSeekKey(raw)
        refreshDeepSeekKeyStatus()
        flash("DeepSeek 密钥已写入钥匙串。")
    }

    func clearDeepSeekKey() throws {
        try APIKeyStore.clearDeepSeekKey()
        refreshDeepSeekKeyStatus()
        flash("已清除 DeepSeek 密钥。")
    }

    func requestLLMPolish() {
        guard let sourceID = selectedSourceID, let draft = drafts[sourceID], !draft.isBlank else {
            flash("没有已落稿的事实可润色。润色不得增补数字或未校验法条。")
            return
        }
        refreshDeepSeekKeyStatus()
        guard hasDeepSeekKey, let key = try? APIKeyStore.readDeepSeekKey(), !key.isEmpty else {
            flash(GroundedLLM.missingKeyHint)
            showSettings = true
            return
        }
        isGenerating = true
        Task {
            do {
                let text = try await DeepSeekClient().complete(messages: GroundedLLM.polishMessages(draft: draft), key: key)
                applyPolishedMarkdown(text, to: sourceID)
                flash("已用 DeepSeek 润色措辞。未增补数字或法条。")
            } catch {
                flash(error.localizedDescription)
            }
            isGenerating = false
        }
    }

    func fillExampleBrief() {
        briefComposerText = SampleCaseLoader.exampleBrief()
        sendHomeMessage()
    }

    func useHaitianPromptChip() {
        briefChats[Self.homeInboxID] = CaseBriefChat(caseID: Self.homeInboxID)
        if selectedSource == nil {
            loadSamples(enterWorkspace: false)
        } else {
            briefComposerText = SampleCaseLoader.exampleBrief()
            sendHomeMessage()
        }
    }

    func useSummaryPromptChip() {
        briefComposerText = """
        请按中立立场写一份材料总结。文书目的：整理已结构化材料清单与已定位文本。
        请包含：案件概要、材料清单、事实要点、待补材料与缺口。
        约束：不编造法条，不估未读出的单元格金额。
        """
        sendHomeMessage()
    }

    func sendHomeMessage() {
        let incoming = briefComposerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !incoming.isEmpty else {
            flash("先写入长要点。")
            return
        }
        if selectedSource != nil {
            updateBriefCard(revealWorkspace: false)
            return
        }
        var chat = briefChats[Self.homeInboxID] ?? CaseBriefChat(caseID: Self.homeInboxID)
        chat.card = BriefCardParser.parse(incoming, caseID: Self.homeInboxID, existing: chat.card)
        chat.messages.append(BriefChatMessage(role: .user, text: BriefCardParser.shortUserPreview(incoming, card: chat.card)))
        chat.messages.append(
            BriefChatMessage(role: .assistant, text: BriefCardParser.shortAcknowledge(chat.card))
        )
        briefChats[Self.homeInboxID] = chat
        briefComposerText = ""
        flash("已记下要点。请挂上案件材料。")
    }

    func updateBriefCard(revealWorkspace: Bool = false) {
        guard let source = selectedSource else {
            sendHomeMessage()
            return
        }
        var chat = briefChats[source.id] ?? CaseBriefChat(caseID: source.id)
        let incoming = briefComposerText.trimmingCharacters(in: .whitespacesAndNewlines)
        let sourceText = incoming.isEmpty ? chat.card.sourceMessage : incoming
        guard !sourceText.isEmpty else {
            flash("先写入长要点，再更新任务卡。")
            return
        }
        if !incoming.isEmpty {
            chat.card = BriefCardParser.parse(incoming, caseID: source.id, existing: chat.card)
            chat.messages.append(BriefChatMessage(role: .user, text: BriefCardParser.shortUserPreview(incoming, card: chat.card)))
            briefComposerText = ""
        } else {
            chat.card = BriefCardParser.parse(sourceText, caseID: source.id, existing: chat.card)
        }
        let inputs = structuredInputs(for: source)
        chat.messages.append(BriefChatMessage(role: .assistant, text: BriefCardParser.shortAcknowledge(chat.card, inputs: inputs)))
        briefChats[source.id] = chat
        try? packStore.writeBriefChat(source.pack, chat: chat)
        if revealWorkspace {
            setWorkstation(.document)
        }
        flash("任务卡已更新。生成仍只吃结构化材料。")
    }

    func generateFromBrief() {
        generateFromHome()
    }

    func generateFromHome() {
        if !briefComposerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            updateBriefCard(revealWorkspace: false)
        }
        guard selectedSource != nil else {
            flash("先挂上案件材料，再生成文书。")
            return
        }
        if let card = currentBriefCard, card.isActionable, card.documentPurpose.contains("报告") {
            selectedKind = .customReport
        }
        do {
            try generateFromStructuredInputs(announceDownload: true)
            maybePolishAfterGenerate()
        } catch let error as DocumentGenerationError {
            flash(error.localizedDescription)
            if case .unstructuredInputsRejected = error {
                setWorkstation(.structure)
                revealWorkspace()
            }
        } catch {
            flash(error.localizedDescription)
        }
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

    private func generateFromStructuredInputs(announceDownload: Bool = false) throws {
        guard let source = selectedSource else {
            throw DocumentGenerationError.unstructuredInputsRejected
        }
        let inputs = structuredInputs(for: source)
        let brief = briefChats[source.id]?.card
        let draft = try generator.generate(kind: selectedKind, inputs: inputs, brief: brief)
        drafts[source.id] = draft
        try? packStore.writeDraft(source.pack, draft: draft)
        if announceDownload {
            appendAssistant(
                "已生成\(selectedKind.title) · 点此下载",
                to: source.id,
                action: .downloadDraft
            )
            showOnboarding = true
        }
        previewMode = true
        focus = .manuscript
        workstation = .document
        showBriefChat = true
        flash(brief?.isActionable == true ? "已按任务卡组装文书。未编造法条或台账数字。" : "已根据结构化案件包生成本地摘要。未写入任何法条。")
    }

    private func seedExampleBrief(for source: CaseSource) {
        let text = SampleCaseLoader.exampleBrief()
        var chat = CaseBriefChat(caseID: source.id)
        let inputs = structuredInputs(for: source)
        chat.card = BriefCardParser.parse(text, caseID: source.id)
        chat.messages = [
            BriefChatMessage(role: .user, text: BriefCardParser.shortUserPreview(text, card: chat.card)),
            BriefChatMessage(role: .assistant, text: BriefCardParser.shortAcknowledge(chat.card, inputs: inputs))
        ]
        briefChats[source.id] = chat
        try? packStore.writeBriefChat(source.pack, chat: chat)
        briefComposerText = ""
    }

    private func adoptInboxOrSeedExample(onto source: CaseSource) {
        let inbox = briefChats[Self.homeInboxID]
        if let inbox, inbox.hasCard || !inbox.messages.isEmpty {
            var chat = CaseBriefChat(caseID: source.id)
            chat.messages = inbox.messages
            let raw = inbox.card.sourceMessage.isEmpty
                ? (inbox.messages.last(where: { $0.role == .user })?.text ?? SampleCaseLoader.exampleBrief())
                : inbox.card.sourceMessage
            chat.card = BriefCardParser.parse(raw, caseID: source.id)
            let inputs = structuredInputs(for: source)
            chat.messages = chat.messages.map { message in
                if message.role == .user, message.text.count > 40 {
                    return BriefChatMessage(id: message.id, role: .user, text: BriefCardParser.shortUserPreview(message.text, card: chat.card), createdAt: message.createdAt, action: message.action)
                }
                return message
            }
            chat.messages.append(
                BriefChatMessage(role: .assistant, text: BriefCardParser.shortAcknowledge(chat.card, inputs: inputs))
            )
            briefChats[source.id] = chat
            briefChats[Self.homeInboxID] = CaseBriefChat(caseID: Self.homeInboxID)
            try? packStore.writeBriefChat(source.pack, chat: chat)
            briefComposerText = ""
        } else {
            seedExampleBrief(for: source)
        }
    }

    private func appendHomeAssistant(_ text: String) {
        appendAssistant(text, to: selectedSourceID ?? Self.homeInboxID)
    }

    private func appendAssistant(_ text: String, to caseID: UUID, action: BriefChatAction? = nil) {
        var chat = briefChats[caseID] ?? CaseBriefChat(caseID: caseID)
        chat.messages.append(BriefChatMessage(role: .assistant, text: text, action: action))
        briefChats[caseID] = chat
        if let source = sources.first(where: { $0.id == caseID }) {
            try? packStore.writeBriefChat(source.pack, chat: chat)
        }
    }

    private func maybePolishAfterGenerate() {
        refreshDeepSeekKeyStatus()
        guard hasDeepSeekKey else { return }
        requestLLMPolish()
    }

    private func applyPolishedMarkdown(_ markdown: String, to sourceID: UUID) {
        guard var draft = drafts[sourceID] else { return }
        var changed = false
        for index in draft.sections.indices {
            let heading = draft.sections[index].heading
            if let body = Self.extractMarkdownSection(heading, from: markdown), !body.isEmpty {
                draft.sections[index].body = body
                changed = true
            }
        }
        guard changed else {
            flash("DeepSeek 回文无法按原章节套回，未改本地稿。")
            return
        }
        if !draft.generatorLabel.contains("DeepSeek") {
            draft.generatorLabel += " · DeepSeek 措辞"
        }
        drafts[sourceID] = draft
        if let source = sources.first(where: { $0.id == sourceID }) {
            try? packStore.writeDraft(source.pack, draft: draft)
        }
    }

    private static func extractMarkdownSection(_ heading: String, from markdown: String) -> String? {
        let lines = markdown.components(separatedBy: .newlines)
        var collecting = false
        var body: [String] = []
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("#") {
                let title = trimmed.replacingOccurrences(of: #"^#+\s*"#, with: "", options: .regularExpression)
                if collecting { break }
                collecting = title.contains(heading) || heading.contains(title)
                continue
            }
            if collecting { body.append(line) }
        }
        let text = body.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
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
            if let existing = source.locatedTexts.first(where: { $0.locator.relativePath == item.relativePath }),
               !existing.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               !existing.text.hasPrefix("已定位材料：") {
                return existing
            }
            let fileURL = packStore.subdirectory(source.pack, CasePackLayout.raw)
                .appendingPathComponent(item.filename)
            if item.kind == .docx, let extracted = try? OfficeDocument.extractDOCX(from: fileURL) {
                return LocatedTextBlock(
                    id: UUID(),
                    locator: MaterialLocator(
                        packID: source.pack.id,
                        relativePath: item.relativePath,
                        page: nil,
                        startOffset: 0,
                        endOffset: extracted.count
                    ),
                    text: extracted
                )
            }
            return LocatedTextBlock(
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

}
