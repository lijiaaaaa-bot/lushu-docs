import SwiftUI

/// 对话行：用户软气泡 + 上方文件卡片；助手确认不套紧气泡；落稿在纸面展开。
struct BriefPaperCard: View {
    @EnvironmentObject private var appState: AppState
    let message: BriefChatMessage
    var attachments: [MaterialItem] = []
    var draft: DraftDocument? = nil
    var showsGenerateOffer: Bool = false

    var body: some View {
        if message.role == .user {
            userBlock
        } else if message.action == .downloadDraft, let draft, !draft.isBlank {
            documentBlock(draft)
        } else {
            assistantAck
        }
    }

    private var userBlock: some View {
        VStack(alignment: .trailing, spacing: 8) {
            if !attachments.isEmpty {
                HStack(spacing: 0) {
                    Spacer(minLength: 72)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 8) {
                            ForEach(attachments) { item in
                                HomeFileCard(item: item)
                            }
                        }
                    }
                }
            }
            Text(message.text)
                .font(Theme.serifBody(14))
                .foregroundStyle(Theme.ink)
                .lineSpacing(3)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Theme.walnut.opacity(0.10), lineWidth: 1)
                )
                .frame(maxWidth: 420, alignment: .trailing)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var assistantAck: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(message.text)
                .font(Theme.serifBody(14))
                .foregroundStyle(Theme.ink)
                .lineSpacing(4)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 520, alignment: .leading)
            if showsGenerateOffer {
                HomeTextLink(title: "生成文书", identifier: "home.generate") {
                    appState.generateFromHome()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func documentBlock(_ draft: DraftDocument) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HomeDocumentPage(draft: draft)
            HomeTextLink(title: "下载 .docx") {
                appState.downloadGeneratedDocument()
            }
            if !message.followUps.isEmpty {
                HomeRelatedQuestions(questions: message.followUps) { question in
                    appState.sendRelatedQuestion(question)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }
}
