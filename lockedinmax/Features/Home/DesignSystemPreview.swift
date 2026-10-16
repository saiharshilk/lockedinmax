import SwiftUI

#if DEBUG
struct DesignSystemPreview: View {
    @State private var range: TimeRange = .week
    @State private var buttonTapped = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxl) {
                Text("Design System Preview")
                    .typography(.title)
                    .accessibilityAddTraits(.isHeader)

                colors
                typography
                components
#if DEBUG
                DebugDataTools()
#endif
            }
            .padding(Theme.Spacing.xl)
        }
        .background(Theme.background.ignoresSafeArea())
        .foregroundStyle(Theme.textPrimary)
        .navigationTitle("lockedinmax")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
    }

    private var colors: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            SectionHeader(title: "Colors")
            VStack(spacing: Theme.Spacing.md) {
                ForEach(Theme.swatches) { swatch in
                    HStack(spacing: Theme.Spacing.md) {
                        RoundedRectangle(cornerRadius: Theme.Radius.small)
                            .fill(swatch.color)
                            .frame(width: Theme.swatchSize, height: Theme.swatchSize)
                            .overlay {
                                RoundedRectangle(cornerRadius: Theme.Radius.small)
                                    .strokeBorder(Theme.hairline, lineWidth: Theme.borderWidth)
                            }
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            Text(swatch.name).typography(.rowTitle)
                            Text(swatch.hex)
                                .typography(.caption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(Theme.Spacing.lg)
            .surfaceCard()
        }
    }

    private var typography: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            SectionHeader(title: "Typography")
            ForEach(Typography.Style.allCases) { style in
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text(style.rawValue)
                        .typography(.caption)
                        .foregroundStyle(Theme.textSecondary)
                    Text(style.sample).typography(style)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var components: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            SectionHeader(title: "Components")
            PrimaryButton(title: buttonTapped ? "BUTTON TAPPED" : "PREVIEW BUTTON") {
                buttonTapped.toggle()
            }
            RangePillBar(selection: $range)
            Text("Selected range: \(range.rawValue)")
                .typography(.caption)
                .foregroundStyle(Theme.textSecondary)
                .accessibilityIdentifier("selectedRange")
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                DeltaLabel(value: 4.2, text: "4.2 hrs (+13.9%)")
                DeltaLabel(value: -4, text: "4%")
            }
            .padding(Theme.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .surfaceCard()
        }
    }
}

#Preview {
    NavigationStack {
        DesignSystemPreview()
    }
    .tint(Theme.accent)
    .preferredColorScheme(.dark)
}
#endif
