import SwiftData
import SwiftUI

struct SessionEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let sessionID: UUID
    @Query private var sessions: [Session]
    private var session: Session? { sessions.first { $0.id == sessionID } }
    @State private var hours: String
    @State private var date: Date
    @State private var note: String
    @State private var photoData: Data?
    @State private var isLoadingPhoto = false
    @State private var errorMessage: String?

    init(sessionID: UUID, hours: Double, date: Date, note: String, photoData: Data?) {
        self.sessionID = sessionID
        _hours = State(initialValue: Formatters.hoursValue(hours))
        _date = State(initialValue: date)
        _note = State(initialValue: note)
        _photoData = State(initialValue: photoData)
    }

    init(session: Session) {
        self.init(sessionID: session.id, hours: session.hours, date: session.date,
                  note: session.note, photoData: session.photoData)
    }

    var body: some View {
        Group {
            if session != nil {
                NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    Text("TIME INVESTED · HOURS").typography(.sectionLabel).foregroundStyle(Theme.textTertiary)
                    TextField("0.0", text: $hours).keyboardType(.decimalPad).logInputStyle()
                    if LogInput.exceedsSessionLimit(hours) {
                        Text("Max 24 hours per session").typography(.caption).foregroundStyle(Theme.down)
                    }
                    DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])
                        .logInputStyle()
                    TextField("Note (optional)", text: $note, axis: .vertical).logInputStyle()
                    PhotoInput(title: "Add photo (optional)", large: false, data: $photoData,
                               isLoading: $isLoadingPhoto)
                    PrimaryButton(title: "SAVE CHANGES", action: save)
                        .disabled(LogInput.sessionHours(hours) == nil || isLoadingPhoto)
                }
                .padding(Theme.Spacing.lg)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Edit Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .alert("Could not save session", isPresented: Binding(
                get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
            )) { Button("OK", role: .cancel) {} } message: { Text(errorMessage ?? "") }
                }
            } else {
                Color.clear.task { dismiss() }
            }
        }
        .onAppear(perform: resetDraft)
        .onChange(of: sessions.map(\.id)) { _, ids in
            if !ids.contains(sessionID) { dismiss() }
        }
        .tint(Theme.accent).preferredColorScheme(.dark)
    }

    private func resetDraft() {
        guard let session else { dismiss(); return }
        hours = Formatters.hoursValue(session.hours)
        date = session.date
        note = session.note
        photoData = session.photoData
    }

    private func save() {
        guard let value = LogInput.sessionHours(hours) else { return }
        guard let session else { dismiss(); return }
        session.hours = value
        session.date = date
        session.note = note
        session.photoData = photoData
        do { try context.save(); dismiss() }
        catch { context.rollback(); errorMessage = error.localizedDescription }
    }
}

#Preview {
    SessionEditSheet(sessionID: UUID(), hours: 1.5, date: .now, note: "", photoData: nil)
        .modelContainer(for: [Activity.self, Session.self, Metric.self, MetricEntry.self], inMemory: true)
}
