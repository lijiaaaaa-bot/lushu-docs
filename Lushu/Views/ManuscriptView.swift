import SwiftUI

struct ManuscriptView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            if appState.selectedSource == nil {
                EmptyStateView(
                    title: "稿纸空着",
                    detail: "选好材料后，点「成文书」生成本地摘要。无需 API Key。",
                    actionTitle: "选材料"
                ) {
                    appState.pickMaterials()
                }
            } else if appState.currentDraft.isBlank && !appState.isGenerating {
                EmptyStateView(
                    title: appState.currentDraft.title,
                    detail: "围绕已选材料生成清单、要点、时间线、争议与待办。大模型润色为可选项。",
                    actionTitle: "成文书"
                ) {
                    appState.composeDocument()
                }
            } else if appState.previewMode {
                paperPreview
            } else {
                paperEditor
            }
        }
        .background(Theme.paper)
        .navigationTitle("")
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            if appState.isGenerating {
                Text("正在落稿…")
                    .font(Theme.serifBody(13))
                    .foregroundStyle(Theme.mute)
            }
            Spacer()
            SerifTextButton(title: appState.previewMode ? "编辑" : "预览") {
                appState.previewMode.toggle()
            }
            .disabled(appState.currentDraft.isBlank)
            Text("·")
                .foregroundStyle(Theme.mute)
                .accessibilityHidden(true)
            SerifTextButton(title: "润色") { appState.requestLLMPolish() }
        }
        .padding(.horizontal, Theme.pagePad)
        .padding(.vertical, 12)
        .background(Theme.paper)
    }

    private var paperPreview: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Text(appState.currentDraft.title)
                    .font(Theme.brandTitle(30))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if let stamp = appState.currentDraft.generatedAt {
                    Text("\(appState.currentDraft.generatorLabel)  ·  \(formatted(stamp))")
                        .font(Theme.serifBody(12))
                        .foregroundStyle(Theme.mute)
                }
                ForEach(appState.currentDraft.sections) { section in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(section.heading)
                            .font(Theme.screenTitle(18))
                            .foregroundStyle(Theme.walnut)
                        Text(section.body)
                            .font(Theme.serifBody(15))
                            .foregroundStyle(Theme.ink)
                            .lineSpacing(6)
                            .textSelection(.enabled)
                    }
                }
            }
            .padding(Theme.pagePad + 6)
            .frame(maxWidth: 680, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Theme.paper)
    }

    private var paperEditor: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(appState.currentDraft.title)
                    .font(Theme.brandTitle(26))
                    .foregroundStyle(Theme.ink)
                ForEach(appState.currentDraft.sections) { section in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(section.heading)
                            .font(Theme.screenTitle(15))
                            .foregroundStyle(Theme.walnut)
                        TextEditor(text: binding(for: section.id))
                            .font(Theme.serifBody(14))
                            .foregroundStyle(Theme.ink)
                            .scrollContentBackground(.hidden)
                            .padding(10)
                            .frame(minHeight: 100)
                            .background(Theme.card)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                                    .stroke(Theme.walnutStroke, lineWidth: 1)
                            )
                    }
                }
            }
            .padding(Theme.pagePad)
            .frame(maxWidth: 680, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Theme.paper)
    }

    private func binding(for id: DraftSection.ID) -> Binding<String> {
        Binding(
            get: { appState.currentDraft.sections.first(where: { $0.id == id })?.body ?? "" },
            set: { appState.updateSection(id: id, body: $0) }
        )
    }

    private func formatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月d日 HH:mm"
        return formatter.string(from: date)
    }
}

#Preview("空白") {
    ManuscriptView()
        .environmentObject(AppState(seedSamples: true))
        .frame(width: 560, height: 720)
}

#Preview("已成稿") {
    ManuscriptView()
        .environmentObject(AppState(seedSamples: true, seedDrafts: true, seedFocus: .manuscript))
        .frame(width: 560, height: 720)
}
