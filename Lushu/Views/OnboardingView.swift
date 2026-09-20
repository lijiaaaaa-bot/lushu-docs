import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text("律书")
                    .font(Theme.brandTitle(48))
                    .foregroundStyle(Theme.ink)
                Text("从案匣材料写成文书。先做材料总结。")
                    .font(Theme.serifBody(16))
                    .foregroundStyle(Theme.mute)
            }
            .padding(.horizontal, Theme.pagePad + 8)
            .padding(.top, 36)
            .padding(.bottom, 22)

            ThinSearchField(placeholder: "检索", text: $appState.searchText)
                .padding(.horizontal, Theme.pagePad + 8)
                .padding(.bottom, 22)

            HStack(alignment: .top, spacing: 16) {
                OnboardingDrawerCard(
                    title: "案匣文件夹",
                    detail: "优先指向案匣或 iCloud 中的案件目录。一次授权，持续读取。",
                    badge: "优先",
                    outlined: false
                ) {
                    appState.chooseAnxiaFolder()
                }
                OnboardingDrawerCard(
                    title: "导入文件",
                    detail: "尚未建柜时，导入单个、多个文件或整个文件夹。",
                    badge: "回退",
                    outlined: true
                ) {
                    appState.importFolder()
                }
            }
            .padding(.horizontal, Theme.pagePad + 8)

            HStack(spacing: 10) {
                SerifTextButton(title: "仅导入文件") { appState.importFiles() }
                Text("·")
                    .foregroundStyle(Theme.mute)
                    .accessibilityHidden(true)
                SerifTextButton(title: "载入示例") { appState.loadSamples() }
                if !appState.sources.isEmpty {
                    Text("·")
                        .foregroundStyle(Theme.mute)
                        .accessibilityHidden(true)
                    SerifTextButton(title: "返回工作区") { appState.showOnboarding = false }
                }
            }
            .padding(.horizontal, Theme.pagePad + 8)
            .padding(.top, 18)

            Spacer()

            HStack {
                Text("与案匣同族 · 不代写法条")
                    .font(Theme.serifBody(12))
                    .foregroundStyle(Theme.mute)
                Spacer()
                DotActionBar(
                    onPick: { appState.chooseAnxiaFolder() },
                    onCompose: { appState.flash("请先选材料。") },
                    onExport: { appState.flash("请先成文书。") },
                    composeEnabled: false,
                    exportEnabled: false
                )
                .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.horizontal, Theme.pagePad + 8)
            .padding(.vertical, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.paper)
    }
}

struct OnboardingDrawerCard: View {
    let title: String
    let detail: String
    let badge: String
    var outlined: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    ThemeBadge(text: badge, outlined: outlined)
                    Spacer()
                }
                Text(title)
                    .font(Theme.screenTitle(20))
                    .foregroundStyle(Theme.ink)
                Text(detail)
                    .font(Theme.serifBody(14))
                    .foregroundStyle(Theme.mute)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 168, alignment: .topLeading)
            .themeCard(emphasized: !outlined, outlined: outlined)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AppState())
        .frame(width: 920, height: 640)
}
