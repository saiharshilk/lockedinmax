import SwiftUI

enum Typography {
    enum Style: String, CaseIterable, Identifiable {
        case heroNumber, title, sectionLabel, rowTitle, body, caption

        var id: String { rawValue }

        var font: Font {
            switch self {
            case .heroNumber:
                Theme.Fonts.mono(size: 48, weight: .semibold, relativeTo: .largeTitle)
            case .title:
                Theme.Fonts.serif(size: 30, relativeTo: .title)
            case .sectionLabel:
                Theme.Fonts.mono(size: 11, relativeTo: .caption)
            case .rowTitle:
                Theme.Fonts.mono(size: 13, weight: .semibold, relativeTo: .subheadline)
            case .body:
                Theme.Fonts.mono(size: 15, relativeTo: .body)
            case .caption:
                Theme.Fonts.mono(size: 12, relativeTo: .caption)
            }
        }

        var tracking: CGFloat { self == .sectionLabel ? 2 : 0 }

        var sample: String {
            switch self {
            case .heroNumber: "34.5 hrs"
            case .title: "Market Close"
            case .sectionLabel: "Time Invested"
            case .rowTitle: "Math position"
            case .body: "A focused day in the city."
            case .caption: "Local only. Built for focus."
            }
        }
    }

    static let heroNumber = Style.heroNumber.font
    static let title = Style.title.font
    static let sectionLabel = Style.sectionLabel.font
    static let rowTitle = Style.rowTitle.font
    static let body = Style.body.font
    static let caption = Style.caption.font
    static let buttonTracking: CGFloat = 2
}

private struct TypographyModifier: ViewModifier {
    let style: Typography.Style

    func body(content: Content) -> some View {
        content
            .font(style.font)
            .tracking(style.tracking)
            .textCase(style == .sectionLabel ? .uppercase : nil)
    }
}

extension View {
    func typography(_ style: Typography.Style) -> some View {
        modifier(TypographyModifier(style: style))
    }
}

#Preview {
    VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
        ForEach(Typography.Style.allCases) { style in
            Text(style.sample).typography(style)
        }
    }
    .foregroundStyle(Theme.textPrimary)
    .padding(Theme.Spacing.xl)
    .background(Theme.background)
    .preferredColorScheme(.dark)
}
