import SwiftUI

/// 对话气泡：用户靠右、回执靠左。附件条在助手气泡下方，动作在气泡内。
struct BriefPaperCard: View {
    @EnvironmentObject private var appState: AppState
    let message: BriefChatMessage
    var attachments: [MaterialItem] = []

    var body: some View {
        let isUser = message.role == .user
        VStack(alignment: isUser ? .trailing : .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 0) {
                if isUser { Spacer(minLength: 72) }
                bubble(isUser: isUser)
                if !isUser { Spacer(minLength: 72) }
            }
            if !isUser, !attachments.isEmpty {
                FlowRow(spacing: 6, lineSpacing: 6) {
                    ForEach(attachments) { item in
                        HomeAttachmentChip(title: HomeMaterialLabel.short(item.filename)) {
                            appState.revealWorkspace()
                        }
                    }
                }
                .padding(.trailing, 72)
            }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }

    private func bubble(isUser: Bool) -> some View {
        VStack(alignment: isUser ? .trailing : .leading, spacing: 8) {
            Text(message.text)
                .font(Theme.serifBody(14))
                .foregroundStyle(Theme.ink)
                .lineSpacing(3)
                .multilineTextAlignment(isUser ? .trailing : .leading)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)
            if message.action == .offerGenerate {
                HomePillButton(title: "生成文书", kind: .primary, identifier: "home.generate") {
                    appState.generateFromHome()
                }
            }
            if message.action == .downloadDraft {
                HomePillButton(title: "下载", kind: .primary) {
                    appState.downloadGeneratedDocument()
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(isUser ? Theme.card : Theme.paper)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isUser ? Theme.brass : Theme.walnut.opacity(0.22), lineWidth: isUser ? 1.2 : 1)
        )
        .frame(maxWidth: 420, alignment: isUser ? .trailing : .leading)
    }
}
