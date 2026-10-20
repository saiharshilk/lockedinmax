import SwiftUI

#if DEBUG
#Preview {
    EmptyStateView(title: "Nothing on the board.",
                   message: "Log your first session to open your position.",
                   buttonTitle: "LOG A SESSION", action: {})
        .padding(Theme.Spacing.lg)
        .background(Theme.background)
        .preferredColorScheme(.dark)
}
#endif
