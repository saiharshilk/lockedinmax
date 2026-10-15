import SwiftData
import SwiftUI

struct MetricEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let metric: Metric
    @State private var name: String
    @State private var unit: String
    @State private var errorMessage: String?

    init(metric: Metric) {
        self.metric = metric
        _name = State(initialValue: metric.name)
        _unit = State(initialValue: metric.unit)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                TextField("Metric name", text: $name).logInputStyle()
                TextField("Unit (optional)", text: $unit).logInputStyle()
                PrimaryButton(title: "SAVE CHANGES", action: save)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Spacer()
            }.padding(Theme.Spacing.lg).background(Theme.background.ignoresSafeArea())
                .navigationTitle("Edit Metric").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
                .alert("Could not save metric", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                    Button("OK", role: .cancel) {}
                } message: { Text(errorMessage ?? "") }
        }.tint(Theme.accent).preferredColorScheme(.dark)
    }

    private func save() {
        metric.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        metric.unit = unit.trimmingCharacters(in: .whitespacesAndNewlines)
        do { try context.save(); dismiss() } catch { context.rollback(); errorMessage = error.localizedDescription }
    }
}

#Preview {
    MetricEditSheet(metric: Metric(name: "Sleep Score", unit: "pts"))
        .modelContainer(for: [Activity.self, Session.self, Metric.self, MetricEntry.self], inMemory: true)
}
