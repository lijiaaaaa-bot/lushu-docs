import SwiftUI

struct SettingsSheet: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var useLLM = false
    @State private var endpoint = "https://api.openai.com/v1/chat/completions"
    @State private var apiKey = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("SETTINGS")
                    .font(LushuType.eyebrow())
                    .foregroundStyle(LushuTheme.gold)
                    .tracking(1.2)
                Text("设置")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(LushuTheme.ink)
                Text("密钥只应写入钥匙串，不得提交到仓库。")
                    .font(LushuType.body())
                    .foregroundStyle(LushuTheme.softInk)
            }
            .padding(20)

            Divider().overlay(LushuTheme.hairline)

            Form {
                Section("本地摘要") {
                    LabeledContent("状态") {
                        Text("始终可用，无需密钥")
                            .foregroundStyle(LushuTheme.softInk)
                    }
                }
                Section("大模型（可选）") {
                    Toggle("启用大模型润色", isOn: $useLLM)
                    TextField("接口地址", text: $endpoint)
                    SecureField("API Key（将存入钥匙串）", text: $apiKey)
                    Text("本轮不接线、不写入钥匙串。字段仅用于确认设置界面完整。")
                        .font(LushuType.caption())
                        .foregroundStyle(LushuTheme.softInk)
                }
            }
            .formStyle(.grouped)
            .padding(.horizontal, 8)

            HStack {
                Spacer()
                Button("完成") {
                    if useLLM || !apiKey.isEmpty {
                        appState.flash("设置已保留在界面。钥匙串写入与请求下一轮接入，密钥不会写入项目文件。")
                    }
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
        .frame(width: 520, height: 420)
        .background(LushuTheme.paper)
    }
}

#Preview {
    SettingsSheet()
        .environmentObject(AppState())
}
