#if DEBUG
import SwiftData
import SwiftUI

struct DebugDataTools: View {
    @Environment(\.modelContext) private var context
    @Query private var activities: [Activity]
    @State private var confirmingClear = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Button("Load sample data") { perform { try SampleData.load(into: context) } }
                .disabled(activities.contains { $0.id == SampleData.markerID })
            Button("Clear all data", role: .destructive) { confirmingClear = true }
                .foregroundStyle(Theme.down)
        }
        .typography(.caption).tint(Theme.accent)
        .confirmationDialog("Clear all positions, sessions, metrics, and entries?",
                            isPresented: $confirmingClear, titleVisibility: .visible) {
            Button("Clear all data", role: .destructive) { perform { try SampleData.clear(context) } }
            Button("Cancel", role: .cancel) {}
        } message: { Text("This cannot be undone.") }
        .alert("Data operation failed", isPresented: Binding(
            get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
        )) { Button("OK", role: .cancel) {} } message: { Text(errorMessage ?? "") }
    }

    private func perform(_ action: () throws -> Void) {
        do { try action() } catch {
            context.rollback()
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    DebugDataTools().padding(Theme.Spacing.lg).background(Theme.background)
        .modelContainer(for: [Activity.self, Session.self, Metric.self, MetricEntry.self], inMemory: true)
}
#endif
