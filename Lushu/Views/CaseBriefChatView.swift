import SwiftUI

/// 案件绑定的撰稿对话。用法可以像对话（列表 + 多行输入），视觉必须与引导页同一套 Theme。
struct CaseBriefChatView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if appState.selectedSource == nil {
                        Text("先选案件。对话只挂在当前 CasePack 上。")
                            .font(Theme.serifBody(14))
                            .foregroundStyle(Theme.mute)
                            .lineSpacing(4)
                    } else if let chat = appState.currentBriefChat, !chat.messages.isEmpty {
                        ForEach(chat.messages) { message in
                            BriefPaperCard(message: message)
                        }
                    } else {
                        Text("把长要点贴进下方，更新任务卡。用法像对话，色板仍是引导页的纸色与胡桃描边。")
                            .font(Theme.serifBody(14))
                            .foregroundStyle(Theme.mute)
                            .lineSpacing(4)
                    }
                }
                .padding(.horizontal, Theme.pagePad)
                .padding(.vertical, 16)
            }
            composer
        }
        .background(Theme.paper)
        .tint(Theme.walnut)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("撰稿对话")
                .font(Theme.brandTitle(28))
                .foregroundStyle(Theme.ink)
            Text(appState.selectedSource?.title ?? "未绑定案件")
                .font(Theme.serifBody(13))
                .foregroundStyle(Theme.mute)
                .lineLimit(2)
            Text(appState.hasDeepSeekKey
                 ? "DeepSeek 已保存。润色只改措辞。"
                 : "无 DeepSeek 密钥。任务卡与本地落稿仍可用。")
                .font(Theme.serifBody(12))
                .foregroundStyle(Theme.mute)
        }
        .padding(.horizontal, Theme.pagePad)
        .padding(.top, 18)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.paper)
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 16) {
            ThinMultilineField(
                placeholder: "粘贴本案件长要点…",
                text: $appState.briefComposerText
            )

            HStack(spacing: 10) {
                SerifTextButton(title: "生成文书") { appState.generateFromBrief() }
                Text("·")
                    .font(Theme.screenTitle(16))
                    .foregroundStyle(Theme.mute)
                    .accessibilityHidden(true)
                SerifTextButton(title: "更新任务卡") { appState.updateBriefCard() }
                if appState.selectedSource?.isSample == true {
                    Text("·")
                        .font(Theme.screenTitle(16))
                        .foregroundStyle(Theme.mute)
                        .accessibilityHidden(true)
                    SerifTextButton(title: "填入示例要点") { appState.fillExampleBrief() }
                }
            }
        }
        .padding(.horizontal, Theme.pagePad)
        .padding(.top, 16)
        .padding(.bottom, 18)
        .background(Theme.paper)
    }
}

#Preview("撰稿对话") {
    CaseBriefChatView()
        .environmentObject(AppState(seedSamples: true))
        .frame(width: 360, height: 720)
}
