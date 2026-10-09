import SwiftUI

struct DeltaLabel: View {
    let value: Double
    let text: String

    private var isUp: Bool { value >= 0 }

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Text(isUp ? "▲" : "▼")
            Text(text)
        }
        .typography(.rowTitle)
        .foregroundStyle(isUp ? Theme.up : Theme.down)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(isUp ? "Up" : "Down") \(text)")
    }
}

#Preview {
    VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
        DeltaLabel(value: 4.2, text: "4.2 hrs (+13.9%)")
        DeltaLabel(value: -4, text: "4%")
    }
    .padding(Theme.Spacing.lg)
    .background(Theme.background)
    .preferredColorScheme(.dark)
}
