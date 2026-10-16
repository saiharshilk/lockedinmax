import Foundation

enum Formatters {
    static func hours(_ value: Double) -> String {
        guard value.isFinite else { return "—" }
        if value > 9_999 { return "9,999+ hrs" }
        return "\(hoursValue(value)) \(hoursUnit(value))"
    }

    static func hoursUnit(_ value: Double) -> String {
        value == 1.0 ? "hr" : "hrs"
    }

    static func hoursValue(_ value: Double) -> String {
        guard value.isFinite else { return "—" }
        guard value <= 9_999 else { return "9,999+" }
        return value.formatted(.number.precision(.fractionLength(1...1)))
    }

    static func percent(_ value: Double) -> String {
        guard value.isFinite else { return "—" }
        let sign = value >= 0 ? "+" : ""
        let number = value.formatted(.number.precision(.fractionLength(1...1)))
        return "\(sign)\(number)%"
    }

    static func delta(hours value: Double, percent change: Double?) -> String {
        guard value.isFinite else { return "—" }
        guard let change, change.isFinite else { return hours(abs(value)) }
        return "\(hours(abs(value))) (\(percent(change)))"
    }

    static func metricValue(_ value: Double) -> String {
        guard value.isFinite else { return "—" }
        return value.formatted(.number.grouping(.never).precision(.fractionLength(0...2)))
    }

    static func metric(_ value: Double, unit: String = "") -> String {
        let number = metricValue(value)
        return unit.isEmpty ? number : "\(number) \(unit)"
    }

    static func metricDelta(_ change: Double) -> String {
        guard change.isFinite else { return "—" }
        let number = change.formatted(.number.grouping(.never).precision(.fractionLength(0...2)))
        return "\(change >= 0 ? "+" : "")\(number)"
    }
}
