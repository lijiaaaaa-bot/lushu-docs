import SwiftUI

struct ManuscriptView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            if appState.selectedSource == nil {
                EmptyStateView(
                    title: "稿纸空着",
                    detail: "先导入，再结构化真表。文书只吃 StructuredCaseInputs，不读原始 PDF 字节。",
                    actionTitle: "选材料"
                ) {
                    appState.pickMaterials()
                }
            } else if appState.currentDraft.isBlank && !appState.isGenerating {
                EmptyStateView(
                    title: appState.currentDraft.title,
                    detail: "点工位「结构化」写出 .xlsx，再点「文书」。生成器不会编造法条。",
                    actionTitle: "成文书"
                ) {
                    appState.composeDocument()
                }
            } else if appState.workstation == .provenance || appState.showHiddenCitations {
                provenancePanel
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
            Text("·")
                .foregroundStyle(Theme.mute)
                .accessibilityHidden(true)
            SerifTextButton(title: "溯源") { appState.revealProvenance() }
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
                            .clipShape(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                                    .stroke(Theme.walnut.opacity(0.12), lineWidth: 1)
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

    private var provenancePanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("隐式溯源")
                    .font(Theme.brandTitle(28))
                    .foregroundStyle(Theme.ink)
                Text("引用默认隐藏。本页从 bundled LegalKnowledge 子集打开原文，查找失败则报错，不编造。")
                    .font(Theme.serifBody(14))
                    .foregroundStyle(Theme.mute)

                HStack(spacing: 10) {
                    SerifTextButton(title: "刑法第一条") {
                        appState.openCorpusArticle(id: "刑法/第一条")
                    }
                    Text("·")
                        .foregroundStyle(Theme.mute)
                        .accessibilityHidden(true)
                    SerifTextButton(title: "民法典总则第一条") {
                        appState.openCorpusArticle(id: "总则/第一条")
                    }
                    Text("·")
                        .foregroundStyle(Theme.mute)
                        .accessibilityHidden(true)
                    SerifTextButton(title: "绑定隐藏引用") {
                        appState.bindHiddenCitation(articleID: "刑法/第一条")
                    }
                }

                if let chunk = appState.openedChunk {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(chunk.lawTitle)
                            .font(Theme.screenTitle(16))
                            .foregroundStyle(Theme.walnut)
                        Text("\(chunk.id) · \(chunk.heading)")
                            .font(Theme.serifBody(12))
                            .foregroundStyle(Theme.mute)
                        Text(chunk.text)
                            .font(Theme.serifBody(15))
                            .foregroundStyle(Theme.ink)
                            .textSelection(.enabled)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .themeCard(emphasized: true)
                }

                if appState.currentDraft.citations.isEmpty {
                    Text("本稿未绑定 LegalCitation。生成器不会自动写条文；只有校验通过的隐藏引用可在此打开。")
                        .font(Theme.serifBody(15))
                        .foregroundStyle(Theme.ink)
                        .themeCard(outlined: true)
                } else {
                    ForEach(appState.currentDraft.citations) { citation in
                        Button {
                            appState.openCorpusArticle(id: "\(citation.lawID)/\(citation.articleNum)")
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(citation.locatorLabel)
                                    .font(Theme.screenTitle(16))
                                    .foregroundStyle(Theme.walnut)
                                Text("lawID \(citation.lawID) · 展示 \(citation.display.rawValue)（稿面默认隐藏）")
                                    .font(Theme.serifBody(12))
                                    .foregroundStyle(Theme.mute)
                                Text("sourceSpan \(citation.sourceSpan.start)–\(citation.sourceSpan.end)")
                                    .font(Theme.caption(11))
                                    .foregroundStyle(Theme.mute)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .themeCard()
                        }
                        .buttonStyle(.plain)
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
