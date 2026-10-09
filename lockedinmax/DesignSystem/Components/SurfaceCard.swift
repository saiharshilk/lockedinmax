import SwiftUI

struct SurfaceCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.medium))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.medium)
                    .strokeBorder(Theme.hairline, lineWidth: Theme.borderWidth)
            }
    }
}

extension View {
    func surfaceCard() -> some View {
        modifier(SurfaceCard())
    }
}

#Preview {
    Text("A quiet place for a position.")
        .typography(.body)
        .foregroundStyle(Theme.textPrimary)
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .surfaceCard()
        .padding(Theme.Spacing.lg)
        .background(Theme.background)
        .preferredColorScheme(.dark)
}
