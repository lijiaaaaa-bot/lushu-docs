import SwiftUI

/// 首页主列宽度。豆包式居中栏，不是通栏稿纸。
enum HomeChatLayout {
    static let columnWidth: CGFloat = 680
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
