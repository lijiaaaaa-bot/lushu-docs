import Combine
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var sources: [CaseSource] = []
    @Published var selectedSourceID: CaseSource.ID?
    @Published var stage: WorkspaceStage = .materials
    @Published var selectedKind: DocumentKind = .summary
    @Published var drafts: [UUID: DraftDocument] = [:]
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

    init(
        seedSamples: Bool = false,
        seedDrafts: Bool = false,
        seedStage: WorkspaceStage = .materials
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
            stage = seedStage
        }
    }

    func loadSamples() {
        let samples = [SampleData.laborDispute(), SampleData.houseContract()]
        sources = samples
        selectedSourceID = samples.first?.id
        showOnboarding = false
        for sample in samples {
            drafts[sample.id] = DraftDocument.blankSummary(caseTitle: sample.title)
        }
    }

    func chooseAnxiaFolder() {
        // UI-first：系统选档 + security-scoped bookmark 下一轮接入。
        ingestDemoSource(SampleData.laborDispute(), note: "已载入案匣示例案件。真实文件夹授权将在下一轮接入。")
    }

    func importFiles() {
        ingestDemoSource(
            rewritten(SampleData.houseContract(), origin: .importedFiles, caption: "导入 · 所选文件"),
            note: "已载入导入文件示例。系统多选文件将在下一轮接入。"
        )
    }

    func importFolder() {
        ingestDemoSource(
            SampleData.houseContract(),
            note: "已载入导入文件夹示例。系统选文件夹将在下一轮接入。"
        )
    }

    func selectSource(_ id: CaseSource.ID) {
        selectedSourceID = id
        stage = .materials
        selectedKind = .summary
        if drafts[id] == nil, let source = sources.first(where: { $0.id == id }) {
            drafts[id] = DraftDocument.blankSummary(caseTitle: source.title)
        }
    }

    func removeSource(_ id: CaseSource.ID) {
        sources.removeAll { $0.id == id }
        drafts[id] = nil
        if selectedSourceID == id {
            selectedSourceID = sources.first?.id
        }
        if sources.isEmpty {
            showOnboarding = true
            stage = .materials
        }
    }

    func setStage(_ next: WorkspaceStage) {
        if next == .draft, !selectedKind.isAvailable {
            flash("「\(selectedKind.title)」尚未开放生稿，请先使用材料总结。")
            selectedKind = .summary
        }
        stage = next
    }

    func chooseKind(_ kind: DocumentKind) {
        if kind.isAvailable {
            selectedKind = kind
            return
        }
        flash("「\(kind.title)」为后续文书类型，本轮仅开放材料总结。")
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
            stage = .draft
            flash("已生成本地摘要。PDF / DOCX 解析与大模型润色稍后接入。")
        }
    }

    func requestLLMPolish() {
        flash("大模型润色将读取钥匙串中的密钥。本轮不接线，本地摘要仍可用。")
        showSettings = true
    }

    func updateDraft(_ draft: DraftDocument) {
        guard let id = selectedSourceID else { return }
        drafts[id] = draft
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
        stage = .materials
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
