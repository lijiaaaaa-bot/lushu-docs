import SwiftUI

struct ThinSearchField: View {
    var placeholder: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.mute)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(Theme.serifBody(13))
                .foregroundStyle(Theme.ink)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Theme.paper)
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Theme.walnut.opacity(0.22), lineWidth: 1)
        )
    }
}

/// 案匣式底栏：衬线字按钮，中间圆点分隔。律书为「选材料 · 成文书 · 导出」。
struct DotActionBar: View {
    var onPick: () -> Void
    var onCompose: () -> Void
    var onExport: () -> Void
    var composeEnabled: Bool = true
    var exportEnabled: Bool = true

    var body: some View {
        HStack(spacing: 0) {
            SerifTextButton(title: "选材料", action: onPick)
            dot
            SerifTextButton(title: "成文书", action: onCompose)
                .opacity(composeEnabled ? 1 : 0.35)
                .disabled(!composeEnabled)
            dot
            SerifTextButton(title: "导出", action: onExport)
                .opacity(exportEnabled ? 1 : 0.35)
                .disabled(!exportEnabled)
        }
        .frame(maxWidth: .infinity)
    }

    private var dot: some View {
        Text("·")
            .font(Theme.screenTitle(16))
            .foregroundStyle(Theme.mute)
            .padding(.horizontal, 8)
            .accessibilityHidden(true)
    }
}

struct SerifTextButton: View {
    let title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.screenTitle(15))
                .foregroundStyle(Theme.walnut)
        }
        .buttonStyle(.plain)
    }
}

struct ThemeBadge: View {
    let text: String
    var outlined: Bool = false

    var body: some View {
        Text(text)
            .font(Theme.caption(10))
            .foregroundStyle(outlined ? Theme.mute : Theme.walnut)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(outlined ? Theme.paper : Theme.card)
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(Theme.walnut.opacity(0.12), lineWidth: 1)
            )
    }
}

struct EmptyStateView: View {
    let title: String
    let detail: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(Theme.screenTitle(22))
                .foregroundStyle(Theme.ink)
            Text(detail)
                .font(Theme.serifBody(14))
                .foregroundStyle(Theme.mute)
                .fixedSize(horizontal: false, vertical: true)
            if let actionTitle, let action {
                SerifTextButton(title: actionTitle, action: action)
                    .padding(.top, 6)
            }
        }
        .padding(Theme.pagePad)
        .frame(maxWidth: 480, alignment: .leading)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.paper)
    }
}

struct UIFirstNote: View {
    var onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("界面先行")
                .font(Theme.caption(10))
                .foregroundStyle(Theme.walnut)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(Theme.brass, lineWidth: 1)
                )
            Text("色板已锁定为案匣 Theme。选档、解析与大模型仍为说明性按钮。")
                .font(Theme.caption(11))
                .foregroundStyle(Theme.mute)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Button("收起", action: onDismiss)
                .buttonStyle(.plain)
                .font(Theme.caption(11))
                .foregroundStyle(Theme.walnut)
        }
        .padding(.horizontal, Theme.pagePad)
        .padding(.vertical, 8)
        .background(Theme.paper)
    }
}
