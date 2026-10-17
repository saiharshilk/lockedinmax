import SwiftData
import SwiftUI

struct MetricEntryEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let entryID: UUID
    @Query private var entries: [MetricEntry]
    private var entry: MetricEntry? { entries.first { $0.id == entryID } }
    @State private var value: String
    @State private var date: Date
    @State private var screenshotData: Data?
    @State private var isLoading = false
    @State private var errorMessage: String?

    init(entryID: UUID, value: Double, date: Date, screenshotData: Data?) {
        self.entryID = entryID
        _value = State(initialValue: Formatters.metricValue(value))
        _date = State(initialValue: date)
        _screenshotData = State(initialValue: screenshotData)
    }

    init(entry: MetricEntry) {
        self.init(entryID: entry.id, value: entry.value, date: entry.date, screenshotData: entry.screenshotData)
    }

    var body: some View {
        Group {
            if entry != nil {
                NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    Text(valueTitle)
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
                }
            } else {
                Color.clear.task { dismiss() }
            }
        }
        .onChange(of: entries.map(\.id)) { _, ids in
            if !ids.contains(entryID) { dismiss() }
        }
        .tint(Theme.accent).preferredColorScheme(.dark)
    }

    private var valueTitle: String {
        guard let unit = entry?.metric?.unit, !unit.isEmpty else { return "VALUE" }
        return "VALUE · \(unit)"
    }

    private func save() {
        guard let entry, let number = LogInput.positiveNumber(value) else { dismiss(); return }
        entry.value = number
        entry.date = date
        entry.screenshotData = screenshotData
        do { try context.save(); dismiss() } catch { context.rollback(); errorMessage = error.localizedDescription }
    }
}

#Preview {
    MetricEntryEditSheet(entryID: UUID(), value: 84, date: .now, screenshotData: nil)
        .modelContainer(for: [Activity.self, Session.self, Metric.self, MetricEntry.self], inMemory: true)
}
