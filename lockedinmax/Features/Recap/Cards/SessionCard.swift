import SwiftUI
#if os(iOS)
import UIKit
#endif

struct SessionCard: View {
    let data: SessionRecapCardData

    private var average: Double {
        let values = data.activityHistory.filter { $0.hours.isFinite }
        guard !values.isEmpty else { return 0 }
        return values.reduce(0) { $0 + Analytics.boundedHours($1.hours) } / Double(values.count)
    }

    private var delta: Double? {
        let values = data.activityHistory.filter { $0.hours.isFinite }
        guard values.count > 1, average > 0 else { return nil }
        let result = (Analytics.boundedHours(data.session.hours) - average) / average * 100
        return result.isFinite ? result : nil
    }

    private var titleColor: Color { data.background == .neon ? Theme.onAccent : Theme.accent }
    private var primaryColor: Color { data.background == .neon ? Theme.onAccent : Theme.textPrimary }
    private var secondaryColor: Color { data.background == .neon ? Theme.onAccent.opacity(0.72) : Theme.textSecondary }

    var body: some View {
        ZStack {
            RecapCardBackdrop(background: data.background, format: data.format, photo: data.session.photo)
            VStack(alignment: .leading, spacing: data.format == .story ? 5 : 7) {
                CardHeader(title: "SESSION", date: data.session.date)
                HStack(alignment: .center, spacing: 10) {
                    Circle().fill(Theme.activityColor(data.session.activityColorHex))
                        .frame(width: 38, height: 38)
                        .overlay(Image(systemName: data.session.iconName).font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(data.background == .neon ? Theme.onAccent : Theme.background))
                    Text(data.session.activityName).font(Theme.Fonts.serif(size: data.format == .story ? 30 : 32, relativeTo: .largeTitle))
                        .foregroundStyle(titleColor).lineLimit(2).minimumScaleFactor(0.55)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(Formatters.hours(data.session.hours))
                        .font(Theme.Fonts.mono(size: data.format == .story ? 60 : 52, weight: .medium, relativeTo: .largeTitle))
                        .foregroundStyle(primaryColor).lineLimit(1).minimumScaleFactor(0.55)
                    Text("hrs").typography(.rowTitle).foregroundStyle(secondaryColor)
                }
                deltaView
                sparkline
                HStack(spacing: 7) {
                    statChip("TODAY", value: Formatters.hours(data.todayHours))
                    statChip("THIS WEEK", value: Formatters.hours(data.weekHours))
                    statChip("STREAK", value: data.streakDays == 0 ? "—" : data.streakDays == 1 ? "1 DAY" : "\(data.streakDays) DAYS")
                }
                if !data.caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(data.caption).font(.system(size: 15, weight: .regular, design: .serif).italic())
                        .foregroundStyle(secondaryColor).lineLimit(2).minimumScaleFactor(0.75)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                CardFooterTicker(sessions: data.daySessions, previousSessions: data.previousDaySessions, scores: data.scores)
                Text("lockedinmax").font(Theme.Fonts.mono(size: 9)).foregroundStyle(secondaryColor.opacity(0.9))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, 24)
            .padding(.top, data.format == .story ? data.format.size.height * 0.14 : 24)
            .padding(.bottom, data.format == .story ? data.format.size.height * 0.20 : 24)
            .frame(width: data.format.size.width, height: data.format.size.height, alignment: .topLeading)
        }
        .frame(width: data.format.size.width, height: data.format.size.height)
        .clipped()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Session, \(data.session.activityName), \(Formatters.hours(data.session.hours))")
    }

    @ViewBuilder private var deltaView: some View {
        if let delta, abs(delta) >= 0.005 {
            HStack(spacing: 5) {
                Text(delta > 0 ? "▲" : "▼")
                Text("\(Formatters.percent(abs(delta))) vs your avg")
            }.typography(.caption).foregroundStyle(delta > 0 ? Theme.up : Theme.down).lineLimit(1)
        } else if data.activityHistory.count < 2 {
            Text("FIRST SESSION").typography(.caption).foregroundStyle(secondaryColor).lineLimit(1)
        } else {
            Text("0.0 hrs").typography(.caption).foregroundStyle(secondaryColor).lineLimit(1)
        }
    }

    private var sparkline: some View {
        let history = data.activityHistory.suffix(14).map { Analytics.boundedHours($0.hours) }
        return Group {
            if history.count < 3 {
                VStack(spacing: 4) {
                    Rectangle().fill(secondaryColor.opacity(0.7)).frame(height: 1).overlay {
                        Rectangle().stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 4])).foregroundStyle(secondaryColor)
                    }
                    Text("FIRST SESSIONS").typography(.sectionLabel).foregroundStyle(secondaryColor)
                }
            } else {
                SessionSparkline(values: history, selectedIndex: history.count - 1,
                                 color: data.background == .neon ? Theme.onAccent : Theme.accent)
            }
        }
        .padding(10)
        .background(data.background == .photo || data.background == .neon ? Theme.surface.opacity(0.72) : .clear,
                    in: RoundedRectangle(cornerRadius: 8))
        .frame(height: 48)
    }

    private func statChip(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label).font(Theme.Fonts.mono(size: 8, weight: .medium)).tracking(1.2).lineLimit(1)
                .foregroundStyle(secondaryColor)
            Text(value).font(Theme.Fonts.mono(size: 12, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.55)
                .fixedSize(horizontal: true, vertical: false).foregroundStyle(primaryColor)
        }
        .frame(maxWidth: .infinity, minHeight: 38, alignment: .leading)
        .padding(.horizontal, 6).padding(.vertical, 5)
        .background(data.background == .photo || data.background == .neon ? Theme.surface.opacity(0.72) : Theme.surface.opacity(0.85),
                    in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(data.background == .neon ? Theme.onAccent.opacity(0.25) : Theme.hairline, lineWidth: 1))
    }
}

private struct SessionSparkline: View {
    let values: [Double]
    let selectedIndex: Int
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            let points = makePoints(size: geometry.size)
            ZStack {
                if let first = points.first, let last = points.last {
                    Path { path in
                        path.move(to: CGPoint(x: first.x, y: geometry.size.height))
                        path.addLine(to: first)
                        points.dropFirst().forEach { path.addLine(to: $0) }
                        path.addLine(to: CGPoint(x: last.x, y: geometry.size.height))
                        path.closeSubpath()
                    }.fill(LinearGradient(colors: [color.opacity(0.28), color.opacity(0.01)], startPoint: .top, endPoint: .bottom))
                    Path { path in
                        guard let first = points.first else { return }
                        path.move(to: first); points.dropFirst().forEach { path.addLine(to: $0) }
                    }.stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    if points.indices.contains(selectedIndex) {
                        Circle().fill(color).frame(width: 7, height: 7).overlay(Circle().stroke(Theme.background, lineWidth: 2))
                            .position(points[selectedIndex])
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func makePoints(size: CGSize) -> [CGPoint] {
        let safe = values.map { $0.isFinite ? max(0, $0) : 0 }
        guard safe.count > 1 else { return [] }
        let maximum = max(safe.max() ?? 0, 0.001)
        return safe.enumerated().map { index, value in
            CGPoint(x: size.width * CGFloat(index) / CGFloat(safe.count - 1),
                    y: size.height - CGFloat(value / maximum) * (size.height - 6) - 3)
        }
    }
}
