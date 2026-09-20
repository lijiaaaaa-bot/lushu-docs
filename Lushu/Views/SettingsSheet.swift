import SwiftUI

struct SettingsSheet: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var apiKey = ""
    @State private var statusNote = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("设置")
                .font(Theme.brandTitle(28))
                .foregroundStyle(Theme.ink)
            Text("DeepSeek 密钥只写入钥匙串，与剧本工厂相同。禁止提交到仓库。")
                .font(Theme.serifBody(14))
                .foregroundStyle(Theme.mute)

            VStack(alignment: .leading, spacing: 8) {
                Text("本地组装")
                    .font(Theme.screenTitle(16))
                    .foregroundStyle(Theme.ink)
                Text("任务卡解析与结构化落稿始终可用，无需密钥。")
                    .font(Theme.serifBody(13))
                    .foregroundStyle(Theme.mute)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .themeCard()

            VStack(alignment: .leading, spacing: 10) {
                Text("DeepSeek（自备密钥）")
                    .font(Theme.screenTitle(16))
                    .foregroundStyle(Theme.ink)
                Text(appState.hasDeepSeekKey
                     ? "钥匙串已保存 \(appState.maskedDeepSeekKey ?? "密钥")。接口 \(DeepSeekClient.defaultEndpoint.host ?? "api.deepseek.com")，思考链关闭。"
                     : "尚未保存密钥。润色与模型回执会提示来这里粘贴。")
                    .font(Theme.serifBody(13))
                    .foregroundStyle(Theme.mute)
                    .fixedSize(horizontal: false, vertical: true)

                SecureField("粘贴 DeepSeek API Key", text: $apiKey)
                    .textFieldStyle(.plain)
                    .font(Theme.serifBody(13))
                    .padding(8)
                    .background(Theme.paper)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Theme.walnut.opacity(0.22), lineWidth: 1)
                    )

                HStack(spacing: 10) {
                    SerifTextButton(title: "保存到钥匙串") { save() }
                    Text("·")
                        .font(Theme.screenTitle(16))
                        .foregroundStyle(Theme.mute)
                        .accessibilityHidden(true)
                    SerifTextButton(title: "清除密钥") { clear() }
                }

                if !statusNote.isEmpty {
                    Text(statusNote)
                        .font(Theme.serifBody(12))
                        .foregroundStyle(Theme.mute)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .themeCard()

            HStack {
                Spacer()
                SerifTextButton(title: "完成") { dismiss() }
            }
        }
        .padding(Theme.pagePad)
        .frame(width: 520, height: 500)
        .background(Theme.paper)
        .tint(Theme.walnut)
        .onAppear { appState.refreshDeepSeekKeyStatus() }
    }

    private func save() {
        do {
            try appState.saveDeepSeekKey(apiKey)
            apiKey = ""
            statusNote = "已写入钥匙串。不会出现在仓库或界面明文。"
        } catch {
            statusNote = error.localizedDescription
        }
    }

    private func clear() {
        do {
            try appState.clearDeepSeekKey()
            apiKey = ""
            statusNote = "已从钥匙串清除 DeepSeek 密钥。"
        } catch {
            statusNote = error.localizedDescription
        }
    }
}

#Preview {
    SettingsSheet()
        .environmentObject(AppState())
}
