import SwiftUI

struct RecapModeControl: View {
    @Binding var marketClose: Bool

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            segment("SESSION", isSelected: !marketClose) { marketClose = false }
            segment("MARKET CLOSE", isSelected: marketClose) { marketClose = true }
        }
        .padding(Theme.Spacing.xs)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.medium))
    }

    private func segment(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).typography(.rowTitle).lineLimit(1).minimumScaleFactor(0.7)
                .foregroundStyle(isSelected ? Theme.onAccent : Theme.textSecondary)
                .frame(maxWidth: .infinity, minHeight: Theme.minimumTapHeight)
                .background(isSelected ? Theme.accent : Theme.surface,
                            in: RoundedRectangle(cornerRadius: Theme.Radius.small))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct RecapValuePicker<Option: RawRepresentable & CaseIterable & Identifiable & Hashable>: View where Option.RawValue == String {
    let title: String
    let options: [Option]
    @Binding var selection: Option
    var disabledOptions: Set<Option> = []
    @Environment(\.isEnabled) private var isEnabled

    init(title: String, options: [Option], selection: Binding<Option>, disabledOptions: Set<Option> = []) {
        self.title = title
        self.options = options
        self._selection = selection
        self.disabledOptions = disabledOptions
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {                Text(title).typography(.sectionLabel).foregroundStyle(Theme.textTertiary)
            HStack(spacing: Theme.Spacing.xs) {
                ForEach(options) { option in
                    Button { selection = option } label: {
                        Text(option.rawValue).typography(.caption).lineLimit(1).minimumScaleFactor(0.7)
                            .foregroundStyle(selection == option ? Theme.onAccent : Theme.textSecondary)
                            .padding(.horizontal, Theme.Spacing.sm).frame(minHeight: Theme.minimumTapHeight)
                            .background(selection == option ? Theme.accent : Theme.surface, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(title) \(option.rawValue)")
                    .accessibilityAddTraits(selection == option ? .isSelected : [])
                    .disabled(disabledOptions.contains(option))
                }
            }
        }
        .opacity(isEnabled ? 1 : 0.4)
    }
}

#Preview {
    VStack {
        RecapModeControl(marketClose: .constant(false))
        RecapValuePicker(title: "FORMAT", options: RecapCardFormat.allCases, selection: .constant(.portrait))
    }.padding().background(Theme.background).preferredColorScheme(.dark)
}
