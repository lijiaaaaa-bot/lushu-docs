import SwiftUI

/// 左栏：窄话题列表。案匣纸色分隔，禁止系统蓝。
struct HomeTopicSidebar: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(appState.homeTopics) { topic in
                        topicRow(topic)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            }
            .accessibilityIdentifier("home.topicList")
            footer
        }
        .frame(width: HomeChatLayout.sidebarWidth)
        .frame(maxHeight: .infinity)
        .background(Theme.card)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Theme.walnut.opacity(0.12))
                .frame(width: 1)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("律书")
                .font(Theme.brandTitle(22))
                .foregroundStyle(Theme.ink)
            HomePillButton(title: "新对话", kind: .secondary) {
                appState.startNewConversation()
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 16)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func topicRow(_ topic: HomeTopic) -> some View {
        let selected = topic.id == appState.selectedTopicID
        return Button {
            appState.selectTopic(topic.id)
        } label: {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(topic.title)
                        .font(Theme.screenTitle(13))
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                    Text(topic.caption)
                        .font(Theme.caption(11))
                        .foregroundStyle(Theme.mute)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? Theme.paper : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                    .stroke(selected ? Theme.walnut.opacity(0.28) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(topic.isInbox ? "清空对话" : "删除话题", role: .destructive) {
                appState.removeTopic(topic.id)
            }
        }
    }

    private var footer: some View {
        HStack {
            HomeActionChip(title: "设置", systemImage: "gearshape") {
                appState.showSettings = true
            }
            Spacer()
        }
        .padding(12)
    }
}
