import SwiftData
import SwiftUI

struct MetricEntryEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let entry: MetricEntry
    @State private var value: String
    @State private var date: Date
    @State private var screenshotData: Data?
    @State private var isLoading = false
    @State private var errorMessage: String?

    init(entry: MetricEntry) {
        self.entry = entry
        _value = State(initialValue: Formatters.metricValue(entry.value))
        _date = State(initialValue: entry.date)
        _screenshotData = State(initialValue: entry.screenshotData)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    Text(entry.metric?.unit.isEmpty == false ? "VALUE · \(entry.metric?.unit ?? "")" : "VALUE")
                        .typography(.sectionLabel).foregroundStyle(Theme.textTertiary)
                    TextField("0", text: $value).keyboardType(.decimalPad).logInputStyle()
                    DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute]).logInputStyle()
                    PhotoInput(title: "Add screenshot (optional)", large: false,
                               data: $screenshotData, isLoading: $isLoading)
                    PrimaryButton(title: "SAVE CHANGES", action: save)
                        .disabled(LogInput.positiveNumber(value) == nil || isLoading)
                }.padding(Theme.Spacing.lg)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Edit Score").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .alert("Could not save entry", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: { Text(errorMessage ?? "") }
        }.tint(Theme.accent).preferredColorScheme(.dark)
    }

    private func save() {
        guard let number = LogInput.positiveNumber(value) else { return }
        entry.value = number
        entry.date = date
        entry.screenshotData = screenshotData
        do { try context.save(); dismiss() } catch { context.rollback(); errorMessage = error.localizedDescription }
    }
}

#Preview {
    MetricEntryEditSheet(entry: MetricEntry(value: 84))
        .modelContainer(for: [Activity.self, Session.self, Metric.self, MetricEntry.self], inMemory: true)
}
