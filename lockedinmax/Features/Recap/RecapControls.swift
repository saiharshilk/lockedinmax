import SwiftUI

enum RecapMode: String, CaseIterable, Identifiable {
    case session = "SESSION"
    case day = "MARKET CLOSE"
    case week = "WEEKLY"
    var id: String { rawValue }
}

struct RecapModeControl: View {
    @Binding var mode: RecapMode
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 2) {
            ForEach(RecapMode.allCases) { option in
                Button {
                    if reduceMotion { mode = option }
                    else { withAnimation(.easeOut(duration: 0.18)) { mode = option } }
                } label: {
                    Text(option.rawValue).typography(.caption).lineLimit(1).minimumScaleFactor(0.6)
                        .foregroundStyle(mode == option ? Theme.onAccent : Theme.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: Theme.minimumTapHeight)
                        .background(mode == option ? Theme.accent : Theme.surface,
                                    in: RoundedRectangle(cornerRadius: Theme.Radius.small))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(option.rawValue)
                .accessibilityAddTraits(mode == option ? .isSelected : [])
            }
        }
        .padding(Theme.Spacing.xs)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.medium))
        .accessibilityElement(children: .contain)
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
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(title).typography(.sectionLabel).foregroundStyle(Theme.textTertiary)
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

struct RecapWeekPicker: View {
    @Binding var selectedWeek: Date
    private let calendar = Calendar.current
    private var currentStart: Date { StatsAnalytics.period(kind: .week, anchor: .now, calendar: calendar).start }
    private var selectedStart: Date { StatsAnalytics.period(kind: .week, anchor: selectedWeek, calendar: calendar).start }

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Button { shift(-1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                .disabled(selectedStart <= calendar.date(byAdding: .weekOfYear, value: -52, to: currentStart) ?? currentStart)
            Text(StatsFormat.period(.week, period: StatsAnalytics.period(kind: .week, anchor: selectedStart, calendar: calendar)))
                .font(Theme.Fonts.mono(size: 12, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)
            Button { shift(1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }
                .disabled(selectedStart >= currentStart)
        }
        .foregroundStyle(Theme.accent)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.medium))
        .accessibilityElement(children: .contain)
    }

    private func shift(_ amount: Int) {
        guard let next = calendar.date(byAdding: .weekOfYear, value: amount, to: selectedStart) else { return }
        selectedWeek = min(next, currentStart)
    }
}

#Preview {
    VStack {
        RecapModeControl(mode: .constant(.session))
        RecapValuePicker(title: "FORMAT", options: RecapCardFormat.allCases, selection: .constant(.portrait))
        RecapWeekPicker(selectedWeek: .constant(.now))
    }.padding().background(Theme.background).preferredColorScheme(.dark)
}
