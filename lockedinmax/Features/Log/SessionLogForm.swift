import SwiftData
import SwiftUI

struct SessionLogForm: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Activity.createdAt) private var activities: [Activity]
    @Environment(AppState.self) private var appState
    @State private var activityID: UUID?
    private var selectedActivity: Activity? { activities.first { $0.id == activityID } }
    @State private var hours = ""
    @State private var date = Date.now
    @State private var note = ""
    @State private var photoData: Data?
    @State private var isLoadingPhoto = false
    @State private var showingNew = false
    @State private var errorMessage: String?
    @State private var saveCount = 0

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            SectionHeader(title: "Position")
            SelectionChips(items: activities, selection: activitySelection, title: { $0.name },
                           icon: { $0.iconName }, color: { Theme.activityColor($0.colorHex) },
                           newTitle: "+ New") { showingNew = true }
            Text("Time Invested · hours").typography(.sectionLabel).foregroundStyle(Theme.textTertiary)
            TextField("0.0", text: $hours)
                .keyboardType(.decimalPad).typography(.heroNumber)
                .foregroundStyle(Theme.textPrimary).accessibilityLabel("Hours")
            if LogInput.exceedsSessionLimit(hours) {
                Text("Max 24 hours per session").typography(.caption).foregroundStyle(Theme.down)
            }
            DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])
                .logInputStyle()
            TextField("Note (optional)", text: $note, axis: .vertical).logInputStyle()
            PhotoInput(title: "Add photo (optional)", large: false, data: $photoData,
                       isLoading: $isLoadingPhoto)
            PrimaryButton(title: "SAVE SESSION", action: save)
                .disabled(selectedActivity == nil || LogInput.sessionHours(hours) == nil || isLoadingPhoto)
        }
        .sheet(isPresented: $showingNew) { NewActivitySheet { activityID = $0 } }
        .onAppear { applyPrefilledActivity() }
        .onChange(of: appState.sessionActivityID) { _, _ in applyPrefilledActivity() }
        .onChange(of: activities.map(\.id)) { _, ids in
            if let activityID, !ids.contains(activityID) { self.activityID = nil }
            applyPrefilledActivity()
        }
        .sensoryFeedback(.impact(weight: .light), trigger: saveCount)
        .alert("Could not save session", isPresented: Binding(
            get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
        )) { Button("OK", role: .cancel) {} } message: { Text(errorMessage ?? "") }
    }

    private func applyPrefilledActivity() {
        guard let id = appState.sessionActivityID,
              activities.contains(where: { $0.id == id }) else { return }
        activityID = id
        appState.sessionActivityID = nil
    }

    private var activitySelection: Binding<Activity?> {
        Binding(get: { selectedActivity }, set: { activityID = $0?.id })
    }

    private func save() {
        guard let activity = selectedActivity, let value = LogInput.sessionHours(hours) else { return }
        context.insert(Session(date: date, hours: value, note: note, photoData: photoData, activity: activity))
        do {
            try context.save()
            activityID = nil
            hours = ""
            date = .now
            note = ""
            photoData = nil
            saveCount += 1
        } catch {
            context.rollback()
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    SessionLogForm().padding(Theme.Spacing.lg).background(Theme.background)
        .modelContainer(for: [Activity.self, Session.self, Metric.self, MetricEntry.self], inMemory: true)
        .preferredColorScheme(.dark)
}
