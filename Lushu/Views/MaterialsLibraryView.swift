import SwiftUI

struct MaterialsLibraryView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if appState.selectedSource == nil {
                EmptyStateView(
                    title: "尚未选材料",
                    detail: "选取 iCloud Drive「材料」，或载入示例案件。原始件进 raw/，xlsx 进 structured/tables 真表。",
                    actionTitle: "导入"
                ) {
                    appState.pickMaterials()
                    appState.showOnboarding = true
                }
            } else if appState.visibleMaterials.isEmpty {
                EmptyStateView(
                    title: "没有匹配的材料",
                    detail: "换一个检索词，或导入更多文件。",
                    actionTitle: "导入"
                ) {
                    appState.importFiles()
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if !appState.unfiledMaterials.isEmpty {
                            sectionLabel("未归")
                            ForEach(appState.unfiledMaterials) { item in
                                materialCard(item, outlined: true)
                            }
                        }
                        if !appState.rawMaterials.isEmpty {
                            sectionLabel("原始")
                            ForEach(appState.rawMaterials) { item in
                                materialCard(item, outlined: item.tableStatus == .pendingStructure)
                            }
                        }
                        if !appState.structuredMaterials.isEmpty {
                            sectionLabel("已结构化")
                            ForEach(appState.structuredMaterials) { item in
                                materialCard(item, outlined: false)
                            }
                        }
                    }
                    .padding(Theme.pagePad)
                }
            }
        }
        .background(Theme.paper)
        .navigationTitle("")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(appState.selectedSource?.title ?? "材料")
                .font(Theme.screenTitle(24))
                .foregroundStyle(Theme.ink)
                .lineLimit(2)
            if let source = appState.selectedSource {
                Text(source.locationCaption)
                    .font(Theme.serifBody(13))
                    .foregroundStyle(Theme.mute)
            }
        }
        .padding(.horizontal, Theme.pagePad)
        .padding(.top, 18)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(Theme.caption(11))
            .foregroundStyle(Theme.mute)
            .tracking(0.6)
    }

    private func materialCard(_ item: MaterialItem, outlined: Bool) -> some View {
        MaterialDrawerCard(
            item: item,
            outlined: outlined,
            selected: item.id == appState.selectedMaterialID
        ) {
            appState.openStructuredWorkbook(item)
        }
        .onTapGesture { appState.selectedMaterialID = item.id }
    }
}

struct MaterialDrawerCard: View {
    let item: MaterialItem
    var outlined: Bool
    var selected: Bool
    var onOpenWorkbook: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(item.filename)
                    .font(Theme.screenTitle(16))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
                Spacer(minLength: 8)
                ThemeBadge(text: item.statusLabel, outlined: item.tableStatus == .pendingStructure)
            }
            HStack(spacing: 8) {
                Text(item.kind.displayName)
                Text("·")
                Text(item.formattedSize)
                if item.layer == .structured {
                    Text("·")
                    Text(item.relativePath)
                }
            }
            .font(Theme.serifBody(12))
            .foregroundStyle(Theme.mute)

            if item.tableStatus == .realWorkbook {
                SerifTextButton(title: "打开 Excel") { onOpenWorkbook() }
            } else if item.tableStatus == .pendingStructure {
                Text("待写入 structured/tables 真表，不用碎文本预览。")
                    .font(Theme.serifBody(12))
                    .foregroundStyle(Theme.mute)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .themeCard(emphasized: selected, outlined: outlined)
        .contentShape(Rectangle())
    }
}

#Preview {
    MaterialsLibraryView()
        .environmentObject(AppState(seedSamples: true))
        .frame(width: 400, height: 720)
}
