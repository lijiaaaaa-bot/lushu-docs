import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ZStack {
            LushuTheme.sky.ignoresSafeArea()
            if appState.showOnboarding {
                OnboardingView()
            } else {
                WorkspaceView()
            }
        }
        .preferredColorScheme(.light)
        .tint(LushuTheme.ink)
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
                ToastBanner(text: toast)
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.22), value: appState.toast)
        .animation(.easeInOut(duration: 0.25), value: appState.showOnboarding)
    }
}

struct ToastBanner: View {
    let text: String

    var body: some View {
        Text(text)
            .font(LushuType.body())
            .foregroundStyle(LushuTheme.ink)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(LushuTheme.softGold)
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(LushuTheme.gold.opacity(0.45), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .shadow(color: LushuTheme.ink.opacity(0.08), radius: 8, y: 2)
    }
}

#Preview("引导") {
    RootView()
        .environmentObject(AppState())
        .frame(width: 1280, height: 820)
}

#Preview("工作区") {
    RootView()
        .environmentObject(AppState(seedSamples: true))
        .frame(width: 1280, height: 820)
}

#Preview("撰稿") {
    RootView()
        .environmentObject(AppState(seedSamples: true, seedDrafts: true, seedStage: .draft))
        .frame(width: 1280, height: 820)
}
