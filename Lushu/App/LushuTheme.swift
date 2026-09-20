import SwiftUI

/// 与案匣家族一致的视觉令牌：墨青、浅空、纸白、点金。
enum LushuTheme {
    static let ink = Color(red: 23 / 255, green: 63 / 255, blue: 89 / 255)
    static let softInk = Color(red: 71 / 255, green: 106 / 255, blue: 128 / 255)
    static let sky = Color(red: 234 / 255, green: 245 / 255, blue: 251 / 255)
    static let paper = Color.white
    static let gold = Color(red: 184 / 255, green: 139 / 255, blue: 46 / 255)
    static let softGold = Color(red: 244 / 255, green: 236 / 255, blue: 212 / 255)
    static let ice = Color(red: 131 / 255, green: 206 / 255, blue: 233 / 255)
    static let line = Color(red: 184 / 255, green: 223 / 255, blue: 239 / 255)
    static let hairline = Color(red: 23 / 255, green: 63 / 255, blue: 89 / 255).opacity(0.12)

    static let sidebarWidth: CGFloat = 248
    static let contentMaxWidth: CGFloat = 920
}

enum LushuType {
    static func eyebrow() -> Font { .system(size: 11, weight: .semibold) }
    static func title() -> Font { .system(size: 26, weight: .semibold) }
    static func section() -> Font { .system(size: 16, weight: .semibold) }
    static func body() -> Font { .system(size: 13) }
    static func caption() -> Font { .system(size: 11) }
    static func mono() -> Font { .system(size: 13, design: .monospaced) }
}

struct LushuCardModifier: ViewModifier {
    var emphasized: Bool = false

    func body(content: Content) -> some View {
        content
            .padding(18)
            .background(LushuTheme.paper)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(emphasized ? LushuTheme.gold : LushuTheme.line, lineWidth: emphasized ? 1.5 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

extension View {
    func lushuCard(emphasized: Bool = false) -> some View {
        modifier(LushuCardModifier(emphasized: emphasized))
    }
}

struct StatusChip: View {
    enum Kind {
        case available
        case upcoming
        case sample
        case local
        case imported
        case folder
    }

    let kind: Kind
    var label: String? = nil

    private var text: String {
        if let label { return label }
        switch kind {
        case .available: return "可用"
        case .upcoming: return "筹备中"
        case .sample: return "示例"
        case .local: return "本地"
        case .imported: return "导入"
        case .folder: return "案匣"
        }
    }

    private var fill: Color {
        switch kind {
        case .available, .local, .folder: return LushuTheme.sky
        case .upcoming: return LushuTheme.softGold
        case .sample, .imported: return LushuTheme.softGold
        }
    }

    var body: some View {
        Text(text)
            .font(LushuType.caption())
            .foregroundStyle(LushuTheme.ink)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(fill)
            .overlay(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .stroke(LushuTheme.line, lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
    }
}
