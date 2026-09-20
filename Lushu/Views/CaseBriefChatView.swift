import SwiftUI

/// 案件绑定的撰稿对话。不是通用聊天。
struct CaseBriefChatView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if appState.selectedSource == nil {
                        Text("先选案件。对话只挂在当前 CasePack 上。")
                            .font(Theme.serifBody(13))
                            .foregroundStyle(Theme.mute)
                    } else if let chat = appState.currentBriefChat, !chat.messages.isEmpty {
                        ForEach(chat.messages) { message in
                            bubble(message)
                        }
                    } else {
                        Text("把长要点贴进下方，更新任务卡。不会当成通用问答，也不会编造法条或台账数字。")
                            .font(Theme.serifBody(13))
                            .foregroundStyle(Theme.mute)
                    }
                }
                .padding(14)
            }
            composer
        }
        .background(Theme.paper)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("撰稿对话")
                .font(Theme.screenTitle(16))
                .foregroundStyle(Theme.walnut)
            Text(appState.selectedSource?.title ?? "未绑定案件")
                .font(Theme.caption(11))
                .foregroundStyle(Theme.mute)
                .lineLimit(2)
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func bubble(_ message: BriefChatMessage) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(message.role == .user ? "要点" : "律书")
                .font(Theme.caption(10))
                .foregroundStyle(Theme.mute)
            Text(message.text)
                .font(Theme.serifBody(13))
                .foregroundStyle(Theme.ink)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .themeCard(outlined: message.role == .assistant, emphasized: message.role == .user)
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextEditor(text: $appState.briefComposerText)
                .font(Theme.serifBody(13))
                .foregroundStyle(Theme.ink)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 88, maxHeight: 140)
                .padding(8)
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                        .stroke(Theme.walnut.opacity(0.12), lineWidth: 1)
                )
                .overlay(alignment: .topLeading) {
                    if appState.briefComposerText.isEmpty {
                        Text("粘贴本案件长要点…")
                            .font(Theme.serifBody(13))
                            .foregroundStyle(Theme.mute)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 16)
                            .allowsHitTesting(false)
                    }
                }

            HStack(spacing: 10) {
                SerifTextButton(title: "生成文书") { appState.generateFromBrief() }
                Text("·")
                    .foregroundStyle(Theme.mute)
                    .accessibilityHidden(true)
                SerifTextButton(title: "更新任务卡") { appState.updateBriefCard() }
            }

            if appState.selectedSource?.isSample == true {
                SerifTextButton(title: "填入示例要点") { appState.fillExampleBrief() }
            }
        }
        .padding(14)
        .background(Theme.paper)
    }
}

#Preview("撰稿对话") {
    CaseBriefChatView()
        .environmentObject(AppState(seedSamples: true))
        .frame(width: 340, height: 720)
}
