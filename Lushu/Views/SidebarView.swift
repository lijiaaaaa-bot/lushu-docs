import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            ThinSearchField(placeholder: "检索来源或材料", text: $appState.searchText)
                .padding(.horizontal, Theme.pagePad)
                .padding(.bottom, 16)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    sourceSection
                    kindSection
                }
                .padding(.horizontal, Theme.pagePad)
                .padding(.bottom, 12)
            }
            if appState.showUIFirstBanner {
                UIFirstNote { appState.showUIFirstBanner = false }
            }
            DotActionBar(
                onPick: { appState.pickMaterials() },
                onCompose: { appState.composeDocument() },
                onExport: { appState.exportDocument() },
                composeEnabled: appState.selectedSource != nil,
                exportEnabled: !appState.currentDraft.isBlank
            )
            .padding(.horizontal, Theme.pagePad)
            .padding(.vertical, 16)
        }
        .background(Theme.paper)
        .navigationTitle("")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("律书")
                .font(Theme.brandTitle(36))
                .foregroundStyle(Theme.ink)
            HStack(alignment: .firstTextBaseline) {
                Text("从材料到文书")
                    .font(Theme.serifBody(13))
                    .foregroundStyle(Theme.mute)
                Spacer()
                Button("设置") { appState.showSettings = true }
                    .buttonStyle(.plain)
                    .font(Theme.caption(11))
                    .foregroundStyle(Theme.mute)
            }
        }
        .padding(.horizontal, Theme.pagePad)
        .padding(.top, 18)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var sourceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("来源")
            ForEach(appState.visibleSources) { source in
                SourceDrawerCard(
                    source: source,
                    selected: source.id == appState.selectedSourceID
                )
                .onTapGesture { appState.selectSource(source.id) }
                .contextMenu {
                    Button("显示材料") { appState.selectSource(source.id) }
                    Button("删除来源", role: .destructive) { appState.removeSource(source.id) }
                }
            }
            if appState.visibleSources.isEmpty {
                Text(appState.sources.isEmpty ? "尚未选取 iCloud「材料」或载入示例案件。" : "无匹配来源。")
                    .font(Theme.serifBody(13))
                    .foregroundStyle(Theme.mute)
                    .padding(.vertical, 4)
            }
            HStack(spacing: 10) {
                SerifTextButton(title: "案匣文件夹") { appState.chooseAnxiaFolder() }
                Text("·")
                    .foregroundStyle(Theme.mute)
                    .accessibilityHidden(true)
                SerifTextButton(title: "导入") { appState.importFolder() }
            }
            .padding(.top, 2)
        }
    }

    private var kindSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("文书")
            ForEach(DocumentKind.allCases) { kind in
                DocumentKindDrawerCard(
                    kind: kind,
                    selected: appState.selectedKind == kind
                )
                .onTapGesture { appState.chooseKind(kind) }
            }
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(Theme.caption(11))
            .foregroundStyle(Theme.mute)
            .tracking(0.6)
    }
}

struct SourceDrawerCard: View {
    let source: CaseSource
    let selected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(source.title)
                    .font(Theme.screenTitle(15))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
                Spacer(minLength: 6)
                if source.isSample {
                    ThemeBadge(text: "示例", outlined: true)
                }
            }
            Text(source.displaySubtitle)
                .font(Theme.serifBody(12))
                .foregroundStyle(Theme.mute)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .themeCard(emphasized: selected, outlined: false)
        .contentShape(Rectangle())
    }
}

struct DocumentKindDrawerCard: View {
    let kind: DocumentKind
    let selected: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text(kind.title)
                    .font(Theme.screenTitle(15))
                    .foregroundStyle(kind.isAvailable ? Theme.ink : Theme.mute)
                Text(kind.isAvailable ? "当前可撰" : "筹备中")
                    .font(Theme.serifBody(12))
                    .foregroundStyle(Theme.mute)
            }
            Spacer(minLength: 0)
            if !kind.isAvailable {
                ThemeBadge(text: "未开", outlined: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .themeCard(emphasized: selected && kind.isAvailable, outlined: !kind.isAvailable)
        .opacity(kind.isAvailable ? 1 : 0.72)
        .contentShape(Rectangle())
    }
}
