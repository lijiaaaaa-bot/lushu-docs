import SwiftUI

/// 对话气泡：用户靠右、回执靠左。纸色/卡片底 + 胡桃/黄铜描边，不是蓝气泡。
struct BriefPaperCard: View {
    let message: BriefChatMessage

    var body: some View {
        let isUser = message.role == .user
        HStack(alignment: .top, spacing: 0) {
            if isUser { Spacer(minLength: 72) }
            VStack(alignment: isUser ? .trailing : .leading, spacing: 6) {
                ThemeBadge(text: isUser ? "要点" : "律书", outlined: !isUser)
                Text(message.text)
                    .font(Theme.serifBody(14))
                    .foregroundStyle(Theme.ink)
                    .lineSpacing(4)
                    .textSelection(.enabled)
                    .multilineTextAlignment(isUser ? .trailing : .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(isUser ? Theme.card : Theme.paper)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isUser ? Theme.brass : Theme.walnut.opacity(0.22), lineWidth: isUser ? 1.2 : 1)
            )
            .frame(maxWidth: 520, alignment: isUser ? .trailing : .leading)
            if !isUser { Spacer(minLength: 72) }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }
}
