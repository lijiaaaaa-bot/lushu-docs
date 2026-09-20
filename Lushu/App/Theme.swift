import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// 律书 Theme —— 与案匣 Anxia **shipping** `Theme.swift` 对齐。
/// 色值来自 LIVE Simulator + 案匣 Theme.swift，禁止另起色板。
enum Theme {
    static let paper = Color(anxiaLight: 0xF4EFE6, dark: 0x12100C)
    static let card = Color(anxiaLight: 0xFBF7F0, dark: 0x1C1914)
    static let ink = Color(anxiaLight: 0x2A2118, dark: 0xEDE6DA)
    static let mute = Color(anxiaLight: 0x6F675C, dark: 0x9A9084)
    static let walnut = Color(anxiaLight: 0x4A3426, dark: 0xC4A484)
    static let brass = Color(anxiaLight: 0xA6844A, dark: 0xC9A86A)

    static let cornerRadius: CGFloat = 14
    static let pagePad: CGFloat = 22

    static var walnutStroke: Color { walnut.opacity(0.12) }
    static var inkShadow: Color { ink.opacity(0.08) }

    static let sidebarIdeal: CGFloat = 280
    static let materialsIdeal: CGFloat = 380

    /// 品牌 / 屏幕标题：Noto Serif SC Black／Bold。未嵌入字体时回退宋体或系统 serif。
    static func brandTitle(_ size: CGFloat = 34) -> Font {
        serif(size, black: true)
    }

    static func screenTitle(_ size: CGFloat = 20) -> Font {
        serif(size, black: false)
    }

    static func serifBody(_ size: CGFloat = 14) -> Font {
        serif(size, black: false, body: true)
    }

    static func caption(_ size: CGFloat = 11) -> Font {
        .system(size: size, weight: .regular)
    }

    static func serif(_ size: CGFloat, black: Bool, body: Bool = false) -> Font {
        #if os(macOS)
        let candidates: [String]
        if body {
            candidates = [
                "NotoSerifSC-Regular",
                "Noto Serif SC",
                "NotoSerifCJKsc-Regular",
                "Noto Serif CJK SC",
                "Songti SC",
                "STSongti-SC-Regular"
            ]
        } else if black {
            candidates = [
                "NotoSerifSC-Black",
                "Noto Serif SC Black",
                "NotoSerifCJKsc-Black",
                "Noto Serif CJK SC",
                "Songti SC Black",
                "STSongti-SC-Black"
            ]
        } else {
            candidates = [
                "NotoSerifSC-Bold",
                "Noto Serif SC Bold",
                "NotoSerifCJKsc-Bold",
                "Noto Serif CJK SC",
                "Songti SC Bold",
                "STSongti-SC-Bold"
            ]
        }
        for name in candidates {
            if NSFont(name: name, size: size) != nil {
                return .custom(name, size: size)
            }
        }
        #endif
        let weight: Font.Weight = body ? .regular : (black ? .heavy : .bold)
        return .system(size: size, weight: weight, design: .serif)
    }
}

extension Color {
    /// 案匣动态色：light / dark 各一枚 0xRRGGBB。
    init(anxiaLight light: UInt32, dark: UInt32) {
        #if os(macOS)
        self.init(nsColor: NSColor(name: "anxia.\(light).\(dark)", dynamicProvider: { appearance in
            let useDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return Color.nsRGB(useDark ? dark : light)
        }))
        #else
        self.init(uiColor: UIColor { traits in
            Color.uiRGB(traits.userInterfaceStyle == .dark ? dark : light)
        })
        #endif
    }

    #if os(macOS)
    fileprivate static func nsRGB(_ hex: UInt32) -> NSColor {
        NSColor(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
    #else
    fileprivate static func uiRGB(_ hex: UInt32) -> UIColor {
        UIColor(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
    #endif
}

struct ThemeCardModifier: ViewModifier {
    var emphasized: Bool = false
    var outlined: Bool = false

    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(outlined ? Theme.paper : Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                    .stroke(emphasized ? Theme.brass : Theme.walnutStroke, lineWidth: emphasized ? 1.2 : 1)
            )
            .shadow(color: outlined ? .clear : Theme.inkShadow, radius: outlined ? 0 : 7, y: outlined ? 0 : 2)
    }
}

extension View {
    func themeCard(emphasized: Bool = false, outlined: Bool = false) -> some View {
        modifier(ThemeCardModifier(emphasized: emphasized, outlined: outlined))
    }
}
