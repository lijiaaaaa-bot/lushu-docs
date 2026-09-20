import SwiftUI

struct SummaryWorkspaceView: View {
    @EnvironmentObject private var appState: AppState
    let source: CaseSource

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider().overlay(LushuTheme.hairline)
            if appState.currentDraft.isBlank && !appState.isGenerating {
                blankState
            } else {
                editorSplit
            }
        }
        .background(LushuTheme.sky)
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            Text(appState.currentDraft.title)
                .font(LushuType.section())
                .foregroundStyle(LushuTheme.ink)
                .lineLimit(1)
            StatusChip(kind: .local, label: appState.currentDraft.generatorLabel)
            Spacer()
            Picker("视图", selection: $appState.previewMode) {
                Text("预览").tag(true)
                Text("编辑").tag(false)
            }
            .pickerStyle(.segmented)
            .frame(width: 140)
            Button("生成本地摘要") { appState.generateLocalSummary() }
                .disabled(appState.isGenerating)
            Button("大模型润色") { appState.requestLLMPolish() }
                .foregroundStyle(LushuTheme.softInk)
            Button("导出…") { appState.showExportSheet = true }
                .disabled(appState.currentDraft.isBlank)
                .font(.system(size: 13, weight: .semibold))
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 12)
        .background(LushuTheme.paper)
    }

    private var blankState: some View {
        EmptyStateView(
            title: "尚未成稿",
            detail: "围绕「\(source.title)」使用本地摘要即可生成材料总结骨架：清单、要点、时间线、争议与待办。无需 API Key。大模型润色为可选项。",
            actionTitle: "生成本地摘要"
        ) {
            appState.generateLocalSummary()
        }
    }

    private var editorSplit: some View {
        HSplitView {
            sectionRail
                .frame(minWidth: 200, idealWidth: 228, maxWidth: 280)
            Group {
                if appState.previewMode {
                    markdownPreview
                } else {
                    sectionEditor
                }
            }
            .frame(minWidth: 420)
        }
    }

    private var sectionRail: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("章节")
                .font(LushuType.caption())
                .foregroundStyle(LushuTheme.softInk)
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 8)
            ForEach(Array(appState.currentDraft.sections.enumerated()), id: \.element.id) { index, section in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(String(format: "%02d", index + 1))
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(LushuTheme.gold)
                    Text(section.heading)
                        .font(LushuType.body())
                        .foregroundStyle(LushuTheme.ink)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
            }
            Spacer()
            if appState.isGenerating {
                Text("正在组织本地摘要…")
                    .font(LushuType.caption())
                    .foregroundStyle(LushuTheme.softInk)
                    .padding(16)
            }
        }
        .background(LushuTheme.paper)
    }

    private var markdownPreview: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                ForEach(appState.currentDraft.sections) { section in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(section.heading)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(LushuTheme.ink)
                        Text(section.body)
                            .font(LushuType.body())
                            .foregroundStyle(LushuTheme.softInk)
                            .lineSpacing(5)
                            .textSelection(.enabled)
                    }
                }
            }
            .padding(28)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(LushuTheme.sky)
    }

    private var sectionEditor: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ForEach(appState.currentDraft.sections) { section in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(section.heading)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(LushuTheme.ink)
                        TextEditor(text: binding(for: section.id))
                            .font(LushuType.body())
                            .foregroundStyle(LushuTheme.ink)
                            .scrollContentBackground(.hidden)
                            .padding(8)
                            .frame(minHeight: 96)
                            .background(LushuTheme.paper)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .stroke(LushuTheme.line, lineWidth: 1)
                            )
                    }
                }
            }
            .padding(28)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(LushuTheme.sky)
    }

    private func binding(for id: DraftSection.ID) -> Binding<String> {
        Binding(
            get: {
                appState.currentDraft.sections.first(where: { $0.id == id })?.body ?? ""
            },
            set: { appState.updateSection(id: id, body: $0) }
        )
    }
}

#Preview("空白") {
    SummaryWorkspaceView(source: SampleData.laborDispute())
        .environmentObject(AppState(seedSamples: true))
        .frame(width: 1100, height: 720)
}

#Preview("已成稿") {
    SummaryWorkspaceView(source: SampleData.laborDispute())
        .environmentObject(AppState(seedSamples: true, seedDrafts: true))
        .frame(width: 1100, height: 720)
}
