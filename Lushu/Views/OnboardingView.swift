import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        HStack(spacing: 0) {
            leftRail
            Divider().overlay(LushuTheme.line)
            rightPane
        }
        .background(LushuTheme.sky)
    }

    private var leftRail: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("律师工作开发软件集群")
                .font(LushuType.eyebrow())
                .foregroundStyle(LushuTheme.gold)
                .tracking(1.2)

            Text("律书")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(LushuTheme.ink)

            Text("从材料到文书")
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(LushuTheme.softInk)

            Text("先整理案匣里的原件，再写成可用的总结稿。起诉状与答辩状共用同一套文书类型扩展点，本轮只开放材料总结。")
                .font(LushuType.body())
                .foregroundStyle(LushuTheme.softInk)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                familyRow(name: "案匣", role: "案件柜子 · 原件与检索")
                familyRow(name: "律书", role: "文书生成 · 本应用")
            }
            .padding(.top, 8)

            Spacer()

            Text("本地摘要无需 API Key。大模型为可选项，密钥只写入钥匙串，不入库。")
                .font(LushuType.caption())
                .foregroundStyle(LushuTheme.softInk)
        }
        .padding(40)
        .frame(width: 380, alignment: .leading)
        .background(LushuTheme.paper)
    }

    private var rightPane: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("选择材料来源")
                    .font(LushuType.section())
                    .foregroundStyle(LushuTheme.ink)
                Spacer()
                if !appState.sources.isEmpty {
                    Button("返回工作区") {
                        appState.showOnboarding = false
                    }
                    .buttonStyle(.plain)
                    .font(LushuType.caption())
                    .foregroundStyle(LushuTheme.ink)
                }
                Button("载入示例案件") {
                    appState.loadSamples()
                    appState.flash("已载入两件示例，便于审阅完整界面。")
                }
                .buttonStyle(.plain)
                .font(LushuType.caption())
                .foregroundStyle(LushuTheme.softInk)
            }

            Text("优先使用案匣或 iCloud 中的案件文件夹；若尚未建柜，再导入文件或整个文件夹。")
                .font(LushuType.body())
                .foregroundStyle(LushuTheme.softInk)

            HStack(alignment: .top, spacing: 16) {
                SourceChoiceCard(
                    eyebrow: "优先",
                    title: "选择案匣文件夹",
                    detail: "指向案匣 / iCloud 案件目录。一次授权，持续读取。本轮界面可走通，系统选档与书签下一轮接入。",
                    symbol: "externaldrive.connected.to.line.below",
                    actionTitle: "选择文件夹"
                ) {
                    appState.chooseAnxiaFolder()
                }

                SourceChoiceCard(
                    eyebrow: "回退",
                    title: "导入文件或文件夹",
                    detail: "导入单个、多个文件，或整个案件夹。支持 txt / md / pdf / docx 列入材料库。",
                    symbol: "square.and.arrow.down",
                    actionTitle: "导入材料"
                ) {
                    appState.importFolder()
                }
            }

            HStack(spacing: 10) {
                Button("仅导入文件…") { appState.importFiles() }
                    .buttonStyle(.plain)
                    .font(LushuType.body())
                    .foregroundStyle(LushuTheme.ink)
                Text("·")
                    .foregroundStyle(LushuTheme.softInk)
                Button("设置（大模型密钥）") { appState.showSettings = true }
                    .buttonStyle(.plain)
                    .font(LushuType.body())
                    .foregroundStyle(LushuTheme.ink)
            }
            .padding(.top, 4)

            Spacer()
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func familyRow(name: String, role: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(LushuTheme.ink)
                .frame(width: 36, alignment: .leading)
            Text(role)
                .font(LushuType.body())
                .foregroundStyle(LushuTheme.softInk)
        }
    }
}

struct SourceChoiceCard: View {
    let eyebrow: String
    let title: String
    let detail: String
    let symbol: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(eyebrow)
                .font(LushuType.eyebrow())
                .foregroundStyle(LushuTheme.gold)
                .tracking(1.1)

            HStack(alignment: .center, spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(LushuTheme.ink)
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(LushuTheme.ink)
            }

            Text(detail)
                .font(LushuType.body())
                .foregroundStyle(LushuTheme.softInk)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 12)

            Button(action: action) {
                Text(actionTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(LushuTheme.paper)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(LushuTheme.ink)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, minHeight: 220, alignment: .topLeading)
        .lushuCard()
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AppState())
        .frame(width: 1100, height: 720)
}
