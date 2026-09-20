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
            header
            Divider().overlay(LushuTheme.hairline)
            content
            Divider().overlay(LushuTheme.hairline)
            footer
        }
        .frame(width: 640, height: 520)
        .background(LushuTheme.paper)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("EXPORT")
                .font(LushuType.eyebrow())
                .foregroundStyle(LushuTheme.gold)
                .tracking(1.2)
            Text("导出文书")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(LushuTheme.ink)
            Text(appState.currentDraft.title)
                .font(LushuType.body())
                .foregroundStyle(LushuTheme.softInk)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 18) {
                Text("格式")
                    .font(LushuType.body())
                    .foregroundStyle(LushuTheme.softInk)
                ForEach(ExportFormat.allCases) { item in
                    Button {
                        format = item
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: format == item ? "largecircle.fill.circle" : "circle")
                                .foregroundStyle(LushuTheme.ink)
                            Text(item.title)
                                .foregroundStyle(LushuTheme.ink)
                        }
                        .font(LushuType.body())
                    }
                    .buttonStyle(.plain)
                }
            }

            Text("预览")
                .font(LushuType.caption())
                .foregroundStyle(LushuTheme.softInk)

            ScrollView {
                Text(exportBody)
                    .font(LushuType.mono())
                    .foregroundStyle(LushuTheme.ink)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(10)
            .background(LushuTheme.sky)
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(LushuTheme.line, lineWidth: 1)
            )
        }
        .padding(20)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Button("写回案匣文件夹") {
                appState.flash("写回案匣将使用已授权书签。本轮界面先行，未执行写入。")
            }
            .disabled(appState.currentDraft.isBlank)
            Spacer()
            Button("取消") { dismiss() }
            Button("导出到文件…") { exportToFile() }
                .disabled(appState.currentDraft.isBlank)
                .keyboardShortcut(.defaultAction)
        }
        .padding(16)
    }

    private var exportBody: String {
        switch format {
        case .markdown: return appState.currentDraft.markdown
        case .plainText: return appState.currentDraft.plainText
        }
    }

    private func exportToFile() {
        // UI-first：NSSavePanel 下一轮接入。
        let name = "\(appState.currentDraft.title).\(format.filenameExtension)"
        appState.flash("将保存为「\(name)」。系统保存面板下一轮接入。")
        dismiss()
    }
}

#Preview {
    ExportSheet()
        .environmentObject(AppState(seedSamples: true, seedDrafts: true))
}
