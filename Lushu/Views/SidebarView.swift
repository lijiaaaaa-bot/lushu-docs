import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            brand
            Divider().overlay(LushuTheme.hairline)
            sourceList
            Divider().overlay(LushuTheme.hairline)
            footer
        }
        .background(LushuTheme.paper)
    }

    private var brand: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("LUSHU")
                .font(LushuType.eyebrow())
                .foregroundStyle(LushuTheme.gold)
                .tracking(1.4)
            Text("律书")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(LushuTheme.ink)
            Text("文书生成")
                .font(LushuType.caption())
                .foregroundStyle(LushuTheme.softInk)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var sourceList: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("案件来源")
                    .font(LushuType.caption())
                    .foregroundStyle(LushuTheme.softInk)
                Spacer()
                Menu {
                    Button("选择案匣文件夹…") { appState.chooseAnxiaFolder() }
                    Button("导入文件…") { appState.importFiles() }
                    Button("导入文件夹…") { appState.importFolder() }
                    Divider()
                    Button("重新打开引导") { appState.showOnboarding = true }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(LushuTheme.ink)
                }
                .menuStyle(.borderlessButton)
                .frame(width: 20, height: 20)
                .help("添加来源")
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 6)

            if appState.sources.isEmpty {
                Text("尚无来源。请选择案匣文件夹或导入材料。")
                    .font(LushuType.caption())
                    .foregroundStyle(LushuTheme.softInk)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(appState.sources) { source in
                            SourceRow(
                                source: source,
                                selected: source.id == appState.selectedSourceID
                            )
                            .onTapGesture { appState.selectSource(source.id) }
                            .contextMenu {
                                Button("显示材料") {
                                    appState.selectSource(source.id)
                                    appState.setStage(.materials)
                                }
                                Button("删除来源", role: .destructive) {
                                    appState.removeSource(source.id)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 12)
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                appState.showSettings = true
            } label: {
                Label("设置", systemImage: "gearshape")
                    .font(LushuType.body())
                    .foregroundStyle(LushuTheme.softInk)
            }
            .buttonStyle(.plain)
            Text("与案匣同族 · 不代写法条")
                .font(LushuType.caption())
                .foregroundStyle(LushuTheme.softInk.opacity(0.8))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SourceRow: View {
    let source: CaseSource
    let selected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: source.origin.symbolName)
                .font(.system(size: 12))
                .foregroundStyle(selected ? LushuTheme.ink : LushuTheme.softInk)
                .frame(width: 16)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 3) {
                Text(source.title)
                    .font(.system(size: 12.5, weight: selected ? .semibold : .regular))
                    .foregroundStyle(LushuTheme.ink)
                    .lineLimit(2)
                Text(source.displaySubtitle)
                    .font(LushuType.caption())
                    .foregroundStyle(LushuTheme.softInk)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(selected ? LushuTheme.sky : Color.clear)
        .overlay(alignment: .leading) {
            if selected {
                Rectangle()
                    .fill(LushuTheme.gold)
                    .frame(width: 2)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .contentShape(Rectangle())
    }
}
