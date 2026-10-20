import SwiftUI

struct MarketCloseCard: View {
    let data: MarketCloseCardData

    private var total: Double { data.sessions.reduce(0) { $0 + Analytics.boundedHours($1.hours) } }
    private var previousTotal: Double { data.previousDaySessions.reduce(0) { $0 + Analytics.boundedHours($1.hours) } }
    private var deltaText: String {
        let change = Analytics.percentChange(current: total, previous: previousTotal)
        return "\(Formatters.delta(hours: total - previousTotal, percent: change)) vs prior"
    }
    private var rows: [(id: UUID, name: String, colorHex: String, hours: Double)] {
        Dictionary(grouping: data.sessions.filter { $0.activityID != nil }, by: { $0.activityID! })
            .compactMap { id, entries in
                guard let first = entries.first else { return nil }
                return (id, first.activityName, first.activityColorHex,
                        entries.reduce(0) { $0 + Analytics.boundedHours($1.hours) })
            }.sorted { $0.hours > $1.hours }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.background
            VStack { Spacer(); SkylineShape().fill(Theme.surface).frame(height: data.format.size.height * 0.2) }
                .allowsHitTesting(false)
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                CardHeader(date: data.date)
                Text("Market Close").font(Theme.Fonts.serif(size: 34, relativeTo: .title))
                    .foregroundStyle(Theme.textPrimary).lineLimit(1).minimumScaleFactor(0.7)
                    .accessibilityAddTraits(.isHeader)
                Text(data.date.formatted(.dateTime.weekday(.wide).day().month(.wide)).uppercased())
                    .typography(.sectionLabel).foregroundStyle(Theme.textSecondary).lineLimit(1)
                HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.md) {
                    Text(Formatters.hours(total)).font(Theme.Fonts.mono(size: 31, weight: .medium, relativeTo: .largeTitle))
                        .foregroundStyle(Theme.textPrimary).lineLimit(1).minimumScaleFactor(0.65)
                    DeltaLabel(value: total - previousTotal, text: deltaText,
                               neutralText: "0.0 hrs").lineLimit(1).minimumScaleFactor(0.6)
                }
                VStack(spacing: Theme.Spacing.sm) {
                    ForEach(Array(rows.prefix(5)), id: \.id) { row in positionRow(row) }
                    if rows.count > 5 {
                        Text("+ \(rows.count - 5) MORE POSITIONS").typography(.caption).foregroundStyle(Theme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                ForEach(data.scores.sorted { $0.date < $1.date }.prefix(3)) { entry in
                    HStack {
                        Text(entry.metricName.uppercased()).typography(.caption).foregroundStyle(Theme.textSecondary)
                        Spacer()
                        Text(Formatters.metricValue(entry.value)).typography(.rowTitle).foregroundStyle(Theme.textPrimary)
                    }
                }
                Spacer(minLength: 0)
                CardFooterTicker(sessions: data.sessions, previousSessions: data.previousDaySessions, scores: data.scores)
            }
            .padding(Theme.Spacing.xl)
        }
        .frame(width: data.format.size.width, height: data.format.size.height).clipped()
        .accessibilityElement(children: .combine)
    }

    private func positionRow(_ row: (id: UUID, name: String, colorHex: String, hours: Double)) -> some View {
        VStack(spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.sm) {
                Circle().fill(Theme.activityColor(row.colorHex)).frame(width: 7, height: 7)
                Text(row.name).typography(.caption).foregroundStyle(Theme.textPrimary).lineLimit(1)
                    .truncationMode(.tail).layoutPriority(0)
                Spacer(minLength: Theme.Spacing.xs)
                Text(Formatters.hours(row.hours)).typography(.rowTitle).foregroundStyle(Theme.textPrimary)
                    .fixedSize().layoutPriority(1)
            }
            GeometryReader { geometry in
                Capsule().fill(Theme.hairline).overlay(alignment: .leading) {
                    Capsule().fill(Theme.activityColor(row.colorHex))
                        .frame(width: geometry.size.width * (total > 0 ? row.hours / total : 0))
                }
            }.frame(height: 3)
        }
    }
}

#if DEBUG
#Preview("Market Close 4:5") {
    let today = Calendar.current.startOfDay(for: .now)
    let sessions = (0..<7).map { index in
        RecapSessionValue(date: today, hours: Double(7 - index), activityID: UUID(),
            activityName: ["Math", "Chess", "Real Analysis", "Walks", "Language", "Music", "Projects"][index],
            activityColorHex: Theme.activityColorPresets[index])
    }
    MarketCloseCard(data: MarketCloseCardData(date: today, sessions: sessions,
        previousDaySessions: [], scores: [], format: .portrait))
}
#endif
