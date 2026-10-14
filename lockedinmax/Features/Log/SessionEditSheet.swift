import SwiftData
import SwiftUI

struct SessionEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let session: Session
    @State private var hours: String
    @State private var date: Date
    @State private var note: String
    @State private var photoData: Data?
    @State private var isLoadingPhoto = false
    @State private var errorMessage: String?

    init(session: Session) {
        self.session = session
        _hours = State(initialValue: Formatters.hoursValue(session.hours))
        _date = State(initialValue: session.date)
        _note = State(initialValue: session.note)
        _photoData = State(initialValue: session.photoData)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    Text("TIME INVESTED · HOURS").typography(.sectionLabel).foregroundStyle(Theme.textTertiary)
                    TextField("0.0", text: $hours).keyboardType(.decimalPad).logInputStyle()
                    DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])
                        .logInputStyle()
                    TextField("Note (optional)", text: $note, axis: .vertical).logInputStyle()
                    PhotoInput(title: "Add photo (optional)", large: false, data: $photoData,
                               isLoading: $isLoadingPhoto)
                    PrimaryButton(title: "SAVE CHANGES", action: save)
                        .disabled(LogInput.positiveNumber(hours) == nil || isLoadingPhoto)
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
        .onAppear(perform: resetDraft)
        .tint(Theme.accent).preferredColorScheme(.dark)
    }

    private func resetDraft() {
        hours = Formatters.hoursValue(session.hours)
        date = session.date
        note = session.note
        photoData = session.photoData
    }

    private func save() {
        guard let value = LogInput.positiveNumber(hours) else { return }
        session.hours = value
        session.date = date
        session.note = note
        session.photoData = photoData
        do { try context.save(); dismiss() }
        catch { context.rollback(); errorMessage = error.localizedDescription }
    }
}

#Preview {
    SessionEditSheet(session: Session(hours: 1.5))
        .modelContainer(for: [Activity.self, Session.self, Metric.self, MetricEntry.self], inMemory: true)
}
