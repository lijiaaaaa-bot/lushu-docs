import SwiftUI

@main
struct LushuApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .frame(minWidth: 1080, minHeight: 700)
        }
        .defaultSize(width: 1280, height: 820)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("选择案匣文件夹…") { appState.chooseAnxiaFolder() }
                    .keyboardShortcut("o", modifiers: [.command])
                Button("导入文件…") { appState.importFiles() }
                Button("导入文件夹…") { appState.importFolder() }
                Divider()
                Button("导出文书…") { appState.showExportSheet = true }
                    .keyboardShortcut("e", modifiers: [.command])
                    .disabled(appState.selectedSource == nil || appState.currentDraft.isBlank)
            }
            CommandMenu("撰稿") {
                Button("材料") { appState.setStage(.materials) }
                    .keyboardShortcut("1", modifiers: [.command])
                Button("文书类型") { appState.setStage(.documentKind) }
                    .keyboardShortcut("2", modifiers: [.command])
                Button("撰稿") { appState.setStage(.draft) }
                    .keyboardShortcut("3", modifiers: [.command])
                Divider()
                Button("生成本地摘要") { appState.generateLocalSummary() }
                    .keyboardShortcut("g", modifiers: [.command])
                    .disabled(appState.selectedSource == nil)
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
                .frame(width: 480, height: 360)
        }
        #endif
    }
}
