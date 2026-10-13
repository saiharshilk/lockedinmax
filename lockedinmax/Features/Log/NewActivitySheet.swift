import SwiftData
import SwiftUI

struct NewActivitySheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var colorHex = Theme.activityColorPresets[0]
    @State private var iconName = "book"
    @State private var errorMessage: String?
    let onCreated: (Activity) -> Void
    private let icons = ["book", "function", "laptopcomputer", "figure.walk", "crown", "bed.double",
                         "dumbbell", "music.note", "paintbrush", "brain", "pencil", "flame"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    TextField("Position name", text: $name).logInputStyle()
                    SectionHeader(title: "Color")
                    HStack(spacing: Theme.Spacing.sm) {
                        ForEach(Theme.activityColorPresets, id: \.self) { hex in
                            Button { colorHex = hex } label: {
                                Circle().fill(Theme.activityColor(hex))
                                    .frame(maxWidth: .infinity).frame(height: 32)
                                    .overlay {
                                        if hex == colorHex {
                                            Image(systemName: "checkmark")
                                                .foregroundStyle(Theme.onAccent).typography(.rowTitle)
                                        }
                                    }
                                    .frame(minHeight: Theme.minimumTapHeight)
                            }
                            .accessibilityLabel("Color \(hex)")
                            .accessibilityAddTraits(hex == colorHex ? .isSelected : [])
                        }
                    }
                    SectionHeader(title: "Icon")
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4),
                              spacing: Theme.Spacing.md) {
                        ForEach(icons, id: \.self) { icon in
                            Button { iconName = icon } label: {
                                Image(systemName: icon).typography(.title)
                                    .foregroundStyle(icon == iconName ? Theme.onAccent : Theme.textPrimary)
                                    .frame(maxWidth: .infinity, minHeight: 56)
                                    .background(icon == iconName ? Theme.accent : Theme.surface,
                                                in: RoundedRectangle(cornerRadius: Theme.Radius.small))
                            }
                            .accessibilityLabel(icon)
                            .accessibilityAddTraits(icon == iconName ? .isSelected : [])
                        }
                    }
                    PrimaryButton(title: "CREATE POSITION", action: save)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(Theme.Spacing.lg)
            }
            .buttonStyle(.plain)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("New Position").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .alert("Could not save", isPresented: Binding(
                get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
            )) { Button("OK", role: .cancel) {} } message: { Text(errorMessage ?? "") }
        }
        .tint(Theme.accent).preferredColorScheme(.dark)
    }

    private func save() {
        let activity = Activity(name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                                colorHex: colorHex, iconName: iconName)
        context.insert(activity)
        do {
            try context.save()
            onCreated(activity)
            dismiss()
        } catch {
            context.rollback()
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    NewActivitySheet { _ in }
        .modelContainer(for: [Activity.self, Session.self, Metric.self, MetricEntry.self], inMemory: true)
}
