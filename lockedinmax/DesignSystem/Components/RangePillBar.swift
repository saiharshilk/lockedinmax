import SwiftUI

enum TimeRange: String, CaseIterable, Identifiable {
    case day = "1D"
    case week = "1W"
    case month = "1M"
    case quarter = "3M"
    case year = "1Y"
    case all = "ALL"

    var id: String { rawValue }
}

struct RangePillBar<Selection>: View where Selection: CaseIterable & Hashable & RawRepresentable,
    Selection.RawValue == String {
    @Binding var selection: Selection

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            ForEach(Array(Selection.allCases), id: \.self) { range in
                Button {
                    selection = range
                } label: {
                    Text(range.rawValue)
                        .typography(.rowTitle)
                        .foregroundStyle(selection == range ? Theme.onAccent : Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: Theme.minimumTapHeight)
                        .background {
                            if selection == range {
                                RoundedRectangle(cornerRadius: Theme.Radius.small)
                                    .fill(Theme.accent)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Range \(range.rawValue)")
                .accessibilityAddTraits(selection == range ? .isSelected : [])
            }
        }
    }
}

private struct RangePillBarPreview: View {
    @State private var selection: TimeRange = .week

    var body: some View {
        RangePillBar(selection: $selection)
            .padding(Theme.Spacing.lg)
            .background(Theme.background)
    }
}

#Preview {
    RangePillBarPreview().preferredColorScheme(.dark)
}
