import Foundation

enum Formatters {
    static func hours(_ value: Double) -> String {
        guard value.isFinite else { return "—" }
        if value > 9_999 { return "9,999+ hrs" }
        let rounded = roundedHours(value)
        return "\(hoursValue(rounded)) \(hoursUnit(rounded))"
    }

    static func hoursUnit(_ value: Double) -> String {
        value.isFinite && roundedHours(value) == 1.0 ? "hr" : "hrs"
    }

    static func hoursValue(_ value: Double) -> String {
        guard value.isFinite else { return "—" }
        guard value <= 9_999 else { return "9,999+" }
        let rounded = roundedHours(value)
        let formatter = NumberFormatter()
        formatter.locale = .current
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = rounded * 10 == (rounded * 10).rounded() ? 1 : 2
        formatter.roundingMode = .halfUp
        return formatter.string(from: NSNumber(value: rounded)) ?? String(rounded)
    }

    private static func roundedHours(_ value: Double) -> Double {
        guard value.isFinite else { return value }
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.maximumFractionDigits = 2
        formatter.roundingMode = .halfUp
        let formatted = formatter.string(from: NSNumber(value: value)) ?? String(value)
        return formatter.number(from: formatted)?.doubleValue ?? value
    }

    static func percent(_ value: Double) -> String {
        guard value.isFinite else { return "—" }
        let number = value.formatted(.number.grouping(.automatic).precision(.fractionLength(1...1)))
        return "\(value >= 0 ? "+" : "")\(number)%"
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
