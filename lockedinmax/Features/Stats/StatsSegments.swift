import SwiftUI

struct StatsSegments<Value: Hashable & CaseIterable & RawRepresentable>: View where Value.RawValue == String {
    @Binding var selection: Value

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            ForEach(Array(Value.allCases), id: \.self) { value in
                Button { selection = value } label: {
                    Text(value.rawValue)
                        .typography(.rowTitle)
                        .foregroundStyle(selection == value ? Theme.onAccent : Theme.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: Theme.minimumTapHeight)
                        .contentShape(Rectangle())
                        .background(selection == value ? Theme.accent : Theme.surface,
                                    in: RoundedRectangle(cornerRadius: Theme.Radius.small))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(value.rawValue)
                .accessibilityAddTraits(selection == value ? .isSelected : [])
            }
        }
        .padding(Theme.Spacing.xs)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.medium))
    }
}

#Preview {
    struct Preview: View {
        enum Choice: String, CaseIterable { case time = "TIME", scores = "SCORES" }
        @State var selection: Choice = .time
        var body: some View { StatsSegments(selection: $selection).padding().background(Theme.background) }
    }
    return Preview()
}
