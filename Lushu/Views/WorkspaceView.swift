import SwiftUI

struct WorkspaceView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 220, ideal: LushuTheme.sidebarWidth, max: 300)
        } detail: {
            detail
        }
        .navigationSplitViewStyle(.balanced)
        .background(LushuTheme.sky)
    }

    @ViewBuilder
    private var detail: some View {
        if let source = appState.selectedSource {
            SourceWorkspaceView(source: source)
        } else {
            EmptyStateView(
                title: "未选择案件",
                detail: "从左侧选择来源，或添加案匣文件夹 / 导入材料。",
                actionTitle: "添加来源"
            ) {
                appState.showOnboarding = true
            }
        }
    }
}

struct SourceWorkspaceView: View {
    @EnvironmentObject private var appState: AppState
    let source: CaseSource

    var body: some View {
        VStack(spacing: 0) {
            WorkspaceChrome(source: source)
            if appState.showUIFirstBanner {
                UIFirstBanner {
                    appState.showUIFirstBanner = false
                }
            }
            StageHeader()
            Divider().overlay(LushuTheme.hairline)
            stageBody
        }
        .background(LushuTheme.sky)
        .navigationTitle(source.title)
    }

    @ViewBuilder
    private var stageBody: some View {
        switch appState.stage {
        case .materials:
            MaterialsLibraryView(source: source)
        case .documentKind:
            DocumentKindPickerView()
        case .draft:
            SummaryWorkspaceView(source: source)
        }
    }
}

struct WorkspaceChrome: View {
    @EnvironmentObject private var appState: AppState
    let source: CaseSource

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(source.origin.title.uppercased())
                    .font(LushuType.eyebrow())
                    .foregroundStyle(LushuTheme.gold)
                    .tracking(0.8)
                Text(source.title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(LushuTheme.ink)
                Text(source.locationCaption)
                    .font(LushuType.caption())
                    .foregroundStyle(LushuTheme.softInk)
            }
            Spacer()
            if source.isSample {
                StatusChip(kind: .sample)
            }
            Button("导出") {
                appState.showExportSheet = true
            }
            .disabled(appState.currentDraft.isBlank)
            .keyboardShortcut("e", modifiers: [.command])
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 16)
        .background(LushuTheme.paper)
        .overlay(alignment: .bottom) {
            Rectangle().fill(LushuTheme.hairline).frame(height: 1)
        }
    }
}

struct UIFirstBanner: View {
    var onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("界面先行")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(LushuTheme.ink)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(LushuTheme.softGold)
            Text("本轮交付完整屏幕结构。选文件夹授权、PDF/DOCX 解析与大模型接线按后续说明接入；按钮可点，未就绪处置为说明，不中断浏览。")
                .font(LushuType.caption())
                .foregroundStyle(LushuTheme.softInk)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Button("知道了", action: onDismiss)
                .buttonStyle(.plain)
                .font(LushuType.caption())
                .foregroundStyle(LushuTheme.ink)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 8)
        .background(LushuTheme.sky)
        .overlay(alignment: .bottom) {
            Rectangle().fill(LushuTheme.line).frame(height: 1)
        }
    }
}

#Preview {
    WorkspaceView()
        .environmentObject(AppState(seedSamples: true))
        .frame(width: 1280, height: 820)
}
