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
    @Published var showOnboarding: Bool = true
    @Published var showExportSheet: Bool = false
    @Published var showSettings: Bool = false
    @Published var showUIFirstBanner: Bool = true
    @Published var toast: String?
    @Published var isGenerating: Bool = false
    @Published var previewMode: Bool = true

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
    var filedMaterials: [MaterialItem] { visibleMaterials.filter(\.included) }

    init(
        seedSamples: Bool = false,
        seedDrafts: Bool = false,
        seedFocus: WorkspaceFocus = .materials
    ) {
        if seedSamples {
            loadSamples()
        }
        if seedDrafts {
            for source in sources {
                drafts[source.id] = SampleData.summary(for: source)
            }
        }
        if seedSamples {
            focus = seedFocus
        }
    }

    func loadSamples() {
        let samples = [SampleData.laborDispute(), SampleData.houseContract()]
        sources = samples
        selectedSourceID = samples.first?.id
        showOnboarding = false
        focus = .materials
        for sample in samples {
            drafts[sample.id] = DraftDocument.blankSummary(caseTitle: sample.title)
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
        if drafts[id] == nil, let source = sources.first(where: { $0.id == id }) {
            drafts[id] = DraftDocument.blankSummary(caseTitle: source.title)
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
        }
    }

    func chooseKind(_ kind: DocumentKind) {
        if kind.isAvailable {
            selectedKind = kind
            return
        }
        flash("「\(kind.title)」为后续文书类型，本轮仅开放材料总结。")
    }

    func pickMaterials() {
        focus = .materials
        if sources.isEmpty {
            showOnboarding = true
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
        generateLocalSummary()
    }

    func exportDocument() {
        if currentDraft.isBlank {
            flash("请先成文书，再导出。")
            return
        }
        showExportSheet = true
    }

    func generateLocalSummary() {
        guard let source = selectedSource else {
            flash("请先选择案件来源。")
            return
        }
        isGenerating = true
        Task {
            try? await Task.sleep(nanoseconds: 380_000_000)
            drafts[source.id] = SampleData.summary(for: source)
            isGenerating = false
            previewMode = true
            focus = .manuscript
            flash("已生成本地摘要。PDF / DOCX 解析与大模型润色稍后接入。")
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

    private func ingestDemoSource(_ source: CaseSource, note: String) {
        var incoming = source
        incoming.id = UUID()
        incoming.lastOpenedAt = Date()
        sources.insert(incoming, at: 0)
        drafts[incoming.id] = DraftDocument.blankSummary(caseTitle: incoming.title)
        selectedSourceID = incoming.id
        selectedMaterialID = nil
        focus = .materials
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
