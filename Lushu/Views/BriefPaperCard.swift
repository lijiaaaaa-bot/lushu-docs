import SwiftUI

/// 对话气泡：用户靠右、回执靠左。只显示短文，下载动作不展开全文。
struct BriefPaperCard: View {
    @EnvironmentObject private var appState: AppState
    let message: BriefChatMessage

    var body: some View {
        let isUser = message.role == .user
        HStack(alignment: .top, spacing: 0) {
            if isUser { Spacer(minLength: 72) }
            VStack(alignment: isUser ? .trailing : .leading, spacing: 8) {
                Text(message.text)
                    .font(Theme.serifBody(14))
                    .foregroundStyle(Theme.ink)
                    .lineSpacing(3)
                    .multilineTextAlignment(isUser ? .trailing : .leading)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
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
            if !isUser { Spacer(minLength: 72) }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }
}
