import SwiftUI
#if os(iOS)
import UIKit
#endif

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

enum Theme {
    static let background = Color(hex: 0x1C180D)
    static let surface = Color(hex: 0x26221A)
    static let hairline = Color(hex: 0x3A3526)
    static let textPrimary = Color(hex: 0xD4D0C9)
    static let textSecondary = Color(hex: 0x8A8783)
    static let textTertiary = Color(hex: 0xB4B1AB)
    static let accent = Color(hex: 0xCCFF00)
    static let onAccent = Color(hex: 0x1C180D)
    static let up = accent
    static let down = Color(hex: 0xFF5A5F)

    static let activityColorPresets = [
        "#CCFF00", "#63C7FF", "#C4A1FF", "#FFB86B",
        "#FF83B5", "#64DDB0", "#FFE08A", "#A9BFFF"
    ]

    static func activityColor(_ hex: String) -> Color {
        let digits = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard digits.count == 6, let value = UInt32(digits, radix: 16) else { return accent }
        return Color(hex: value)
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    enum Radius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 20
    }

    static let borderWidth: CGFloat = 1
    static let minimumTapHeight: CGFloat = 44
    static let swatchSize: CGFloat = 40

    enum Fonts {
        static func mono(size: CGFloat, weight: Font.Weight = .regular, relativeTo style: Font.TextStyle = .body) -> Font {
#if os(iOS)
            let postScriptName: String
            switch weight {
            case .semibold: postScriptName = "JetBrainsMono-SemiBold"
            case .medium: postScriptName = "JetBrainsMono-Medium"
            default: postScriptName = "JetBrainsMono-Regular"
            }
            if UIFont(name: postScriptName, size: size) != nil {
                return .custom(postScriptName, size: size, relativeTo: style)
            }
#endif
            return .system(size: size, weight: weight, design: .monospaced)
        }

        static func serif(size: CGFloat, relativeTo style: Font.TextStyle = .title) -> Font {
#if os(iOS)
            if UIFont(name: "PlayfairDisplay-Regular", size: size) != nil {
                return .custom("PlayfairDisplay-Regular", size: size, relativeTo: style).weight(.semibold)
            }
            if UIFont(name: "PlayfairDisplay-SemiBold", size: size) != nil {
                return .custom("PlayfairDisplay-SemiBold", size: size, relativeTo: style)
            }
#endif
            return .system(size: size, weight: .semibold, design: .serif)
        }

        static func isCustomFontAvailable(_ name: String) -> Bool {
#if os(iOS)
            return UIFont(name: name, size: 16) != nil
#else
            return false
#endif
        }
    }

    struct Swatch: Identifiable {
        let name: String
        let hex: String
        let color: Color
        var id: String { name }
    }

    // Native TabView has no SwiftUI API for the unselected item color.
    static func configureTabBarAppearance() {
#if os(iOS)
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(background)
        appearance.shadowColor = UIColor(hairline)
        for item in [appearance.stackedLayoutAppearance,
                     appearance.inlineLayoutAppearance,
                     appearance.compactInlineLayoutAppearance] {
            item.normal.iconColor = UIColor(textSecondary)
            item.normal.titleTextAttributes = [.foregroundColor: UIColor(textSecondary)]
            item.selected.iconColor = UIColor(accent)
            item.selected.titleTextAttributes = [.foregroundColor: UIColor(accent)]
        }
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        UITabBar.appearance().unselectedItemTintColor = UIColor(textSecondary)
#endif
    }

    static let swatches: [Swatch] = [
        .init(name: "background", hex: "#1C180D", color: background),
        .init(name: "surface", hex: "#26221A", color: surface),
        .init(name: "hairline", hex: "#3A3526", color: hairline),
        .init(name: "textPrimary", hex: "#D4D0C9", color: textPrimary),
        .init(name: "textSecondary", hex: "#8A8783", color: textSecondary),
        .init(name: "textTertiary", hex: "#B4B1AB", color: textTertiary),
        .init(name: "accent", hex: "#CCFF00", color: accent),
        .init(name: "onAccent", hex: "#1C180D", color: onAccent),
        .init(name: "up", hex: "#CCFF00", color: up),
        .init(name: "down", hex: "#FF5A5F", color: down)
    ]
}
