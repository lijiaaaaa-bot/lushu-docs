import SwiftUI

struct StageHeader: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        HStack(spacing: 0) {
            ForEach(WorkspaceStage.allCases) { stage in
                Button {
                    appState.setStage(stage)
                } label: {
                    VStack(spacing: 7) {
                        HStack(spacing: 6) {
                            Text("\(stage.stepIndex)")
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundStyle(appState.stage == stage ? LushuTheme.ink : LushuTheme.softInk)
                                .frame(width: 16, height: 16)
                                .overlay(
                                    Circle()
                                        .stroke(appState.stage == stage ? LushuTheme.gold : LushuTheme.line, lineWidth: 1)
                                )
                            Text(stage.title)
                                .font(.system(size: 13, weight: appState.stage == stage ? .semibold : .regular))
                                .foregroundStyle(appState.stage == stage ? LushuTheme.ink : LushuTheme.softInk)
                            Text(stage.shortcutHint)
                                .font(LushuType.caption())
                                .foregroundStyle(LushuTheme.softInk.opacity(0.7))
                        }
                        Rectangle()
                            .fill(appState.stage == stage ? LushuTheme.gold : Color.clear)
                            .frame(height: 2)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .background(LushuTheme.paper)
    }
}
