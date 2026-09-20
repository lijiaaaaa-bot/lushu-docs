import SwiftUI

enum ExportFormat: String, CaseIterable, Identifiable {
    case markdown
    case plainText

    var id: String { rawValue }

    var title: String {
        switch self {
        case .markdown: return "Markdown"
        case .plainText: return "纯文本"
        }
    }

    var filenameExtension: String {
        switch self {
        case .markdown: return "md"
        case .plainText: return "txt"
        }
    }
}

struct ExportSheet: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var format: ExportFormat = .markdown

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text("导出")
                    .font(Theme.brandTitle(28))
                    .foregroundStyle(Theme.ink)
                Text(appState.currentDraft.title)
                    .font(Theme.serifBody(14))
                    .foregroundStyle(Theme.mute)
            }
            .padding(Theme.pagePad)

            HStack(spacing: 16) {
                ForEach(ExportFormat.allCases) { item in
                    Button {
                        format = item
                    } label: {
                        Text(item.title)
                            .font(Theme.screenTitle(15))
                            .foregroundStyle(format == item ? Theme.walnut : Theme.mute)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Theme.pagePad)
            .padding(.bottom, 12)

            ScrollView {
                Text(exportBody)
                    .font(Theme.serifBody(13))
                    .foregroundStyle(Theme.ink)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                    .stroke(Theme.walnutStroke, lineWidth: 1)
            )
            .padding(.horizontal, Theme.pagePad)

            HStack {
                SerifTextButton(title: "写回案匣") {
                    appState.flash("写回案匣将使用已授权书签。本轮未执行写入。")
                }
                .disabled(appState.currentDraft.isBlank)
                Spacer()
                SerifTextButton(title: "取消") { dismiss() }
                Text("·")
                    .foregroundStyle(Theme.mute)
                    .accessibilityHidden(true)
                SerifTextButton(title: "导出到文件") { exportToFile() }
                    .disabled(appState.currentDraft.isBlank)
            }
            .padding(Theme.pagePad)
        }
        .frame(width: 640, height: 520)
        .background(Theme.paper)
        .tint(Theme.walnut)
    }

    private var exportBody: String {
        switch format {
        case .markdown: return appState.currentDraft.markdown
        case .plainText: return appState.currentDraft.plainText
        }
    }

    private func exportToFile() {
        let name = "\(appState.currentDraft.title).\(format.filenameExtension)"
        appState.flash("将保存为「\(name)」。系统保存面板下一轮接入。")
        dismiss()
    }
}

#Preview {
    ExportSheet()
        .environmentObject(AppState(seedSamples: true, seedDrafts: true))
}
