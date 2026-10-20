import SwiftUI

struct DeltaLabel: View {
    let value: Double
    let text: String
    private let neutralText: String

    init(value: Double, text: String, neutralText: String = "0.0 hrs") {
        self.value = value
        self.text = text
        self.neutralText = neutralText
    }

    private var isNeutral: Bool { abs(value) < 0.005 }
    private var isUp: Bool { value > 0 }
    private var displayText: String { isNeutral ? neutralText : text }

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            if !isNeutral { Text(isUp ? "▲" : "▼") }
            Text(displayText)
        }
        .typography(.rowTitle)
        .foregroundStyle(isNeutral ? Theme.textSecondary : isUp ? Theme.up : Theme.down)
        .frame(minHeight: Theme.minimumTapHeight, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isNeutral ? neutralText : "\(isUp ? "Up" : "Down") \(displayText)")
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
