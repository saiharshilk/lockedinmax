import SwiftData
import SwiftUI
#if os(iOS)
import UIKit
#endif

struct RecapView: View {
    @Environment(AppState.self) private var appState
    @Query private var sessions: [Session]
    @Query private var metrics: [MetricEntry]
    @State private var mode: RecapMode = .session
    @State private var format: RecapCardFormat = .portrait
    @State private var cardBackground: RecapCardBackground = .dark
    @State private var selectedSessionID: UUID?
    @State private var selectedDay = Calendar.current.startOfDay(for: .now)
    @State private var selectedWeek = StatsAnalytics.period(kind: .week, anchor: .now).start
    @State private var caption = ""
    @State private var exportedImage: UIImage?

    private var recentSessions: [Session] { sessions.sorted { $0.date > $1.date }.prefix(14).map { $0 } }
    private var selectedSession: Session? { sessions.first { $0.id == selectedSessionID } ?? recentSessions.first }
    private var activeDays: [Date] {
        let days = Set((sessions.map(\.date) + metrics.map(\.date)).map { Calendar.current.startOfDay(for: $0) })
        return days.filter { $0 <= Calendar.current.startOfDay(for: .now) }.sorted(by: >).prefix(7).map { $0 }
    }
    private var sessionCardData: SessionRecapCardData? {
        guard let selectedSession else { return nil }
        return RecapCardFactory.session(selectedSession, allSessions: sessions, scores: metrics,
                                        caption: caption, format: format, background: cardBackground)
    }
    private var marketCardData: MarketCloseCardData {
        RecapCardFactory.marketClose(selectedDay, sessions: sessions, scores: metrics,
                                     format: format, background: cardBackground)
    }
    private var weeklyCardData: WeeklyCardData {
        RecapCardFactory.weekly(selectedWeek, sessions: sessions, scores: metrics,
                                format: format, background: cardBackground)
    }
    private var currentCard: AnyView {
        switch mode {
        case .session:
            if let sessionCardData { return AnyView(SessionCard(data: sessionCardData)) }
        case .day:
            return AnyView(MarketCloseCard(data: marketCardData))
        case .week:
            return AnyView(WeeklyCard(data: weeklyCardData))
        }
        return AnyView(EmptyView())
    }
    private var renderKey: String {
#if DEBUG
        guard !DebugWorkState.isSeeding else { return "seeding" }
#endif
        let sessionBits = sessions.map { "\($0.id)-\($0.date.timeIntervalSince1970)-\($0.hours)-\($0.note)-\($0.photoData?.hashValue ?? 0)-\($0.activity?.name ?? "")-\($0.activity?.colorHex ?? "")-\($0.activity?.iconName ?? "")" }.joined(separator: "|")
        let scoreBits = metrics.map { "\($0.id)-\($0.date.timeIntervalSince1970)-\($0.value)-\($0.metric?.name ?? "")" }.joined(separator: "|")
        return "\(sessionBits)\(scoreBits)\(mode)\(selectedSessionID?.uuidString ?? "")\(selectedDay.timeIntervalSince1970)\(selectedWeek.timeIntervalSince1970)\(caption)\(format)\(cardBackground)"
    }

    var body: some View {
        Group {
#if DEBUG
            if DebugWorkState.isSeeding {
                ProgressView("Loading sample data...").tint(Theme.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else { recapContent }
#else
            recapContent
#endif
        }
        .background(Theme.background.ignoresSafeArea())
        .noScrollEdgeEffect().tabBarClearance().toolbar(.hidden, for: .navigationBar)
        .onAppear(perform: consumeRoute)
        .onChange(of: mode) { _, newMode in
            if newMode != .session && cardBackground == .photo { cardBackground = .dark }
        }
        .onChange(of: appState.sessionRecapID) { _, _ in consumeRoute() }
        .onChange(of: sessions.map(\.id)) { _, ids in
            if let selectedSessionID, !ids.contains(selectedSessionID) { self.selectedSessionID = nil }
            if let routeID = appState.sessionRecapID, !ids.contains(routeID) { appState.sessionRecapID = nil }
            selectDefaultSession()
        }
        .onChange(of: selectedSessionID) { _, _ in
            caption = selectedSession?.note ?? ""
            if selectedSession?.photoData == nil && cardBackground == .photo { cardBackground = .dark }
        }
        .onChange(of: selectedSession?.photoData != nil) { _, hasPhoto in
            if !hasPhoto && cardBackground == .photo { cardBackground = .dark }
        }
#if DEBUG
        .onChange(of: DebugWorkState.generation) { _, _ in
            if let selectedSessionID, !sessions.contains(where: { $0.id == selectedSessionID }) {
                self.selectedSessionID = nil
            }
        }
#endif
        .task(id: renderKey) {
            do { try await Task.sleep(for: .milliseconds(250)) }
            catch { return }
            renderExport()
        }
        .scrollDismissesKeyboard(.interactively).toolbar { KeyboardDoneToolbar() }
        .tint(Theme.accent)
    }

    private var recapContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                Text("Recap").typography(.title).foregroundStyle(Theme.textPrimary)
                    .padding(.top, Theme.Spacing.md).accessibilityAddTraits(.isHeader)
                RecapModeControl(mode: $mode)
                selectionControls
                if mode == .session, selectedSession != nil { captionField }
                if mode == .session && selectedSession == nil {
                    emptyState
                } else {
                    cardPreview
                    shareButton
                }
            }
            .padding(Theme.Spacing.lg).padding(.bottom, Theme.Spacing.xxl)
        }.noScrollEdgeEffect()
    }

    @ViewBuilder private var selectionControls: some View {
        switch mode {
        case .session: sessionPicker
        case .day: RecapMarketPicker(selectedDay: $selectedDay, activeDays: activeDays)
        case .week: RecapWeekPicker(selectedWeek: $selectedWeek)
        }
        HStack(spacing: Theme.Spacing.md) {
            RecapValuePicker(title: "FORMAT", options: RecapCardFormat.allCases, selection: $format)
            RecapValuePicker(title: "BACKGROUND", options: mode == .session ? RecapCardBackground.allCases : [.dark, .neon],
                             selection: $cardBackground,
                             disabledOptions: mode == .session && selectedSession?.photoData != nil ? [] : [.photo])
        }
    }

    private var sessionPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(recentSessions) { session in
                    Button { selectedSessionID = session.id } label: {
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            Text(session.activity?.name ?? "Session").lineLimit(1).truncationMode(.tail)
                            HStack(spacing: Theme.Spacing.xs) {
                                Text(Formatters.hours(session.hours)).fixedSize().layoutPriority(1)
                                Text("· \(stableDate(session.date, format: "d MMM"))")
                                    .lineLimit(1).minimumScaleFactor(0.7)
                            }
                        }.typography(.caption)
                            .foregroundStyle(session.id == selectedSession?.id ? Theme.onAccent : Theme.textSecondary)
                            .frame(maxWidth: 180, alignment: .leading).padding(Theme.Spacing.md)
                            .frame(minHeight: Theme.minimumTapHeight)
                            .background(session.id == selectedSession?.id ? Theme.accent : Theme.surface,
                                        in: RoundedRectangle(cornerRadius: Theme.Radius.medium))
                    }.buttonStyle(.plain)
                }
            }
        }.noScrollEdgeEffect()
    }

    private var captionField: some View {
        TextField("Caption", text: Binding(get: { caption }, set: { caption = String($0.prefix(80)) }))
            .typography(.body).foregroundStyle(Theme.textPrimary).padding(Theme.Spacing.md).surfaceCard()
            .accessibilityLabel("Caption, maximum 80 characters")
    }

    private var cardPreview: some View {
        GeometryReader { geometry in
            let scale = min(geometry.size.width / format.size.width, 1)
            currentCard
                .scaleEffect(scale, anchor: .topLeading)
                .frame(width: format.size.width, height: format.size.height, alignment: .topLeading)
                .frame(width: format.size.width * scale, height: format.size.height * scale, alignment: .topLeading)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.hairline, lineWidth: 1))
                .shadow(color: .black.opacity(0.28), radius: 12, x: 0, y: 8)
        }
        .aspectRatio(format.size.width / format.size.height, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(mode.rawValue) recap preview")
    }

    private var shareButton: some View {
        Group {
            if let exportedImage {
                ShareLink(item: Image(uiImage: exportedImage),
                          preview: SharePreview(shareTitle, image: Image(uiImage: exportedImage))) {
                    Text("SHARE").typography(.rowTitle).tracking(Typography.buttonTracking).foregroundStyle(Theme.onAccent)
                        .frame(maxWidth: .infinity).frame(minHeight: Theme.minimumTapHeight).padding(.vertical, Theme.Spacing.xs)
                        .background(Theme.accent, in: RoundedRectangle(cornerRadius: Theme.Radius.medium))
                }.buttonStyle(.plain)
            } else { PrimaryButton(title: "SHARE") {}.disabled(true) }
        }
    }

    private var shareTitle: String {
        switch mode {
        case .session: return "Session recap · \(stableDate(selectedSession?.date ?? .now, format: "d MMM"))"
        case .day: return "Market Close · \(stableDate(selectedDay, format: "d MMM"))"
        case .week: return "Weekly Report · \(stableDate(weeklyCardData.startDate, format: "d"))-\(stableDate(Calendar.current.date(byAdding: .day, value: 6, to: weeklyCardData.startDate) ?? weeklyCardData.startDate, format: "d MMM"))"
        }
    }

    private var emptyState: some View {
        EmptyStateView(title: "Nothing to share yet.", message: "Log a session and your recap card shows up here.",
                       buttonTitle: "LOG A SESSION") { appState.selectedTab = .log }
    }

    @MainActor private func renderExport() {
#if DEBUG
        guard !DebugWorkState.isSeeding else { return }
#endif
        if mode == .session && selectedSession == nil { exportedImage = nil; return }
#if DEBUG
        DebugDiagnostics.shared.recordRecapRender()
#endif
        let renderer = ImageRenderer(content: currentCard
            .environment(\.dynamicTypeSize, .large)
            .environment(\.colorScheme, .dark)
            .environment(\.locale, Locale(identifier: "en_US_POSIX")))
        renderer.scale = 3
        renderer.proposedSize = ProposedViewSize(format.size)
        exportedImage = renderer.uiImage
    }

    private func selectDefaultSession() {
        if !recentSessions.contains(where: { $0.id == selectedSessionID }) { selectedSessionID = recentSessions.first?.id }
    }

    private func consumeRoute() {
        if let id = appState.sessionRecapID, sessions.contains(where: { $0.id == id }) {
            selectedSessionID = id
            mode = .session
            caption = sessions.first(where: { $0.id == id })?.note ?? ""
            appState.sessionRecapID = nil
        } else { selectDefaultSession() }
    }
}

private func stableDate(_ date: Date, format: String) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = format
    return formatter.string(from: date).uppercased()
}

#Preview {
    NavigationStack { RecapView() }
        .modelContainer(for: [Activity.self, Session.self, Metric.self, MetricEntry.self], inMemory: true)
        .environment(AppState()).preferredColorScheme(.dark)
}
