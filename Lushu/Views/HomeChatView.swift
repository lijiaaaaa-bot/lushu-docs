import SwiftUI

/// 首页：左话题列表，右当前会话。工作区是次级，不塞进这一壳。
struct HomeChatView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        HStack(spacing: 0) {
            HomeTopicSidebar()
            chatPane
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.paper)
        .tint(Theme.walnut)
        .onAppear { appState.refreshDeepSeekKeyStatus() }
    }

    private var chatPane: some View {
        VStack(spacing: 0) {
            chatHeader
            ScrollView {
                chatColumn
            }
            composerBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.paper)
    }

    private var chatHeader: some View {
        HStack(alignment: .center, spacing: 10) {
            Text(appState.currentTopicTitle)
                .font(Theme.screenTitle(18))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
            Spacer(minLength: 8)
            HomeActionChip(title: "工作区", systemImage: "rectangle.split.3x1") {
                appState.revealWorkspace()
            }
            HomeActionChip(title: "设置", systemImage: "gearshape") {
                appState.showSettings = true
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Theme.walnut.opacity(0.12))
                .frame(height: 1)
        }
    }

    private var chatColumn: some View {
        VStack(alignment: .leading, spacing: 18) {
            if appState.homeMessages.isEmpty {
                emptyState
            } else {
                ForEach(appState.homeMessages) { message in
                    BriefPaperCard(
                        message: message,
                        attachments: attachments(for: message),
                        draft: message.action == .downloadDraft ? appState.currentDraft : nil,
                        showsGenerateOffer: isLatestGenerateOffer(message)
                    )
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 20)
        .frame(maxWidth: HomeChatLayout.columnWidth, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Text("今天写哪份文书？")
                .font(Theme.screenTitle(22))
                .foregroundStyle(Theme.ink)
            Text("贴一句要点，或点下面的示例。")
                .font(Theme.serifBody(14))
                .foregroundStyle(Theme.mute)
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
        .frame(maxWidth: .infinity)
    }

    private func attachments(for message: BriefChatMessage) -> [MaterialItem] {
        guard message.role == .user, !message.attachmentIDs.isEmpty else { return [] }
        let all = appState.selectedSource?.materials ?? []
        let byID = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
        return message.attachmentIDs.compactMap { byID[$0] }
    }

    private func isLatestGenerateOffer(_ message: BriefChatMessage) -> Bool {
        guard message.action == .offerGenerate else { return false }
        guard appState.homeMessages.last(where: { $0.action == .offerGenerate })?.id == message.id else {
            return false
        }
        guard let offerIndex = appState.homeMessages.firstIndex(where: { $0.id == message.id }) else {
            return false
        }
        return !appState.homeMessages[offerIndex...].contains(where: { $0.action == .downloadDraft })
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

            if shouldShowComposerGenerate {
                HomeTextLink(title: "生成文书", identifier: "home.generate") {
                    appState.generateFromHome()
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 14)
        .background(Theme.paper)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Theme.walnut.opacity(0.12))
                .frame(height: 1)
        }
    }

    private var hasVisibleGenerateOffer: Bool {
        appState.homeMessages.contains(where: isLatestGenerateOffer)
    }

    private var shouldShowComposerGenerate: Bool {
        appState.canGenerateFromHome && !hasVisibleGenerateOffer && !appState.hasGeneratedDraft
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

}

#Preview("首页对话") {
    HomeChatView()
        .environmentObject(AppState())
        .frame(width: 1100, height: 720)
}

#Preview("已挂示例") {
    HomeChatView()
        .environmentObject(AppState(seedHomeSample: true))
        .frame(width: 1100, height: 720)
}

#Preview("已落稿") {
    let state = AppState(seedHomeSample: true)
    state.generateFromHome()
    return HomeChatView()
        .environmentObject(state)
        .frame(width: 1100, height: 720)
}
