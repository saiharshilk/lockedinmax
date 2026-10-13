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
}

extension View {
    func logInputStyle() -> some View {
        self.typography(.body)
            .foregroundStyle(Theme.textPrimary)
            .padding(Theme.Spacing.md)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.medium))
    }
}
