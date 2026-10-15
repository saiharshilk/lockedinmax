import SwiftUI

struct RecapMarketPicker: View {
    @Binding var selectedDay: Date
    let activeDays: [Date]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            DatePicker("Market Close date", selection: $selectedDay, in: ...Date.now, displayedComponents: .date)
                .datePickerStyle(.compact).typography(.caption).tint(Theme.accent)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.sm) {
                    ForEach(activeDays, id: \.self) { day in
                        Button { selectedDay = day } label: {
                            Text(day.formatted(.dateTime.day().month(.abbreviated)).uppercased())
                                .typography(.caption)
                                .foregroundStyle(Calendar.current.isDate(day, inSameDayAs: selectedDay) ? Theme.onAccent : Theme.textSecondary)
                                .padding(.horizontal, Theme.Spacing.md).padding(.vertical, Theme.Spacing.sm)
                                .background(Calendar.current.isDate(day, inSameDayAs: selectedDay) ? Theme.accent : Theme.surface, in: Capsule())
                        }.buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

#Preview {
    RecapMarketPicker(selectedDay: .constant(.now), activeDays: [.now])
        .padding().background(Theme.background).preferredColorScheme(.dark)
}
