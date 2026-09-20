import SwiftUI

/// 首页：豆包式栏位与按钮密度，案匣 paper / walnut / brass，衬线「律书」。
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
                if appState.canGenerateFromHome {
                    generateOffer
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
        VStack(spacing: 18) {
            Text("把长要点贴进来，挂上案件材料，再写成文书。")
                .font(Theme.serifBody(17))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
            Text(appState.hasDeepSeekKey
                 ? "DeepSeek 已保存 \(appState.maskedDeepSeekKey ?? "密钥")。可选回执与润色走 chat/completions，思考链关闭。"
                 : "未保存 DeepSeek 密钥。任务卡解析与本地落稿仍可用；模型回执与润色请到设置粘贴密钥，不会编造内容。")
                .font(Theme.serifBody(13))
                .foregroundStyle(Theme.mute)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text("用法像对话，不是通用闲聊。只服务当前要写的材料总结 / 专项报告。不编法条，不估台账数字。")
                .font(Theme.serifBody(14))
                .foregroundStyle(Theme.mute)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .frame(maxWidth: 480)
                .fixedSize(horizontal: false, vertical: true)

            FlowRow(spacing: 8, lineSpacing: 8) {
                HomePromptChip(title: "海天乙方电费+停车费报告") {
                    appState.useHaitianPromptChip()
                }
                HomePromptChip(title: "只写材料总结要点") {
                    appState.useSummaryPromptChip()
                }
            }
        }
        .padding(.top, 64)
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity)
    }

    private var generateOffer: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Text("材料与任务卡已齐。可按结构化案件包落稿。")
                    .font(Theme.serifBody(13))
                    .foregroundStyle(Theme.mute)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    HomePillButton(title: "生成文书", kind: .primary) {
                        appState.generateFromHome()
                    }
                    HomePillButton(title: "进入工作区", kind: .secondary) {
                        appState.revealWorkspace()
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Theme.paper)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Theme.walnut.opacity(0.22), lineWidth: 1)
            )
            .frame(maxWidth: 520, alignment: .leading)
            Spacer(minLength: 72)
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
                HomeActionChip(title: "示例", systemImage: "doc.text") {
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

            if appState.canGenerateFromHome {
                HStack(spacing: 8) {
                    HomePillButton(title: "生成文书", kind: .primary) {
                        appState.generateFromHome()
                    }
                    HomePillButton(title: "进入工作区", kind: .secondary) {
                        appState.revealWorkspace()
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
                .frame(minHeight: 40, maxHeight: 120)
            if appState.briefComposerText.isEmpty {
                Text("粘贴本案件长要点，如海天停车费与电费报告需求…")
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
        .frame(width: 920, height: 720)
}

#Preview("已挂示例") {
    HomeChatView()
        .environmentObject(AppState(seedHomeSample: true))
        .frame(width: 920, height: 720)
}
