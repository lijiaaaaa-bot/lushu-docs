import SwiftUI

struct WorkspaceView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            WorkstationStrip()
            NavigationSplitView {
                SidebarView()
                    .navigationSplitViewColumnWidth(min: 248, ideal: Theme.sidebarIdeal, max: 340)
            } content: {
                MaterialsLibraryView()
                    .navigationSplitViewColumnWidth(min: 300, ideal: Theme.materialsIdeal, max: 480)
            } detail: {
                ManuscriptView()
            }
            .navigationSplitViewStyle(.balanced)
            .tint(Theme.walnut)
            .background(Theme.paper)
        }
        .background(Theme.paper)
    }
}

#Preview {
    WorkspaceView()
        .environmentObject(AppState(seedSamples: true))
        .frame(width: 1280, height: 820)
}
