import Foundation

enum Formatters {
    static func hours(_ value: Double) -> String {
        "\(hoursValue(value)) \(hoursUnit(value))"
    }

    static func hoursUnit(_ value: Double) -> String {
        value == 1.0 ? "hr" : "hrs"
    }

    static func hoursValue(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(1...1)))
    }

    static func percent(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : ""
        let number = value.formatted(.number.precision(.fractionLength(1...1)))
        return "\(sign)\(number)%"
    }

    static func delta(hours value: Double, percent change: Double?) -> String {
        guard let change else { return hours(abs(value)) }
        return "\(hours(abs(value))) (\(percent(change)))"
    }

    static func metricValue(_ value: Double) -> String {
        value.formatted(.number.grouping(.never).precision(.fractionLength(0...2)))
    }

    static func metric(_ value: Double, unit: String = "") -> String {
        let number = metricValue(value)
        return unit.isEmpty ? number : "\(number) \(unit)"
    }

    static func metricDelta(_ change: Double) -> String {
        let number = change.formatted(.number.grouping(.never).precision(.fractionLength(0...2)))
        return "\(change >= 0 ? "+" : "")\(number)"
    }
}
