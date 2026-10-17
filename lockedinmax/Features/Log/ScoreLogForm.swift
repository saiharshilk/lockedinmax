import SwiftData
import SwiftUI

struct ScoreLogForm: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Metric.createdAt) private var metrics: [Metric]
    @State private var metricID: UUID?
    private var selectedMetric: Metric? { metrics.first { $0.id == metricID } }
    @State private var value = ""
    @State private var date = Date.now
    @State private var screenshotData: Data?
    @State private var isLoadingPhoto = false
    @State private var showingNew = false
    @State private var errorMessage: String?
    @State private var saveCount = 0

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            SectionHeader(title: "Metric")
            SelectionChips(items: metrics, selection: metricSelection, title: { $0.name },
                           icon: { _ in "chart.xyaxis.line" }, color: { _ in Theme.textPrimary },
                           newTitle: "+ New metric") { showingNew = true }
            PhotoInput(title: "Add screenshot (optional)", large: true, data: $screenshotData,
                       isLoading: $isLoadingPhoto)
            Text(selectedMetric?.unit.isEmpty == false ? "Value · \(selectedMetric?.unit ?? "")" : "Value")
                .typography(.sectionLabel).foregroundStyle(Theme.textTertiary)
            TextField("0", text: $value)
                .keyboardType(.decimalPad).typography(.heroNumber)
                .foregroundStyle(Theme.textPrimary).accessibilityLabel("Score value")
            DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])
                .logInputStyle()
            PrimaryButton(title: "SAVE ENTRY", action: save)
                .disabled(selectedMetric == nil || LogInput.positiveNumber(value) == nil || isLoadingPhoto)
        }
        .sheet(isPresented: $showingNew) { NewMetricSheet { metricID = $0 } }
        .sensoryFeedback(.impact(weight: .light), trigger: saveCount)
        .onChange(of: metrics.map(\.id)) { _, ids in
            if let metricID, !ids.contains(metricID) { self.metricID = nil }
        }
        .alert("Could not save entry", isPresented: Binding(
            get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
        )) { Button("OK", role: .cancel) {} } message: { Text(errorMessage ?? "") }
    }

    private var metricSelection: Binding<Metric?> {
        Binding(get: { selectedMetric }, set: { metricID = $0?.id })
    }

    private func save() {
        guard let metric = selectedMetric, let number = LogInput.positiveNumber(value) else { return }
        context.insert(MetricEntry(date: date, value: number, screenshotData: screenshotData, metric: metric))
        do {
            try context.save()
            metricID = nil
            value = ""
            date = .now
            screenshotData = nil
            saveCount += 1
        } catch {
            context.rollback()
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    ScoreLogForm().padding(Theme.Spacing.lg).background(Theme.background)
        .modelContainer(for: [Activity.self, Session.self, Metric.self, MetricEntry.self], inMemory: true)
        .preferredColorScheme(.dark)
}
