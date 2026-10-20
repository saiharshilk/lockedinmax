import SwiftUI

struct SelectionChips<Item: Identifiable>: View where Item.ID == UUID {
    let items: [Item]
    @Binding var selection: Item?
    let title: (Item) -> String
    let icon: (Item) -> String
    let color: (Item) -> Color
    let newTitle: String
    let create: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(items) { item in
                    Button { selection = item } label: {
                        Label(title(item), systemImage: icon(item))
                            .lineLimit(1).truncationMode(.tail)
                            .foregroundStyle(selection?.id == item.id ? Theme.onAccent : color(item))
                            .padding(.horizontal, Theme.Spacing.md)
                            .frame(minHeight: Theme.minimumTapHeight)
                            .contentShape(Capsule())
                            .background(selection?.id == item.id ? Theme.accent : Theme.surface,
                                        in: Capsule())
                    }
                    .accessibilityLabel(title(item))
                    .accessibilityAddTraits(selection?.id == item.id ? .isSelected : [])
                }
                Button(action: create) {
                    Text(newTitle)
                        .foregroundStyle(Theme.textPrimary)
                        .padding(.horizontal, Theme.Spacing.md)
                        .frame(minHeight: Theme.minimumTapHeight)
                        .contentShape(Capsule())
                        .background(Theme.surface, in: Capsule())
                        .overlay(Capsule().stroke(Theme.hairline, lineWidth: Theme.borderWidth))
                }
                .frame(minHeight: Theme.minimumTapHeight)
                .accessibilityLabel(newTitle)
            }
            .typography(.rowTitle)
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    SelectionChips(items: [Activity(name: "Math", colorHex: Theme.activityColorPresets[0], iconName: "function")],
                   selection: .constant(nil), title: { $0.name }, icon: { $0.iconName },
                   color: { Theme.activityColor($0.colorHex) }, newTitle: "+ New", create: {})
        .padding(Theme.Spacing.lg).background(Theme.background)
}
