import SwiftUI

@main
struct LushuApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .frame(minWidth: 1100, minHeight: 720)
        }
        .defaultSize(width: 1320, height: 840)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("选材料…") { appState.pickMaterials(); appState.chooseAnxiaFolder() }
                    .keyboardShortcut("o", modifiers: [.command])
                Button("导入文件…") { appState.importFiles() }
                Button("导入文件夹…") { appState.importFolder() }
                Divider()
                Button("导出…") { appState.exportDocument() }
                    .keyboardShortcut("e", modifiers: [.command])
                    .disabled(appState.currentDraft.isBlank)
            }
            CommandMenu("律书") {
                Button("导入") { appState.setWorkstation(.importMaterials) }
                    .keyboardShortcut("1", modifiers: [.command])
                Button("结构化") { appState.structureSelectedCase() }
                    .keyboardShortcut("2", modifiers: [.command])
                Button("文书") { appState.composeDocument() }
                    .keyboardShortcut("3", modifiers: [.command])
                Button("溯源") { appState.revealProvenance() }
                    .keyboardShortcut("4", modifiers: [.command])
            }
            CommandGroup(replacing: .appSettings) {
                Button("设置…") { appState.showSettings = true }
                    .keyboardShortcut(",", modifiers: [.command])
            }
        }

        #if os(macOS)
        Settings {
            SettingsSheet()
                .environmentObject(appState)
                .frame(width: 520, height: 460)
        }
        #endif
    }
}
