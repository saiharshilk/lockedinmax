import SwiftUI

struct WeeklyCard: View {
    let data: WeeklyCardData

    private var primaryColor: Color { data.background == .neon ? Theme.onAccent : Theme.textPrimary }
    private var secondaryColor: Color { data.background == .neon ? Theme.onAccent.opacity(0.72) : Theme.textSecondary }
    private var bestDayIndex: Int? {
        data.days.indices.filter { !data.days[$0].isFuture && data.days[$0].total > 0 }
            .max(by: { data.days[$0].total < data.days[$1].total })
    }

    var body: some View {
        ZStack {
            RecapCardBackdrop(background: data.background, format: data.format)
            VStack(alignment: .leading, spacing: data.format == .story ? 5 : 8) {
                CardHeader(title: "WEEKLY · \(StatsFormat.period(.week, period: StatsAnalytics.period(kind: .week, anchor: data.startDate)))")
                Text("Weekly Report").font(Theme.Fonts.serif(size: 34, relativeTo: .title))
                    .foregroundStyle(primaryColor).lineLimit(1).minimumScaleFactor(0.7)
                Text("TIME INVESTED").typography(.sectionLabel).foregroundStyle(secondaryColor)
                Text(Formatters.hours(data.totalHours)).font(Theme.Fonts.mono(size: 32, weight: .medium, relativeTo: .largeTitle))
                    .foregroundStyle(primaryColor).lineLimit(1).minimumScaleFactor(0.6)
                HStack(spacing: 5) {
                    if abs(data.deltaHours) >= 0.005 { Text(data.deltaHours > 0 ? "▲" : "▼") }
                    Text("\(Formatters.delta(hours: data.deltaHours, percent: data.deltaPercent)) \(data.comparisonCaption)")
                }.typography(.caption).foregroundStyle(abs(data.deltaHours) < 0.005 ? secondaryColor : data.deltaHours > 0 ? Theme.up : Theme.down)
                    .lineLimit(1).minimumScaleFactor(0.7)
                dailyBars
                if data.totalHours <= 0 {
                    Text("NO TIME LOGGED THIS WEEK").typography(.sectionLabel).foregroundStyle(secondaryColor)
                        .lineLimit(1).minimumScaleFactor(0.65)
                }
                VStack(spacing: 3) {
                    ForEach(data.positions.prefix(3)) { position in
                        HStack(spacing: 7) {
                            Circle().fill(Theme.activityColor(position.colorHex)).frame(width: 7, height: 7)
                            Text(position.name).typography(.caption).foregroundStyle(primaryColor).lineLimit(1)
                            Spacer(minLength: 4)
                            Text("\(Formatters.hours(position.hours)) · \(Formatters.percent(position.share * 100).replacingOccurrences(of: "+", with: ""))")
                                .typography(.caption).foregroundStyle(primaryColor).fixedSize()
                        }
                    }
                }
                HStack(spacing: 6) {
                    statChip("ACTIVE DAYS", value: "\(data.activeDays) / \(data.isCurrentWeek ? data.elapsedDays : 7)")
                    statChip("AVG / ACTIVE DAY", value: Formatters.hours(data.averagePerActiveDay))
                    statChip("STREAK", value: data.streakDays == 0 ? "—" : data.streakDays == 1 ? "1 DAY" : "\(data.streakDays) DAYS")
                }
                VStack(spacing: 3) {
                    ForEach(data.scores.prefix(3)) { score in
                        HStack {
                            Text(score.name.uppercased()).typography(.caption).foregroundStyle(secondaryColor).lineLimit(1)
                            Spacer(minLength: 4)
                            Text("\(Formatters.metricValue(score.value))\(score.change.map { abs($0) >= 0.0001 ? " \($0 > 0 ? "▲" : "▼") \(Formatters.metricValue(abs($0)))" : "" } ?? "")")
                                .typography(.caption).foregroundStyle(primaryColor).lineLimit(1).fixedSize()
                        }
                    }
                }
                Spacer(minLength: 0)
                HStack {
                    Text("lockedinmax").font(Theme.Fonts.mono(size: 9)).foregroundStyle(secondaryColor)
                    Spacer()
                    Text(StatsFormat.period(.week, period: StatsAnalytics.period(kind: .week, anchor: data.startDate)))
                        .font(Theme.Fonts.mono(size: 8)).foregroundStyle(secondaryColor).lineLimit(1)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, data.format == .story ? data.format.size.height * 0.14 : 24)
            .padding(.bottom, data.format == .story ? data.format.size.height * 0.20 : 24)
            .frame(width: data.format.size.width, height: data.format.size.height, alignment: .topLeading)
        }
        .frame(width: data.format.size.width, height: data.format.size.height).clipped()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Weekly report, \(StatsFormat.period(.week, period: StatsAnalytics.period(kind: .week, anchor: data.startDate))), \(Formatters.hours(data.totalHours)), \(data.comparisonCaption); top position \(data.positions.first.map { "\($0.name) \(Formatters.hours($0.hours))" } ?? "none")")
    }

    private var dailyBars: some View {
        let maximum = max(data.days.map(\.total).max() ?? 0, 0.001)
        return HStack(alignment: .bottom, spacing: 7) {
            ForEach(Array(data.days.enumerated()), id: \.element.id) { index, day in
                VStack(spacing: 3) {
                    if bestDayIndex == index { Text("BEST").font(Theme.Fonts.mono(size: 7, weight: .semibold)).foregroundStyle(Theme.accent) }
                    GeometryReader { geometry in
                        VStack(spacing: 0) {
                            if day.stacks.isEmpty {
                                Rectangle().fill(secondaryColor.opacity(day.isFuture ? 0.12 : 0.25)).frame(height: 2)
                            } else {
                                ForEach(day.stacks) { slice in
                                    Rectangle().fill(Theme.activityColor(slice.colorHex))
                                        .frame(height: max(1, geometry.size.height * CGFloat(slice.hours / maximum)))
                                }
                            }
                        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    }
                    .frame(height: 38)
                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(bestDayIndex == index ? Theme.accent : .clear, lineWidth: 1.5))
                    .opacity(day.isFuture ? 0.35 : 1)
                    Text(String(Calendar.current.shortWeekdaySymbols[Calendar.current.component(.weekday, from: day.date) - 1].prefix(1)))
                        .font(Theme.Fonts.mono(size: 8)).foregroundStyle(secondaryColor)
                }.frame(maxWidth: .infinity)
            }
        }.frame(height: 57)
    }

    private func statChip(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(Theme.Fonts.mono(size: 7, weight: .medium)).tracking(0.5).lineLimit(1).foregroundStyle(secondaryColor)
            Text(value).font(Theme.Fonts.mono(size: 10, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.5)
                .fixedSize(horizontal: true, vertical: false).foregroundStyle(primaryColor)
        }.frame(maxWidth: .infinity, minHeight: 34, alignment: .leading).padding(5)
            .background(data.background == .neon ? Theme.onAccent.opacity(0.08) : Theme.surface.opacity(0.8), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(data.background == .neon ? Theme.onAccent.opacity(0.22) : Theme.hairline, lineWidth: 1))
    }
}
