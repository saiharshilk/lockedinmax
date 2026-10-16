import SwiftUI

enum LogInput {
    static func positiveNumber(_ text: String) -> Double? {
        let formatter = NumberFormatter()
        formatter.locale = .current
        formatter.numberStyle = .decimal
        formatter.isLenient = false
        let separator = formatter.decimalSeparator ?? "."
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.components(separatedBy: separator)
        guard parts.count <= 2, parts.contains(where: { !$0.isEmpty }),
              parts.allSatisfy({ $0.allSatisfy(\.isNumber) }),
              let number = formatter.number(from: trimmed)?.doubleValue,
              number.isFinite, number > 0 else { return nil }
        return number
    }

    static func sessionHours(_ text: String) -> Double? {
        guard let value = positiveNumber(text), value <= 24 else { return nil }
        return value
    }

    static func exceedsSessionLimit(_ text: String) -> Bool {
        guard let value = positiveNumber(text) else { return false }
        return value > 24
    }
}

extension View {
    func logInputStyle() -> some View {
        self.typography(.body)
            .foregroundStyle(Theme.textPrimary)
            .padding(Theme.Spacing.md)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.medium))
    }
}
