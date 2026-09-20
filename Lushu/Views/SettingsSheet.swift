import SwiftUI

struct SettingsSheet: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var useLLM = false
    @State private var endpoint = "https://api.openai.com/v1/chat/completions"
    @State private var apiKey = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("设置")
                .font(Theme.brandTitle(28))
                .foregroundStyle(Theme.ink)
            Text("密钥只应写入钥匙串，不得提交到仓库。")
                .font(Theme.serifBody(14))
                .foregroundStyle(Theme.mute)

            VStack(alignment: .leading, spacing: 8) {
                Text("本地摘要")
                    .font(Theme.screenTitle(16))
                    .foregroundStyle(Theme.ink)
                Text("始终可用，无需密钥。")
                    .font(Theme.serifBody(13))
                    .foregroundStyle(Theme.mute)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .themeCard()

            VStack(alignment: .leading, spacing: 10) {
                Text("大模型（可选）")
                    .font(Theme.screenTitle(16))
                    .foregroundStyle(Theme.ink)
                Toggle(isOn: $useLLM) {
                    Text("启用润色")
                        .font(Theme.serifBody(14))
                        .foregroundStyle(Theme.ink)
                }
                .tint(Theme.brass)
                TextField("接口地址", text: $endpoint)
                    .textFieldStyle(.plain)
                    .font(Theme.serifBody(13))
                    .padding(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Theme.walnut.opacity(0.22), lineWidth: 1)
                    )
                SecureField("API Key（将存入钥匙串）", text: $apiKey)
                    .textFieldStyle(.plain)
                    .font(Theme.serifBody(13))
                    .padding(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Theme.walnut.opacity(0.22), lineWidth: 1)
                    )
                Text("本轮不接线、不写入钥匙串。")
                    .font(Theme.caption(11))
                    .foregroundStyle(Theme.mute)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .themeCard()

            HStack {
                Spacer()
                SerifTextButton(title: "完成") {
                    if useLLM || !apiKey.isEmpty {
                        appState.flash("设置留在界面。钥匙串与请求下一轮接入。")
                    }
                    dismiss()
                }
            }
        }
        .padding(Theme.pagePad)
        .frame(width: 520, height: 460)
        .background(Theme.paper)
        .tint(Theme.walnut)
    }
}

#Preview {
    SettingsSheet()
        .environmentObject(AppState())
}
