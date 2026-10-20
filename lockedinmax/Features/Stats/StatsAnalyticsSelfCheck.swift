#if DEBUG
import Foundation

@MainActor
enum StatsAnalyticsSelfCheck {
    static func run() -> String {
        var failures: [String] = []
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        calendar.locale = Locale(identifier: "en_US")
        calendar.firstWeekday = 1
        verify(calendar: calendar, verifyFullFixtures: true, failures: &failures)
        calendar.firstWeekday = 2
        verify(calendar: calendar, verifyFullFixtures: false, failures: &failures)

        if failures.isEmpty {
            return "PASS: Sunday-first WEEK 11–17 Oct 4.5h vs matched 2.0h (+2.5h, +125.0%); completed WEEK 4–10 Oct 4.5h vs 0h; DAY 14 Oct 3.0h vs 1.5h (+1.5h, +100.0%); MONTH Oct 9.0h vs 0h; active-day averages, breakdown shares, 7/24/31 bucket totals, and Sunday/Monday heatmap alignment pass."
        }
        return "FAIL:\n" + failures.joined(separator: "\n")
    }

    private static func verify(calendar: Calendar, verifyFullFixtures: Bool, failures: inout [String]) {
        func date(_ day: Int) -> Date {
            calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: 12))!
        }
        let reference = date(14)
        let math = Activity(name: "Math", colorHex: Theme.activityColorPresets[0], iconName: "function")
        let chess = Activity(name: "Chess", colorHex: Theme.activityColorPresets[2], iconName: "crown")
        let walks = Activity(name: "Walks", colorHex: Theme.activityColorPresets[3], iconName: "figure.walk")
        let sessions = [
            Session(date: date(14), hours: 1, activity: math),
            Session(date: date(14), hours: 2, activity: chess),
            Session(date: date(13), hours: 1.5, activity: math),
            Session(date: date(10), hours: 2.5, activity: walks),
            Session(date: date(7), hours: 2, activity: math)
        ]
        let week = StatsAnalytics.summarize(sessions: sessions, kind: .week, anchor: reference, now: reference, calendar: calendar)
        let day = StatsAnalytics.summarize(sessions: sessions, kind: .day, anchor: reference, now: reference, calendar: calendar)
        let month = StatsAnalytics.summarize(sessions: sessions, kind: .month, anchor: reference, now: reference, calendar: calendar)
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: reference)!.start
        let previousStart = calendar.date(byAdding: .weekOfYear, value: -1, to: weekStart)!
        let elapsedDays = (calendar.dateComponents([.day], from: weekStart, to: calendar.startOfDay(for: reference)).day ?? 0) + 1
        let previousEnd = calendar.date(byAdding: .day, value: elapsedDays, to: previousStart)!
        let matchedPrevious = sessions.filter { $0.date >= previousStart && $0.date < previousEnd }
            .reduce(0) { $0 + Analytics.boundedHours($1.hours) }
        let prefix = calendar.firstWeekday == 1 ? "Sunday" : "Monday"

        check(week.period.start == weekStart && week.totalHours == 4.5, "\(prefix)-first week should contain the 4.5h fixture", &failures)
        check(week.elapsedDays == elapsedDays && week.activeDays == 2 && week.averagePerActiveDay == 2.25,
              "\(prefix)-first week elapsed/active/average mismatch", &failures)
        check(week.bestDay?.hours == 3 && week.bestDay.map { calendar.isDate($0.date, inSameDayAs: reference) } == true,
              "\(prefix)-first best day should be 3.0h on Oct 14", &failures)
        check(week.topPosition?.name == "Math" && week.topPosition?.hours == 2.5,
              "\(prefix)-first top position should be Math 2.5h", &failures)
        check(week.previousHours == matchedPrevious && week.comparisonCaption == "vs same days last week",
              "\(prefix)-first week comparison window/caption mismatch", &failures)
        check(abs(week.bucketValues.reduce(0) { $0 + $1.hours } - 4.5) < 0.0001,
              "\(prefix)-first seven weekly buckets do not sum to 4.5h", &failures)

        if verifyFullFixtures {
            check(weekStart == date(11) && matchedPrevious == 2 && week.deltaHours == 2.5 && week.deltaPercent == 125,
                  "Sunday-first current week should be 4.5h vs 2h (+2.5h, +125%)", &failures)
            check(week.period.bucketDates.count == 7, "Current WEEK should have seven buckets", &failures)
            check(week.activeDays == 2 && week.elapsedDays == 4 && week.averagePerActiveDay == 2.25,
                  "Sunday-first WEEK active-day denominator/average mismatch", &failures)
            let weekShares = Dictionary(uniqueKeysWithValues: week.breakdown.map { ($0.name, $0.share) })
            check(abs((weekShares["Math"] ?? 0) - 2.5 / 4.5) < 0.0001
                  && abs((weekShares["Chess"] ?? 0) - 2.0 / 4.5) < 0.0001,
                  "WEEK breakdown should be Math 55.6%, Chess 44.4%", &failures)

            let completeStart = calendar.dateInterval(of: .weekOfYear, for: date(4))!.start
            let completeEnd = calendar.date(byAdding: .day, value: 7, to: completeStart)!
            let completeReference = calendar.date(byAdding: .second, value: -1, to: completeEnd)!
            let completedWeek = StatsAnalytics.summarize(sessions: sessions, kind: .week, anchor: date(4), now: completeReference, calendar: calendar)
            check(completedWeek.totalHours == 4.5 && completedWeek.previousHours == 0 && completedWeek.deltaPercent == nil,
                  "Completed WEEK 4–10 Oct should be 4.5h vs 0 without percent", &failures)

            check(day.totalHours == 3 && day.previousHours == 1.5 && day.deltaHours == 1.5 && day.deltaPercent == 100,
                  "DAY 14 Oct should be 3.0h vs 1.5h (+1.5h, +100%)", &failures)
            check(day.period.bucketDates.count == 24 && abs(day.bucketValues.reduce(0) { $0 + $1.hours } - 3) < 0.0001,
                  "DAY 24 hourly buckets should sum to 3.0h", &failures)

            check(month.totalHours == 9 && month.previousHours == 0 && month.deltaPercent == nil,
                  "MONTH October should be 9.0h vs 0 without percent", &failures)
            check(month.elapsedDays == 14 && month.activeDays == 4 && month.averagePerActiveDay == 2.25,
                  "MONTH active days should be 4/14 and average 2.25h", &failures)
            let emptyMonthStart = calendar.dateInterval(of: .month, for: date(1))!.start
            let emptyMonthEnd = calendar.dateInterval(of: .month, for: date(1))!.end
            let emptyPastMonth = StatsAnalytics.summarize(sessions: sessions, kind: .month, anchor: date(1),
                now: emptyMonthEnd.addingTimeInterval(-1), calendar: calendar)
            check(emptyPastMonth.period.start == emptyMonthStart && emptyPastMonth.elapsedDays == 31,
                  "Completed past MONTH should use the full 31-day denominator", &failures)
            check(month.period.bucketDates.count == 31 && abs(month.bucketValues.reduce(0) { $0 + $1.hours } - 9) < 0.0001,
                  "MONTH 31 daily buckets should sum to 9.0h", &failures)
            let emptyCompleteMonth = StatsAnalytics.summarize(sessions: sessions, kind: .month, anchor: date(1),
                                                               now: calendar.dateInterval(of: .month, for: date(1))!.end.addingTimeInterval(-1),
                                                               calendar: calendar)
            check(emptyCompleteMonth.elapsedDays == 31,
                  "Completed past MONTH active-day denominator should use all 31 days", &failures)
            let shares = Dictionary(uniqueKeysWithValues: month.breakdown.map { ($0.name, $0.share) })
            check(abs((shares["Math"] ?? 0) - 0.5) < 0.0001
                  && abs((shares["Walks"] ?? 0) - 2.5 / 9) < 0.0001
                  && abs((shares["Chess"] ?? 0) - 2.0 / 9) < 0.0001
                  && abs(month.breakdown.reduce(0) { $0 + $1.share } - 1) < 0.0001,
                  "MONTH breakdown shares should be Math 50%, Walks 27.8%, Chess 22.2%", &failures)
        }

        verifyHeatmap(sessions: sessions, reference: reference, calendar: calendar, prefix: prefix, failures: &failures)
    }

    private static func verifyHeatmap(sessions: [Session], reference: Date, calendar: Calendar,
                                      prefix: String, failures: inout [String]) {
        func date(_ day: Int) -> Date {
            calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: 12))!
        }
        let heatmap = StatsAnalytics.heatmap(sessions: sessions, today: reference, calendar: calendar)
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: reference)!.start
        let firstDate = calendar.date(byAdding: .weekOfYear, value: -11, to: weekStart)!
        let currentWeekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart)!
        let target = heatmap.first { calendar.isDate($0.date, inSameDayAs: reference) }
        let saturday = heatmap.first { calendar.isDate($0.date, inSameDayAs: date(10)) }
        let targetPosition = HeatmapCalendarLayout.gridPosition(for: reference, firstDate: firstDate, calendar: calendar)
        let saturdayPosition = HeatmapCalendarLayout.gridPosition(for: date(10), firstDate: firstDate, calendar: calendar)
        let currentWeekday = calendar.component(.weekday, from: reference)
        let saturdayWeekday = calendar.component(.weekday, from: date(10))
        let expectedCount = (calendar.dateComponents([.day], from: firstDate, to: currentWeekEnd).day ?? 0) + 1
        check(heatmap.count == expectedCount && heatmap.last.map { calendar.isDate($0.date, inSameDayAs: currentWeekEnd) } == true,
              "\(prefix)-first heatmap must show 12 full weeks through this week's Saturday", &failures)
        check(target?.hours == 3 && targetPosition?.column == 11
              && targetPosition?.row == (currentWeekday - calendar.firstWeekday + 7) % 7,
              "\(prefix)-first Oct 14 heatmap cell position/value mismatch", &failures)
        check(saturday?.hours == 2.5 && saturdayPosition?.column == 10
              && saturdayPosition?.row == (saturdayWeekday - calendar.firstWeekday + 7) % 7,
              "\(prefix)-first Oct 10 heatmap cell position/value mismatch", &failures)
        let labels = HeatmapCalendarLayout.weekdayLabels(calendar: calendar)
        for weekday in 1...7 {
            let row = (weekday - calendar.firstWeekday + 7) % 7
            check((!labels[row].isEmpty) == (weekday == 2 || weekday == 4 || weekday == 6),
                  "\(prefix)-first M/W/F heatmap label row mismatch for weekday \(weekday)", &failures)
        }
    }

    private static func check(_ condition: Bool, _ message: String, _ failures: inout [String]) {
        if !condition { failures.append(message) }
    }
}
#endif
