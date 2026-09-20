import SwiftUI

struct WorkstationStrip: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        HStack(spacing: 0) {
            ForEach(WorkstationStage.allCases) { stage in
                if stage != .importMaterials {
                    Text("→")
                        .font(Theme.serifBody(13))
                        .foregroundStyle(Theme.mute)
                        .padding(.horizontal, 8)
                        .accessibilityHidden(true)
                }
                Button {
                    handle(stage)
                } label: {
                    VStack(spacing: 6) {
                        Text(stage.title)
                            .font(Theme.screenTitle(15))
                            .foregroundStyle(appState.workstation == stage ? Theme.walnut : Theme.mute)
                        Rectangle()
                            .fill(appState.workstation == stage ? Theme.brass : Color.clear)
                            .frame(height: 2)
                    }
                    .padding(.horizontal, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 12)
            statusCaption
        }
        .padding(.horizontal, Theme.pagePad)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(Theme.paper)
    }

    @ViewBuilder
    private var statusCaption: some View {
        let pending = appState.selectedSource?.materials.filter { $0.tableStatus == .pendingStructure }.count ?? 0
        let real = appState.selectedSource?.materials.filter { $0.tableStatus == .realWorkbook }.count ?? 0
        Text("真表 \(real) · 待结构化 \(pending)")
            .font(Theme.serifBody(12))
            .foregroundStyle(Theme.mute)
    }

    private func handle(_ stage: WorkstationStage) {
        switch stage {
        case .importMaterials:
            appState.pickMaterials()
        case .structure:
            appState.structureSelectedCase()
        case .document:
            appState.composeDocument()
        case .provenance:
            appState.revealProvenance()
        }
    }
}
