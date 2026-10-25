#if DEBUG
import CoreFoundation
import Foundation
import SwiftUI
import UIKit

@MainActor
enum RecapCardChecks {
    static func run() -> String {
        var failures: [String] = []
        let calendar = fixtureCalendar()
        let fixture = makeFixture(calendar: calendar)
        let week = RecapCardFactory.weekly(fixture.anchor, sessions: fixture.weekSessions, scores: fixture.scores,
                                            now: fixture.anchor, format: .portrait, calendar: calendar)
        let emptyWeek = RecapCardFactory.weekly(fixture.anchor, sessions: [], scores: [], now: fixture.anchor,
                                                format: .portrait, calendar: calendar)
        if emptyWeek.totalHours != 0 || !emptyWeek.totalHours.isFinite || !emptyWeek.averagePerActiveDay.isFinite {
            failures.append("empty weekly fixture did not produce finite zero values")
        }
        if emptyWeek.comparisonCaption != "vs same days last week" {
            failures.append("empty current-week comparison caption mismatch")
        }
        if abs(week.totalHours - 4.5) > 0.0001 { failures.append("weekly fixture total expected 4.5, got \(week.totalHours)") }
        if abs(week.deltaHours - 2.5) > 0.0001 { failures.append("weekly fixture delta expected 2.5, got \(week.deltaHours)") }
        if week.deltaPercent != 125 { failures.append("weekly fixture percent expected 125.0, got \(week.deltaPercent.map(Formatters.percent) ?? "nil")") }
        if week.comparisonCaption != "vs same days last week" { failures.append("weekly caption mismatch: \(week.comparisonCaption)") }

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("RecapCardFixtures", isDirectory: true)
        do { try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true) }
        catch { failures.append("could not create fixture directory: \(error.localizedDescription)") }
        var rendered = 0
        for mode in RecapMode.allCases {
            let backgrounds: [RecapCardBackground] = mode == .day ? [.dark, .neon] : [.dark, .neon, .photo]
            for format in RecapCardFormat.allCases {
                for background in backgrounds {
                    let suffix = "\(mode.rawValue.replacingOccurrences(of: " ", with: "-"))_\(format.rawValue.replacingOccurrences(of: ":", with: "x"))_\(background.rawValue)"
                    let card: AnyView
                    switch mode {
                    case .session:
                        guard let selected = fixture.values.last else { failures.append("session fixture unexpectedly empty"); continue }
                        let session = RecapSessionValue(id: selected.id, date: selected.date, hours: selected.hours,
                            activityID: selected.activityID, activityName: selected.activityName,
                            activityColorHex: selected.activityColorHex, iconName: selected.iconName,
                            note: selected.note, photo: fixture.photo, photoData: selected.photoData)
                        let data = SessionRecapCardData(session: session, activityHistory: fixture.values,
                            allSessions: fixture.values, daySessions: fixture.values.filter { calendar.isDate($0.date, inSameDayAs: session.date) },
                            previousDaySessions: [], scores: fixture.scoreValues, todayHours: 12, weekHours: 27.75,
                            streakDays: 5, caption: session.note, format: format, background: background)
                        card = AnyView(SessionCard(data: data))
                    case .day:
                        let data = MarketCloseCardData(date: fixture.anchor, sessions: fixture.values,
                            previousDaySessions: [], sevenDayHours: [0, 2, 4.5, 7, 3, 0, 12], scores: fixture.marketScores,
                            format: format, background: background)
                        card = AnyView(MarketCloseCard(data: data))
                    case .week:
                        let weeklySessions = background == .photo ? [] : fixture.sessions
                        let data = RecapCardFactory.weekly(fixture.anchor, sessions: weeklySessions, scores: fixture.scores,
                                                           now: fixture.anchor, format: format, background: background, calendar: calendar)
                        card = AnyView(WeeklyCard(data: data))
                    }
                    guard let image = render(card, format: format) else {
                        failures.append("\(suffix): ImageRenderer returned nil")
                        continue
                    }
                    rendered += 1
                    let expectedWidth = Int(format.size.width * 3)
                    let expectedHeight = Int(format.size.height * 3)
                    let pixelWidth = image.cgImage?.width ?? 0
                    let pixelHeight = image.cgImage?.height ?? 0
                    if pixelWidth != expectedWidth || pixelHeight != expectedHeight {
                        failures.append("\(suffix): pixel size \(pixelWidth)x\(pixelHeight), expected \(expectedWidth)x\(expectedHeight)")
                    }
                    if distinctPixelCount(image, samples: 200) < 3 { failures.append("\(suffix): fewer than 3 sampled colors") }
                    let url = directory.appendingPathComponent("\(suffix).png")
                    if let bytes = image.pngData() {
                        do { try bytes.write(to: url, options: .atomic); print("[RecapCardCheck] PNG \(url.path) \(pixelWidth)x\(pixelHeight) \(bytes.count) bytes") }
                        catch { failures.append("\(suffix): could not write PNG: \(error.localizedDescription)") }
                    } else { failures.append("\(suffix): PNG encoding returned nil") }
                }
            }
        }
        let result = failures.isEmpty
            ? "PASS: \(rendered) recap fixture renders, 1080px width/format dimensions and sampled color diversity; weekly math 4.5h, +2.5h, +125.0%, vs same days last week. PNGs: \(directory.path)"
            : "FAIL:\n" + failures.joined(separator: "\n")
        NSLog("[RecapCardCheck] %@", result)
        return result
    }

    static func render(_ card: AnyView, format: RecapCardFormat) -> UIImage? {
        let renderer = ImageRenderer(content: card
            .environment(\.dynamicTypeSize, .large)
            .environment(\.colorScheme, .dark)
            .environment(\.locale, Locale(identifier: "en_US_POSIX")))
        renderer.scale = 3
        renderer.proposedSize = ProposedViewSize(format.size)
        return renderer.uiImage
    }

    private static func makeFixture(calendar: Calendar) -> (anchor: Date, weekSessions: [Session], sessions: [Session], values: [RecapSessionValue], scores: [MetricEntry], scoreValues: [RecapScoreValue], marketScores: [MarketScoreValue], photo: UIImage) {
        func date(_ day: Int, month: Int = 10) -> Date {
            calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: 12)) ?? .now
        }
        let anchor = date(14)
        let activities = (0..<7).map { index in
            Activity(name: ["Mathematics", "Real Analysis Ultra Long Position Name", "Chess", "Walking", "Coding Projects", "Reading", "Piano"][index],
                     colorHex: Theme.activityColorPresets[index], iconName: ["function", "sum", "crown", "figure.walk", "terminal", "book", "pianokeys"][index])
        }
        let weekSessions: [Session] = [
            Session(date: date(14), hours: 1, note: "A focused session with long fixture caption", activity: activities[0]),
            Session(date: date(14), hours: 2, activity: activities[2]),
            Session(date: date(13), hours: 1.5, activity: activities[0]),
            Session(date: date(7), hours: 2, activity: activities[1])
        ]
        var sessions = weekSessions + (0..<7).map { index in
            Session(date: date(14), hours: 12, note: "12-hour stress fixture", activity: activities[index])
        }
        sessions.append(Session(date: date(12), hours: 0, activity: activities[6]))
        let values = sessions.map { RecapSessionValue(model: $0) }
        let metrics = (0..<2).map { index -> Metric in
            Metric(name: index == 0 ? "ZetaMac" : "Sleep Score", unit: "", createdAt: date(1))
        }
        let entries = [MetricEntry(date: date(11), value: 58, metric: metrics[0]),
                       MetricEntry(date: date(14), value: 70, metric: metrics[0]),
                       MetricEntry(date: date(14), value: 92, metric: metrics[1])]
        let scoreValues = entries.map(RecapScoreValue.init(model:))
        let marketScores = [MarketScoreValue(id: UUID(), name: "SLEEP SCORE", value: 92, change: 4)]
        let photo = UIGraphicsImageRenderer(size: CGSize(width: 320, height: 400)).image { context in
            context.cgContext.setFillColor(UIColor(Theme.accent).cgColor)
            context.cgContext.fill(CGRect(x: 0, y: 0, width: 320, height: 200))
            context.cgContext.setFillColor(UIColor(Theme.surface).cgColor)
            context.cgContext.fill(CGRect(x: 0, y: 200, width: 320, height: 200))
        }
        return (anchor, weekSessions, sessions, values, entries, scoreValues, marketScores, photo)
    }

    private static func fixtureCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = .current
        calendar.firstWeekday = 1
        return calendar
    }

    private static func distinctPixelCount(_ image: UIImage, samples: Int) -> Int {
        guard let cgImage = image.cgImage, let data = cgImage.dataProvider?.data,
              let bytes = CFDataGetBytePtr(data) else { return 0 }
        let bpp = cgImage.bitsPerPixel / 8
        let row = cgImage.bytesPerRow
        guard bpp >= 3 else { return 0 }
        var colors = Set<UInt32>()
        for index in 0..<samples {
            let x = (index * 197 + 31) % cgImage.width
            let y = (index * 317 + 17) % cgImage.height
            let offset = y * row + x * bpp
            colors.insert((UInt32(bytes[offset]) << 16) | (UInt32(bytes[offset + 1]) << 8) | UInt32(bytes[offset + 2]))
        }
        return colors.count
    }
}
#endif
