import SwiftData
import SwiftUI

struct NewMetricSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var metrics: [Metric]
    @State private var name = ""
    @State private var unit = ""
    @State private var errorMessage: String?
    let onCreated: (UUID) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: Theme.Spacing.xl) {
                TextField("Metric name", text: $name).logInputStyle()
                TextField("Unit (optional)", text: $unit).logInputStyle()
                PrimaryButton(title: "CREATE METRIC", action: save)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Spacer()
            }
            .padding(Theme.Spacing.lg)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("New Metric").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .alert("Could not save", isPresented: Binding(
                get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
            )) { Button("OK", role: .cancel) {} } message: { Text(errorMessage ?? "") }
        }
        .tint(Theme.accent).preferredColorScheme(.dark)
    }

    private func save() {
        let metric = Metric(name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                            unit: unit.trimmingCharacters(in: .whitespacesAndNewlines))
        context.insert(metric)
        do {
            try context.save()
            onCreated(metric.id)
            dismiss()
        } catch {
            context.rollback()
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    NewMetricSheet { _ in }
        .modelContainer(for: [Activity.self, Session.self, Metric.self, MetricEntry.self], inMemory: true)
}
