import SwiftUI
#if os(iOS)
import UIKit
#endif

extension View {
    func tabBarClearance() -> some View {
        safeAreaPadding(.bottom, 96)
    }
}

struct KeyboardDoneToolbar: ToolbarContent {
    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .keyboard) {
            Spacer()
            Button("Done") {
#if os(iOS)
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                                to: nil, from: nil, for: nil)
#endif
            }
            .foregroundStyle(Theme.accent)
        }
    }
}
