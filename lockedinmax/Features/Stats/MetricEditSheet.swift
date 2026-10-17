import SwiftData
import SwiftUI

struct MetricEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let metricID: UUID
    @Query private var metrics: [Metric]
    private var metric: Metric? { metrics.first { $0.id == metricID } }
    @State private var name: String
    @State private var unit: String
    @State private var errorMessage: String?

    init(metricID: UUID, name: String, unit: String) {
        self.metricID = metricID
        _name = State(initialValue: name)
        _unit = State(initialValue: unit)
    }

    init(metric: Metric) {
        self.init(metricID: metric.id, name: metric.name, unit: metric.unit)
    }

    var body: some View {
        Group {
            if metric != nil {
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
                }
            } else {
                Color.clear.task { dismiss() }
            }
        }
        .onChange(of: metrics.map(\.id)) { _, ids in
            if !ids.contains(metricID) { dismiss() }
        }
        .tint(Theme.accent).preferredColorScheme(.dark)
    }

    private func save() {
        guard let metric else { dismiss(); return }
        metric.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        metric.unit = unit.trimmingCharacters(in: .whitespacesAndNewlines)
        do { try context.save(); dismiss() } catch { context.rollback(); errorMessage = error.localizedDescription }
    }
}

#Preview {
    MetricEditSheet(metricID: UUID(), name: "Sleep Score", unit: "pts")
        .modelContainer(for: [Activity.self, Session.self, Metric.self, MetricEntry.self], inMemory: true)
}
