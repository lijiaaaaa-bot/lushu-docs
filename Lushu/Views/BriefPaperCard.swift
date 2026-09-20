import SwiftUI

/// 引导页同款纸卡：要点用 brass 强调卡，律书回执用描边纸卡。不是蓝气泡。
struct BriefPaperCard: View {
    let message: BriefChatMessage

    var body: some View {
        let isUser = message.role == .user
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                ThemeBadge(text: isUser ? "要点" : "律书", outlined: !isUser)
                Spacer()
            }
            Text(isUser ? "委托要点" : "回执")
                .font(Theme.screenTitle(16))
                .foregroundStyle(Theme.ink)
            Text(message.text)
                .font(Theme.serifBody(14))
                .foregroundStyle(isUser ? Theme.ink : Theme.mute)
                .lineSpacing(4)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .themeCard(emphasized: isUser, outlined: !isUser)
    }
}

struct HomePromptChip: View {
    let title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.serifBody(13))
                .foregroundStyle(Theme.walnut)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Theme.walnut.opacity(0.22), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
