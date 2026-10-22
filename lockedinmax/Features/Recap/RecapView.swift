import SwiftData
import SwiftUI
#if os(iOS)
import UIKit
#endif

struct RecapView: View {
    @Environment(AppState.self) private var appState
    @Query private var sessions: [Session]
    @Query private var metrics: [MetricEntry]
    @State private var marketClose = false
    @State private var format: RecapCardFormat = .portrait
    @State private var cardBackground: RecapCardBackground = .dark
    @State private var selectedSessionID: UUID?
    @State private var selectedDay = Calendar.current.startOfDay(for: .now)
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
        RecapCardFactory.marketClose(selectedDay, sessions: sessions, scores: metrics, format: format)
    }
    private var currentCard: AnyView {
        if marketClose { return AnyView(MarketCloseCard(data: marketCardData)) }
        if let sessionCardData { return AnyView(SessionCard(data: sessionCardData)) }
        return AnyView(EmptyView())
    }

    var body: some View {
        Group {
#if DEBUG
            if DebugWorkState.isSeeding {
                ProgressView("Loading sample data...").tint(Theme.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                recapContent
            }
#else
            recapContent
#endif
        }
        .background(Theme.background.ignoresSafeArea())
        .noScrollEdgeEffect()
        .tabBarClearance()
        .toolbar(.hidden, for: .navigationBar)
        .onAppear(perform: consumeRoute)
        .onChange(of: appState.sessionRecapID) { _, _ in consumeRoute() }
        .onChange(of: sessions.count) { _, _ in selectDefaultSession(); renderExport() }
        .onChange(of: sessions.map(\.id)) { _, ids in
            if let selectedSessionID, !ids.contains(selectedSessionID) { self.selectedSessionID = nil }
            if let routeID = appState.sessionRecapID, !ids.contains(routeID) { appState.sessionRecapID = nil }
        }
#if DEBUG
        .onChange(of: DebugWorkState.generation) { _, _ in
            if let selectedSessionID, !sessions.contains(where: { $0.id == selectedSessionID }) {
                self.selectedSessionID = nil
            }
        }
#endif
        .onChange(of: metrics.count) { _, _ in renderExport() }
        .onChange(of: renderKey) { _, _ in renderExport() }
        .onChange(of: metrics.map(\.id)) { _, _ in renderExport() }
        .onChange(of: selectedSessionID) { _, _ in
            caption = selectedSession?.note ?? ""
            if selectedSession?.photoData == nil { cardBackground = .dark }
            renderExport()
        }
        .onChange(of: caption) { _, _ in renderExport() }
        .scrollDismissesKeyboard(.interactively)
        .toolbar { KeyboardDoneToolbar() }
        .onChange(of: marketClose) { _, _ in renderExport() }
        .onChange(of: selectedDay) { _, _ in renderExport() }
        .onChange(of: format) { _, _ in renderExport() }
        .onChange(of: cardBackground) { _, _ in renderExport() }
#if DEBUG
        .onChange(of: appState.sampleDataRefreshVersion) { _, _ in renderExport() }
#endif
#if DEBUG
        .task(id: DebugWorkState.generation) {
            guard !DebugWorkState.isSeeding else { return }
            renderExport()
        }
#else
        .task { renderExport() }
#endif
        .tint(Theme.accent)
    }

    private var recapContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                Text("Recap").typography(.title).foregroundStyle(Theme.textPrimary)
                    .padding(.top, Theme.Spacing.md)
                    .accessibilityAddTraits(.isHeader)
                RecapModeControl(marketClose: $marketClose)
                if sessions.isEmpty { emptyState }
                else {
                    selectionControls
                    if !marketClose { captionField }
                    cardPreview
                    shareButton
                }
            }
            .padding(Theme.Spacing.lg).padding(.bottom, Theme.Spacing.xxl)
        }
        .noScrollEdgeEffect()
    }

    @ViewBuilder private var selectionControls: some View {
        if marketClose { RecapMarketPicker(selectedDay: $selectedDay, activeDays: activeDays) }
        else if !recentSessions.isEmpty { sessionPicker }
        HStack(spacing: Theme.Spacing.md) {
            RecapValuePicker(title: "FORMAT", options: RecapCardFormat.allCases, selection: $format)
            if !marketClose {
                RecapValuePicker(title: "BACKGROUND", options: RecapCardBackground.allCases,
                                 selection: $cardBackground, disabledOptions: selectedSession?.photoData == nil ? [.photo] : [])
            }
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
                                Text("· \(session.date.formatted(.dateTime.day().month(.abbreviated)))")
                                    .lineLimit(1).minimumScaleFactor(0.7)
                            }
                        }
                        .typography(.caption)
                        .foregroundStyle(session.id == selectedSession?.id ? Theme.onAccent : Theme.textSecondary)
                        .frame(maxWidth: 180, alignment: .leading)
                        .padding(Theme.Spacing.md)
                        .frame(minHeight: Theme.minimumTapHeight)
                        .background(session.id == selectedSession?.id ? Theme.accent : Theme.surface,
                                    in: RoundedRectangle(cornerRadius: Theme.Radius.medium))
                    }.buttonStyle(.plain)
                }
            }
        }
        .noScrollEdgeEffect()
    }

    private var captionField: some View {
        TextField("Caption", text: Binding(get: { caption }, set: { caption = String($0.prefix(80)) }))
            .typography(.body).foregroundStyle(Theme.textPrimary).padding(Theme.Spacing.md).surfaceCard()
            .accessibilityLabel("Caption, maximum 80 characters")
    }

    private var cardPreview: some View {
        GeometryReader { geometry in
            currentCard.scaleEffect(min(geometry.size.width / format.size.width, 1), anchor: .top)
                .frame(width: format.size.width * min(geometry.size.width / format.size.width, 1),
                       height: format.size.height * min(geometry.size.width / format.size.width, 1), alignment: .top)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: format.size.height * min((UIScreen.main.bounds.width - Theme.Spacing.xl * 2 - Theme.Spacing.sm) / format.size.width, 1))
        .padding(Theme.Spacing.xs).surfaceCard()
    }

    private var shareButton: some View {
        Group {
            if let exportedImage {
                ShareLink(item: Image(uiImage: exportedImage),
                          preview: SharePreview(marketClose ? "Market Close" : "Session recap", image: Image(uiImage: exportedImage))) {
                    Text("SHARE").typography(.rowTitle).tracking(Typography.buttonTracking).foregroundStyle(Theme.onAccent)
                        .frame(maxWidth: .infinity).frame(minHeight: Theme.minimumTapHeight).padding(.vertical, Theme.Spacing.xs)
                        .background(Theme.accent, in: RoundedRectangle(cornerRadius: Theme.Radius.medium))
                }.buttonStyle(.plain)
            } else { PrimaryButton(title: "SHARE") {}.disabled(true) }
        }
    }

    private var emptyState: some View {
        EmptyStateView(title: "Nothing to share yet.",
                       message: "Log a session and your recap card shows up here.",
                       buttonTitle: "LOG A SESSION") { appState.selectedTab = .log }
    }

    private var renderKey: String {
#if DEBUG
        guard !DebugWorkState.isSeeding else { return "seeding" }
#endif
        let sessionBits = sessions.map { "\($0.id)-\($0.date.timeIntervalSince1970)-\($0.hours)-\($0.note)-\($0.photoData?.hashValue ?? 0)-\($0.activity?.name ?? "")-\($0.activity?.colorHex ?? "")" }.joined(separator: "|")
        let scoreBits = metrics.map { "\($0.id)-\($0.date.timeIntervalSince1970)-\($0.value)-\($0.metric?.name ?? "")" }.joined(separator: "|")
        let storedActivityBits = sessions.compactMap(\.activity).map { "\($0.id)-\($0.name)-\($0.colorHex)" }.joined(separator: "|")
        return "\(sessionBits)\(scoreBits)\(storedActivityBits)\(marketClose)\(selectedSessionID?.uuidString ?? "")\(selectedDay)\(caption)\(format)\(cardBackground)"
    }

    @MainActor private func renderExport() {
#if DEBUG
        guard !DebugWorkState.isSeeding else { return }
#endif
        guard !sessions.isEmpty else { exportedImage = nil; return }
#if DEBUG
        DebugDiagnostics.shared.recordRecapRender()
#endif
        let card: AnyView
        if marketClose {
            card = AnyView(MarketCloseCard(data: marketCardData))
        } else if let sessionCardData {
            card = AnyView(SessionCard(data: sessionCardData))
        } else {
            exportedImage = nil
            return
        }
        let renderer = ImageRenderer(content: card)
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
            marketClose = false
            caption = sessions.first(where: { $0.id == id })?.note ?? ""
            appState.sessionRecapID = nil
        } else { selectDefaultSession() }
        renderExport()
    }
}

#Preview {
    NavigationStack { RecapView() }
        .modelContainer(for: [Activity.self, Session.self, Metric.self, MetricEntry.self], inMemory: true)
        .environment(AppState()).preferredColorScheme(.dark)
}
