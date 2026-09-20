import SwiftUI

struct MaterialsLibraryView: View {
    @EnvironmentObject private var appState: AppState
    let source: CaseSource

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            toolbar
            columnHeader
            if source.materials.isEmpty {
                EmptyStateView(
                    title: "尚未纳入材料",
                    detail: "从此来源导入文件，或改选案匣文件夹。txt / md / pdf / docx 将列入清单。",
                    actionTitle: "导入文件"
                ) {
                    appState.importFiles()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(source.materials.enumerated()), id: \.element.id) { index, item in
                            MaterialRow(item: item, zebra: index.isMultiple(of: 2))
                        }
                    }
                }
            }
            footer
        }
        .background(LushuTheme.sky)
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            Text("材料库")
                .font(LushuType.section())
                .foregroundStyle(LushuTheme.ink)
            Text("\(source.includedCount) / \(source.materials.count) 份纳入撰稿")
                .font(LushuType.caption())
                .foregroundStyle(LushuTheme.softInk)
            Spacer()
            Button("补充导入…") { appState.importFiles() }
                .buttonStyle(.plain)
                .font(LushuType.body())
                .foregroundStyle(LushuTheme.ink)
            Button("下一步：文书类型") { appState.setStage(.documentKind) }
                .font(.system(size: 13, weight: .semibold))
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 14)
        .background(LushuTheme.paper)
        .overlay(alignment: .bottom) { Rectangle().fill(LushuTheme.hairline).frame(height: 1) }
    }

    private var columnHeader: some View {
        HStack(spacing: 12) {
            Text("名称").frame(maxWidth: .infinity, alignment: .leading)
            Text("类型").frame(width: 64, alignment: .leading)
            Text("大小").frame(width: 72, alignment: .trailing)
            Text("状态").frame(width: 72, alignment: .leading)
        }
        .font(LushuType.caption())
        .foregroundStyle(LushuTheme.softInk)
        .padding(.horizontal, 28)
        .padding(.vertical, 7)
        .background(LushuTheme.sky)
    }

    private var footer: some View {
        HStack {
            Text("PDF / DOCX 本轮只列目录与体积，不拆正文。txt / md 将在摘要接线后优先读取。")
                .font(LushuType.caption())
                .foregroundStyle(LushuTheme.softInk)
            Spacer()
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 10)
        .background(LushuTheme.paper)
        .overlay(alignment: .top) { Rectangle().fill(LushuTheme.hairline).frame(height: 1) }
    }
}

struct MaterialRow: View {
    let item: MaterialItem
    let zebra: Bool

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 12))
                    .foregroundStyle(LushuTheme.softInk)
                    .frame(width: 16)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.filename)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(LushuTheme.ink)
                    Text(item.relativePath)
                        .font(LushuType.caption())
                        .foregroundStyle(LushuTheme.softInk)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(item.kind.displayName)
                .font(LushuType.caption())
                .foregroundStyle(LushuTheme.ink)
                .frame(width: 64, alignment: .leading)

            Text(item.formattedSize)
                .font(LushuType.caption())
                .foregroundStyle(LushuTheme.softInk)
                .frame(width: 72, alignment: .trailing)

            StatusChip(kind: item.included ? .available : .upcoming, label: item.statusLabel)
                .frame(width: 72, alignment: .leading)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 9)
        .background(zebra ? LushuTheme.paper.opacity(0.55) : LushuTheme.paper)
        .overlay(alignment: .bottom) { Rectangle().fill(LushuTheme.hairline).frame(height: 1) }
    }

    private var symbol: String {
        switch item.kind {
        case .pdf: return "doc.richtext"
        case .docx: return "doc"
        case .markdown: return "text.alignleft"
        case .txt: return "doc.plaintext"
        case .other: return "questionmark.square"
        }
    }
}

#Preview {
    MaterialsLibraryView(source: SampleData.laborDispute())
        .environmentObject(AppState(seedSamples: true))
        .frame(width: 960, height: 640)
}
