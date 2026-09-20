import SwiftUI

/// 首页两栏：左话题列表，右聊天。不是单栏居中大标题。
enum HomeChatLayout {
    static let sidebarWidth: CGFloat = 248
    static let columnWidth: CGFloat = 720
}

enum HomePillKind {
    case primary
    case secondary
}

/// 主按钮：胡桃实心胶囊；次按钮：描边胶囊。禁止系统蓝。
struct HomePillButton: View {
    let title: String
    var kind: HomePillKind = .primary
    var enabled: Bool = true
    var identifier: String? = nil
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.screenTitle(14))
                .foregroundStyle(kind == .primary ? Theme.paper : Theme.walnut)
                .padding(.horizontal, kind == .primary ? 16 : 13)
                .padding(.vertical, 8)
                .background(kind == .primary ? Theme.walnut : Theme.card)
                .clipShape(Capsule(style: .continuous))
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(kind == .primary ? Color.clear : Theme.walnut.opacity(0.28), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
        .identified(identifier)
    }
}

/// 底栏次级动作：图标+字，描边小胶囊。
struct HomeActionChip: View {
    let title: String
    var systemImage: String
    var identifier: String? = nil
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .medium))
                Text(title)
                    .font(Theme.caption(12))
            }
            .foregroundStyle(Theme.walnut)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Theme.card)
            .clipShape(Capsule(style: .continuous))
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Theme.walnut.opacity(0.22), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .identified(identifier)
    }
}

enum HomeMaterialLabel {
    static func short(_ filename: String) -> String {
        if filename.contains("照明") || filename.contains("用电") {
            return "照明测算"
        }
        if filename.contains("停车信息") || (filename.lowercased().hasSuffix(".xlsx") && filename.contains("停车")),
           let year = BriefCardParser.year(in: filename) {
            return "\(year)年停车表"
        }
        if filename.count <= 16 { return filename }
        return String(filename.prefix(14)) + "…"
    }

    static func cardTitle(_ filename: String) -> String {
        if filename.count <= 18 { return filename }
        let ext = (filename as NSString).pathExtension
        let base = (filename as NSString).deletingPathExtension
        if ext.isEmpty { return String(filename.prefix(16)) + "…" }
        return String(base.prefix(12)) + "…." + ext
    }
}

/// 用户气泡上方的材料卡片：图标 + 文件名 + 类型。案匣纸色，不是冷灰。
struct HomeFileCard: View {
    let item: MaterialItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Theme.walnut)
            VStack(alignment: .leading, spacing: 2) {
                Text(HomeMaterialLabel.cardTitle(item.filename))
                    .font(Theme.caption(12))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(item.kind.displayName)
                    .font(Theme.caption(10))
                    .foregroundStyle(Theme.mute)
            }
        }
        .padding(12)
        .frame(width: 148, alignment: .leading)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Theme.walnut.opacity(0.16), lineWidth: 1)
        )
    }

    private var symbol: String {
        switch item.kind {
        case .xlsx: return "tablecells"
        case .pdf: return "doc.richtext"
        case .docx: return "doc.text"
        default: return "doc"
        }
    }
}

/// 紧凑文字链：生成确认。下载改用宽文件卡，不用细字链。
struct HomeTextLink: View {
    let title: String
    var identifier: String? = nil
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.serifBody(13))
                .foregroundStyle(Theme.walnut)
        }
        .buttonStyle(.plain)
        .identified(identifier)
    }
}

enum HomeDownloadLabel {
    static func caption(for draft: DraftDocument, byteCount: Int? = nil) -> String {
        var parts = ["DOCX", draft.kind.title]
        if let byteCount, byteCount > 0 {
            parts.append(ByteCountFormatter.string(fromByteCount: Int64(byteCount), countStyle: .file))
        }
        return parts.joined(separator: " · ")
    }
}

/// 落稿下载：近全宽圆角卡，整卡可点。案匣纸色，不是冷灰。
struct HomeDownloadCard: View {
    let draft: DraftDocument
    var byteCount: Int? = nil
    var identifier: String = "home.download"
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(draft.title)
                        .font(Theme.screenTitle(15))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(HomeDownloadLabel.caption(for: draft, byteCount: byteCount))
                        .font(Theme.caption(12))
                        .foregroundStyle(Theme.mute)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.mute)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Theme.walnut.opacity(0.16), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("下载 \(draft.title)")
        .identified(identifier)
    }
}

/// 生成后的编号追问，点选即发出。
struct HomeRelatedQuestions: View {
    let questions: [String]
    var onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("相关问题")
                .font(Theme.caption(12))
                .foregroundStyle(Theme.mute)
            ForEach(Array(questions.enumerated()), id: \.offset) { index, question in
                Button {
                    onSelect(question)
                } label: {
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(index + 1)")
                            .font(Theme.caption(12))
                            .foregroundStyle(Theme.walnut)
                            .frame(width: 16, alignment: .leading)
                        Text(question)
                            .font(Theme.serifBody(13))
                            .foregroundStyle(Theme.ink)
                            .multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 4)
    }
}

/// 已落稿在纸面上展开，不套紧白气泡，也不贴真表。
struct HomeDocumentPage: View {
    let draft: DraftDocument

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(draft.title)
                .font(Theme.screenTitle(18))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(draft.chatPreviewSections.prefix(4)) { section in
                VStack(alignment: .leading, spacing: 6) {
                    Text(section.heading)
                        .font(Theme.screenTitle(14))
                        .foregroundStyle(Theme.ink)
                    Text(trimmed(section.body))
                        .font(Theme.serifBody(14))
                        .foregroundStyle(Theme.ink)
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func trimmed(_ body: String) -> String {
        let compact = body.trimmingCharacters(in: .whitespacesAndNewlines)
        if compact.count <= 360 { return compact }
        return String(compact.prefix(358)).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }
}

/// 空态示例提示：可点的圆角胶囊，可换行排布。
struct HomePromptChip: View {
    let title: String
    var identifier: String? = nil
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.serifBody(13))
                .foregroundStyle(Theme.walnut)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Theme.card)
                .clipShape(Capsule(style: .continuous))
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Theme.walnut.opacity(0.22), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .identified(identifier)
    }
}

private extension View {
    @ViewBuilder
    func identified(_ identifier: String?) -> some View {
        if let identifier, !identifier.isEmpty {
            accessibilityIdentifier(identifier)
        } else {
            self
        }
    }
}

/// 从左到右排布，超出则换行。
struct FlowRow: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(
            proposal: ProposedViewSize(width: bounds.width, height: bounds.height),
            subviews: subviews
        )
        for (view, origin) in zip(subviews, result.origins) {
            view.place(
                at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (origins: [CGPoint], size: CGSize) {
        let limit = proposal.width ?? .infinity
        var origins: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var usedWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > limit {
                x = 0
                y += rowHeight + lineSpacing
                rowHeight = 0
            }
            origins.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            usedWidth = max(usedWidth, x - spacing)
        }
        return (origins, CGSize(width: usedWidth, height: y + rowHeight))
    }
}
