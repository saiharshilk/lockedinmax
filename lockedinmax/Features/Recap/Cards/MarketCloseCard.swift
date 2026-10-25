import SwiftUI

struct MarketCloseCard: View {
    let data: MarketCloseCardData

    private var total: Double { data.sessions.reduce(0) { $0 + Analytics.boundedHours($1.hours) } }
    private var previousTotal: Double { data.previousDaySessions.reduce(0) { $0 + Analytics.boundedHours($1.hours) } }
    private var rows: [(id: UUID, name: String, colorHex: String, hours: Double)] {
        var grouped: [UUID: [RecapSessionValue]] = [:]
        for session in data.sessions {
            guard let id = session.activityID else { continue }
            grouped[id, default: []].append(session)
        }
        return grouped.compactMap { id, entries in
            guard let first = entries.first else { return nil }
            return (id, first.activityName, first.activityColorHex,
                    entries.reduce(0) { $0 + Analytics.boundedHours($1.hours) })
        }.sorted { $0.hours > $1.hours }
    }
    private var primaryColor: Color { data.background == .neon ? Theme.onAccent : Theme.textPrimary }
    private var secondaryColor: Color { data.background == .neon ? Theme.onAccent.opacity(0.7) : Theme.textSecondary }

    var body: some View {
        ZStack {
            RecapCardBackdrop(background: data.background, format: data.format)
            VStack(alignment: .leading, spacing: data.format == .story ? 5 : 9) {
                CardHeader(title: "MARKET CLOSE", date: data.date)
                Text("Market Close").font(Theme.Fonts.serif(size: 30, relativeTo: .title))
                    .foregroundStyle(primaryColor).lineLimit(1).minimumScaleFactor(0.7)
                Text(data.date.formatted(date: .complete, time: .omitted).uppercased())
                    .typography(.sectionLabel).foregroundStyle(secondaryColor).lineLimit(1)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(Formatters.hours(total)).font(Theme.Fonts.mono(size: 31, weight: .medium, relativeTo: .largeTitle))
                        .foregroundStyle(primaryColor).lineLimit(1).minimumScaleFactor(0.65)
                    DeltaLabel(value: total - previousTotal,
                               text: Formatters.delta(hours: total - previousTotal,
                                   percent: Analytics.percentChange(current: total, previous: previousTotal)) + " vs prior",
                               neutralText: "0.0 hrs")
                        .lineLimit(1).minimumScaleFactor(0.6)
                }
                sevenDayChart
                VStack(spacing: 4) {
                    ForEach(Array(rows.prefix(5)), id: \.id) { row in positionRow(row) }
                    if rows.count > 5 {
                        Text("+ \(rows.count - 5) MORE POSITIONS").typography(.caption).foregroundStyle(secondaryColor)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                VStack(spacing: 5) {
                    ForEach(data.scores.prefix(3)) { entry in
                        HStack {
                            Text(entry.name.uppercased()).typography(.caption).foregroundStyle(secondaryColor).lineLimit(1)
                            Spacer(minLength: 4)
                            Text("\(Formatters.metricValue(entry.value))\(scoreChange(entry.change))")
                                .typography(.rowTitle).foregroundStyle(primaryColor).lineLimit(1).fixedSize()
                        }
                    }
                }
                Spacer(minLength: 0)
                CardFooterTicker(sessions: data.sessions, previousSessions: data.previousDaySessions,
                                 scores: data.scores.map { RecapScoreValue(id: $0.id, date: data.date, metricName: $0.name, value: $0.value) })
                Text("lockedinmax").font(Theme.Fonts.mono(size: 9)).foregroundStyle(secondaryColor)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(24)
            .padding(.top, data.format == .story ? data.format.size.height * 0.14 : 0)
            .padding(.bottom, data.format == .story ? data.format.size.height * 0.20 : 0)
            .frame(width: data.format.size.width, height: data.format.size.height, alignment: .topLeading)
        }
        .frame(width: data.format.size.width, height: data.format.size.height).clipped()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Market Close, \(Formatters.hours(total))")
    }

    private var sevenDayChart: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("7 DAYS").typography(.sectionLabel).foregroundStyle(secondaryColor)
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(Array((data.sevenDayHours.isEmpty ? Array(repeating: 0.0, count: 7) : data.sevenDayHours).enumerated()), id: \.offset) { index, hours in
                    let selected = index == (data.sevenDayHours.isEmpty ? 6 : data.sevenDayHours.count - 1)
                    VStack(spacing: 3) {
                        RoundedRectangle(cornerRadius: 2).fill(selected ? primaryColor : Theme.accent)
                            .frame(maxWidth: .infinity).frame(height: max(3, 26 * CGFloat(hours / max(data.sevenDayHours.max() ?? 0, 0.001))))
                            .overlay(RoundedRectangle(cornerRadius: 2).stroke(selected ? Theme.accent : .clear, lineWidth: 1))
                        Text(String(Calendar.current.shortWeekdaySymbols[(Calendar.current.component(.weekday, from: Calendar.current.date(byAdding: .day, value: index - 6, to: data.date) ?? data.date) - 1)].prefix(1)))
                            .font(Theme.Fonts.mono(size: 8)).foregroundStyle(secondaryColor)
                    }
                }
            }.frame(height: 32, alignment: .bottom)
        }
    }

    private func scoreChange(_ change: Double?) -> String {
        guard let change, change.isFinite, abs(change) >= 0.0001 else { return "" }
        return " \(change > 0 ? "▲" : "▼") \(Formatters.metricValue(abs(change)))"
    }

    private func positionRow(_ row: (id: UUID, name: String, colorHex: String, hours: Double)) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 7) {
                Circle().fill(Theme.activityColor(row.colorHex)).frame(width: 7, height: 7)
                Text(row.name).typography(.caption).foregroundStyle(primaryColor).lineLimit(1).truncationMode(.tail)
                Spacer(minLength: 4)
                Text(Formatters.hours(row.hours)).typography(.rowTitle).foregroundStyle(primaryColor).fixedSize()
            }
            GeometryReader { geometry in
                Capsule().fill(data.background == .neon ? Theme.onAccent.opacity(0.2) : Theme.hairline)
                    .overlay(alignment: .leading) {
                        Capsule().fill(Theme.activityColor(row.colorHex))
                            .frame(width: geometry.size.width * (total > 0 ? row.hours / total : 0))
                    }
            }.frame(height: 3)
        }
    }
}
