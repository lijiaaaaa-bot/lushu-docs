import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()
            if appState.showOnboarding {
                HomeChatView()
            } else {
                WorkspaceView()
            }
        }
        .tint(Theme.walnut)
        .sheet(isPresented: $appState.showExportSheet) {
            ExportSheet()
                .environmentObject(appState)
        }
        .sheet(isPresented: $appState.showSettings) {
            SettingsSheet()
                .environmentObject(appState)
        }
        .overlay(alignment: .bottom) {
            if let toast = appState.toast {
                Text(toast)
                    .font(Theme.serifBody(13))
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .themeCard(emphasized: true)
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.22), value: appState.toast)
        .animation(.easeInOut(duration: 0.25), value: appState.showOnboarding)
    }
}

#Preview("首页对话") {
    RootView()
        .environmentObject(AppState())
        .frame(width: 1280, height: 820)
}

#Preview("首页已挂示例") {
    RootView()
        .environmentObject(AppState(seedHomeSample: true))
        .frame(width: 1280, height: 820)
}

#Preview("工作区") {
    RootView()
        .environmentObject(AppState(seedSamples: true))
        .frame(width: 1280, height: 820)
}

#Preview("稿纸") {
    RootView()
        .environmentObject(AppState(seedSamples: true, seedDrafts: true, seedFocus: .manuscript))
        .frame(width: 1280, height: 820)
}
