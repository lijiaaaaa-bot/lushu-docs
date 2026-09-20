import SwiftUI

struct DocumentKindPickerView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("选择文书类型")
                        .font(LushuType.section())
                        .foregroundStyle(LushuTheme.ink)
                    Text("DocumentKind 为扩展点。当前仅「材料总结」进入撰稿；起诉状、答辩状保持同一枚举，后续加模板即可。")
                        .font(LushuType.body())
                        .foregroundStyle(LushuTheme.softInk)
                }
                Spacer()
                Button("进入撰稿") { appState.setStage(.draft) }
                    .font(.system(size: 13, weight: .semibold))
                    .disabled(!appState.selectedKind.isAvailable)
            }

            HStack(alignment: .top, spacing: 14) {
                ForEach(DocumentKind.allCases) { kind in
                    DocumentKindCard(
                        kind: kind,
                        selected: appState.selectedKind == kind
                    ) {
                        appState.chooseKind(kind)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("扩展说明")
                    .font(LushuType.caption())
                    .foregroundStyle(LushuTheme.gold)
                Text("新增文书类型时：在 DocumentKind 增加 case，补 title / subtitle / 模板，并在生成器按 kind 分发。不要另起应用。")
                    .font(LushuType.body())
                    .foregroundStyle(LushuTheme.softInk)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(LushuTheme.paper)
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(LushuTheme.line, lineWidth: 1)
            )

            Spacer()
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(LushuTheme.sky)
    }
}

struct DocumentKindCard: View {
    let kind: DocumentKind
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(kind.latin)
                        .font(LushuType.eyebrow())
                        .foregroundStyle(kind.isAvailable ? LushuTheme.gold : LushuTheme.softInk)
                        .tracking(1.0)
                    Spacer()
                    StatusChip(kind: kind.isAvailable ? .available : .upcoming)
                }
                HStack(spacing: 8) {
                    Image(systemName: kind.symbolName)
                        .foregroundStyle(LushuTheme.ink.opacity(kind.isAvailable ? 1 : 0.45))
                    Text(kind.title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(LushuTheme.ink.opacity(kind.isAvailable ? 1 : 0.55))
                }
                Text(kind.subtitle)
                    .font(LushuType.body())
                    .foregroundStyle(LushuTheme.softInk)
                    .lineSpacing(3)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                if selected && kind.isAvailable {
                    Text("当前选用")
                        .font(LushuType.caption())
                        .foregroundStyle(LushuTheme.ink)
                } else if !kind.isAvailable {
                    Text("点击查看说明")
                        .font(LushuType.caption())
                        .foregroundStyle(LushuTheme.softInk)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 188, alignment: .topLeading)
            .lushuCard(emphasized: selected && kind.isAvailable)
            .opacity(kind.isAvailable ? 1 : 0.78)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    DocumentKindPickerView()
        .environmentObject(AppState(seedSamples: true))
        .frame(width: 960, height: 640)
}
