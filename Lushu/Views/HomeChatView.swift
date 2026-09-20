import SwiftUI

/// 首页：豆包式短对话。长任务卡 / 真表 / 报告正文进工作区。
struct HomeChatView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                chatColumn
                    .frame(maxWidth: HomeChatLayout.columnWidth)
                    .frame(maxWidth: .infinity)
            }
            composerBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.paper)
        .tint(Theme.walnut)
        .onAppear { appState.refreshDeepSeekKeyStatus() }
    }

    private var chatColumn: some View {
        VStack(alignment: .center, spacing: 14) {
            if appState.homeMessages.isEmpty {
                emptyState
            } else {
                ForEach(appState.homeMessages) { message in
                    BriefPaperCard(message: message)
                }
                if let source = appState.selectedSource, !source.materials.isEmpty {
                    materialList(source.materials)
                }
                if appState.canGenerateFromHome || appState.hasGeneratedDraft {
                    actionPills
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, appState.homeMessages.isEmpty ? 8 : 12)
        .padding(.bottom, 20)
    }

    private var header: some View {
        ZStack {
            Text("律书")
                .font(Theme.brandTitle(appState.homeMessages.isEmpty ? 44 : 28))
                .foregroundStyle(Theme.ink)
            HStack {
                Spacer()
                HomeActionChip(title: "设置", systemImage: "gearshape") {
                    appState.showSettings = true
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, appState.homeMessages.isEmpty ? 32 : 14)
        .padding(.bottom, 10)
        .frame(maxWidth: HomeChatLayout.columnWidth)
        .frame(maxWidth: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Text("把要点贴进来，挂上材料，再生成下载。")
                .font(Theme.serifBody(17))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
            Text("不编法条，不估台账数字。任务卡与报告正文在工作区。")
                .font(Theme.serifBody(13))
                .foregroundStyle(Theme.mute)
                .multilineTextAlignment(.center)

            FlowRow(spacing: 8, lineSpacing: 8) {
                HomePromptChip(title: "海天乙方电费+停车费报告", identifier: "home.haitianChip") {
                    appState.useHaitianPromptChip()
                }
                HomePromptChip(title: "只写材料总结要点") {
                    appState.useSummaryPromptChip()
                }
            }
        }
        .padding(.top, 72)
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity)
    }

    private func materialList(_ materials: [MaterialItem]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("材料")
                .font(Theme.caption(11))
                .foregroundStyle(Theme.mute)
            ForEach(materials) { item in
                Button {
                    appState.revealWorkspace()
                } label: {
                    HStack(spacing: 8) {
                        Text(shortMaterialName(item.filename))
                            .font(Theme.serifBody(13))
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        Text(item.statusLabel)
                            .font(Theme.caption(11))
                            .foregroundStyle(Theme.walnut)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Theme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Theme.walnut.opacity(0.18), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: 420, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var actionPills: some View {
        HStack(spacing: 8) {
            if appState.canGenerateFromHome {
                HomePillButton(title: "生成文书", kind: .primary, identifier: "home.generate") {
                    appState.generateFromHome()
                }
            }
            if appState.hasGeneratedDraft {
                HomePillButton(title: "下载", kind: .primary) {
                    appState.downloadGeneratedDocument()
                }
            }
            HomePillButton(title: "工作区", kind: .secondary) {
                appState.revealWorkspace()
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var composerBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            FlowRow(spacing: 8, lineSpacing: 8) {
                HomeActionChip(title: "选材料", systemImage: "folder") {
                    appState.chooseAnxiaFolder()
                }
                HomeActionChip(title: "导入", systemImage: "square.and.arrow.down") {
                    appState.importFiles()
                }
                HomeActionChip(title: "示例", systemImage: "doc.text", identifier: "home.sample") {
                    appState.loadSamples(enterWorkspace: false)
                }
                HomeActionChip(title: "设置", systemImage: "gearshape") {
                    appState.showSettings = true
                }
                if !appState.sources.isEmpty {
                    HomeActionChip(title: "工作区", systemImage: "rectangle.split.3x1") {
                        appState.revealWorkspace()
                    }
                }
            }

            HStack(alignment: .bottom, spacing: 8) {
                capsuleField
                HomePillButton(
                    title: "发送",
                    kind: .primary,
                    enabled: !appState.briefComposerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ) {
                    appState.sendHomeMessage()
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(Theme.walnut.opacity(0.22), lineWidth: 1)
            )

            if appState.canGenerateFromHome || appState.hasGeneratedDraft {
                HStack(spacing: 8) {
                    if appState.canGenerateFromHome {
                        HomePillButton(title: "生成文书", kind: .primary, identifier: "home.generate") {
                            appState.generateFromHome()
                        }
                    }
                    if appState.hasGeneratedDraft {
                        HomePillButton(title: "下载", kind: .primary) {
                            appState.downloadGeneratedDocument()
                        }
                    }
                }
            }

            Text("与案匣同族 · 不代写法条")
                .font(Theme.caption(11))
                .foregroundStyle(Theme.mute)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .frame(maxWidth: HomeChatLayout.columnWidth, alignment: .leading)
        .frame(maxWidth: .infinity)
        .background(Theme.paper)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Theme.walnut.opacity(0.12))
                .frame(height: 1)
        }
    }

    private var capsuleField: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $appState.briefComposerText)
                .font(Theme.serifBody(14))
                .foregroundStyle(Theme.ink)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .tint(Theme.walnut)
                .frame(minHeight: 40, maxHeight: 88)
            if appState.briefComposerText.isEmpty {
                Text("粘贴本案件要点…")
                    .font(Theme.serifBody(14))
                    .foregroundStyle(Theme.mute)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                    .allowsHitTesting(false)
            }
        }
    }

    private func shortMaterialName(_ filename: String) -> String {
        if filename.contains("停车"), let year = BriefCardParser.year(in: filename) {
            return "\(year)年停车表"
        }
        if filename.contains("照明") || filename.contains("用电") {
            return "照明测算"
        }
        if filename.count <= 16 { return filename }
        return String(filename.prefix(14)) + "…"
    }
}

#Preview("首页对话") {
    HomeChatView()
        .environmentObject(AppState())
        .frame(width: 920, height: 720)
}

#Preview("已挂示例") {
    HomeChatView()
        .environmentObject(AppState(seedHomeSample: true))
        .frame(width: 920, height: 720)
}
