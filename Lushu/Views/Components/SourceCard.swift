import SwiftUI

/// 侧栏与引导共用的来源说明条，避免工作区与引导视觉分裂。
struct SourceMetaLine: View {
    let origin: SourceOrigin
    let caption: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: origin.symbolName)
                .font(.system(size: 11))
            Text(origin.title)
            Text("·")
            Text(caption)
                .lineLimit(1)
        }
        .font(LushuType.caption())
        .foregroundStyle(LushuTheme.softInk)
    }
}
