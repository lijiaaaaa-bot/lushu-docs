import SwiftUI

struct MaterialsLibraryView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if appState.selectedSource == nil {
                EmptyStateView(
                    title: "尚未选材料",
                    detail: "从左侧接入案匣文件夹，或导入文件。材料以抽屉卡片列出，不用系统列表框。",
                    actionTitle: "选材料"
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
                                MaterialDrawerCard(
                                    item: item,
                                    outlined: true,
                                    selected: item.id == appState.selectedMaterialID
                                )
                                .onTapGesture { appState.selectedMaterialID = item.id }
                            }
                        }
                        if !appState.filedMaterials.isEmpty {
                            sectionLabel("材料")
                            ForEach(appState.filedMaterials) { item in
                                MaterialDrawerCard(
                                    item: item,
                                    outlined: false,
                                    selected: item.id == appState.selectedMaterialID
                                )
                                .onTapGesture { appState.selectedMaterialID = item.id }
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
}

struct MaterialDrawerCard: View {
    let item: MaterialItem
    var outlined: Bool
    var selected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(item.filename)
                    .font(Theme.screenTitle(16))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
                Spacer(minLength: 8)
                ThemeBadge(text: outlined ? "未归" : item.kind.displayName, outlined: outlined)
            }
            HStack(spacing: 8) {
                Text(item.formattedSize)
                Text("·")
                Text(item.statusLabel)
            }
            .font(Theme.serifBody(12))
            .foregroundStyle(Theme.mute)
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
