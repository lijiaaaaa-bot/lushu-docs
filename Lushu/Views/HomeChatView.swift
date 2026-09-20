import SwiftUI

/// 首页：豆包式对话布局（消息流 + 底栏多行输入），案匣 Theme 纸色与衬线按钮。
struct HomeChatView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if appState.homeMessages.isEmpty {
                        emptyState
                    } else {
                        ForEach(appState.homeMessages) { message in
                            BriefPaperCard(message: message)
                        }
                        if appState.canGenerateFromHome {
                            generateOffer
                        }
                    }
                }
                .padding(.horizontal, Theme.pagePad + 8)
                .padding(.vertical, 8)
                .frame(maxWidth: 760, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            composerBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.paper)
        .tint(Theme.walnut)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("律书")
                    .font(Theme.brandTitle(48))
                    .foregroundStyle(Theme.ink)
                Spacer(minLength: 12)
                SerifTextButton(title: "设置") { appState.showSettings = true }
            }
            Text("把长要点贴进来，挂上案件材料，再写成文书。")
                .font(Theme.serifBody(16))
                .foregroundStyle(Theme.mute)
            Text(appState.hasDeepSeekKey
                 ? "DeepSeek 已保存 \(appState.maskedDeepSeekKey ?? "密钥")。可选回执与润色走 chat/completions，思考链关闭。"
                 : "未保存 DeepSeek 密钥。任务卡解析与本地落稿仍可用；模型回执与润色请到设置粘贴密钥，不会编造内容。")
                .font(Theme.serifBody(13))
                .foregroundStyle(Theme.mute)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, Theme.pagePad + 8)
        .padding(.top, 36)
        .padding(.bottom, 18)
        .frame(maxWidth: 760, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear { appState.refreshDeepSeekKeyStatus() }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("用法像对话，不是通用闲聊。只服务当前要写的材料总结 / 专项报告。不编法条，不估台账数字。")
                .font(Theme.serifBody(15))
                .foregroundStyle(Theme.mute)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)

            HStack(alignment: .top, spacing: 10) {
                HomePromptChip(title: "海天乙方电费+停车费报告") {
                    appState.useHaitianPromptChip()
                }
                HomePromptChip(title: "只写材料总结要点") {
                    appState.useSummaryPromptChip()
                }
            }
        }
        .padding(.top, 8)
    }

    private var generateOffer: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("材料与任务卡已齐。可按结构化案件包落稿。")
                .font(Theme.serifBody(14))
                .foregroundStyle(Theme.mute)
            HStack(spacing: 10) {
                SerifTextButton(title: "生成文书") { appState.generateFromHome() }
                Text("·")
                    .font(Theme.screenTitle(16))
                    .foregroundStyle(Theme.mute)
                    .accessibilityHidden(true)
                SerifTextButton(title: "进入工作区") { appState.revealWorkspace() }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .themeCard(outlined: true)
    }

    private var composerBar: some View {
        VStack(alignment: .leading, spacing: 14) {
            ThinMultilineField(
                placeholder: "粘贴本案件长要点，如海天停车费与电费报告需求…",
                text: $appState.briefComposerText,
                minHeight: 96
            )

            HStack(spacing: 10) {
                SerifTextButton(title: "发送") { appState.sendHomeMessage() }
                if appState.canGenerateFromHome {
                    Text("·")
                        .font(Theme.screenTitle(16))
                        .foregroundStyle(Theme.mute)
                        .accessibilityHidden(true)
                    SerifTextButton(title: "生成文书") { appState.generateFromHome() }
                }
                if !appState.sources.isEmpty {
                    Text("·")
                        .font(Theme.screenTitle(16))
                        .foregroundStyle(Theme.mute)
                        .accessibilityHidden(true)
                    SerifTextButton(title: "进入工作区") { appState.revealWorkspace() }
                }
            }

            HStack(spacing: 10) {
                SerifTextButton(title: "选材料文件夹") { appState.chooseAnxiaFolder() }
                Text("·")
                    .font(Theme.screenTitle(16))
                    .foregroundStyle(Theme.mute)
                    .accessibilityHidden(true)
                SerifTextButton(title: "导入文件") { appState.importFiles() }
                Text("·")
                    .font(Theme.screenTitle(16))
                    .foregroundStyle(Theme.mute)
                    .accessibilityHidden(true)
                SerifTextButton(title: "载入示例案件") { appState.loadSamples(enterWorkspace: false) }
            }

            Text("与案匣同族 · 不代写法条")
                .font(Theme.serifBody(12))
                .foregroundStyle(Theme.mute)
        }
        .padding(.horizontal, Theme.pagePad + 8)
        .padding(.top, 16)
        .padding(.bottom, 22)
        .frame(maxWidth: 760, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.paper)
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
