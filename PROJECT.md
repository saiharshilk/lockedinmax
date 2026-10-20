# APP CONTEXT

lockedinmax is an iOS app (SwiftUI + SwiftData, iPhone only, portrait, iOS 17+, no third-party packages, local storage only, no backend or accounts). It lets people track hours spent on activities (math, real analysis, personal projects, chess, walks) and scores (sleep score, ZetaMac score, chess rating), then shows them in a dark Gotham / NYC finance style modeled on a Robinhood-like portfolio UI: a big number, a scrubbable line chart, range pills (1D 1W 1M 3M 1Y ALL), and watchlist-style rows with sparklines. The goal is motivation: seeing your effort as a "portfolio of time" so you lock in and do more. Users also share "recap cards" (like TikTok study-log slides: activity title, hours, one line of text, optional photo or screenshot). A community/friends feature may come much later; do not build it.

Finance wording used in the UI: activities are "Positions", total hours are "Time Invested", the daily summary is "Market Close".

Scores are logged by attaching a screenshot from the photo library and typing the number by hand. There is NO syncing with other apps and no HealthKit.

## Design tokens

Use the tokens in `DesignSystem/Theme.swift`: background #1C180D, surface #26221A, hairline #3A3526, textPrimary #D4D0C9, textSecondary #8A8783, textTertiary #B4B1AB, accent #CCFF00 (brand, active states, and up), onAccent #1C180D, up = accent, down #FF5A5F. Fonts are system monospaced for numbers/labels and system serif semibold for titles. Spacing 4/8/12/16/24/32, radii 8/12/20. Components in DesignSystem/Components: PrimaryButton, RangePillBar, DeltaLabel, SectionHeader, SurfaceCard modifier, Sparkline.

## Data models and shared logic

Models in `Models/` use SwiftData: Activity (id, name, colorHex, iconName, createdAt, sessions), Session (id, date, hours, note, photoData?, activity?), Metric (id, name, unit, createdAt, entries), and MetricEntry (id, date, value, screenshotData?, metric?). Log supports activity/metric creation, session/score logging, recent-record swipe-to-delete, and DEBUG-only sample/clear controls.

`Shared/Analytics.swift` provides windows, previous windows, totals, deltas, buckets, cumulative/per-bucket series, and per-activity totals. `Shared/StatsAnalytics.swift` provides day/week/month periods, stacked buckets by activity, breakdown shares, insights, 12-week heatmap, and metric stats. `Shared/Formatters.swift` formats hours, signed percentages, deltas, and metric values. `ActivityStats` calculates TOTAL, AVG / ACTIVE DAY, BEST DAY, and STREAK.

`Shared/Charts/` contains the Home/activity time-series chart and metric chart. Each chart is constrained to a fixed height, clipped, and explicitly y-scaled. The Stats TIME stacked chart uses the same containment and keeps its scrubbing tooltip overlaid and clamped inside the chart frame. Metric axes limit their labels and use unique time-of-day labels for entries within two days.

## Implemented screens

- Home: hero number, delta, scrubbable chart, range pills, cumulative/per-day toggle, and POSITIONS rows with sparklines.
- Activity detail: chart, stats, SESSIONS history with edit/delete, and a Share recap action for each session.
- Stats: TIME (DAY/WEEK/MONTH with period navigator, stacked chart and tooltip, BREAKDOWN, INSIGHTS, 12-week heatmap) and SCORES (metric rows -> MetricDetailView with chart, stats, history, edit).
- Log: session and score entry, activity/metric management, and recent logs.
- Recap: SESSION and MARKET CLOSE modes, live fixed-ratio previews, selectable 4:5/9:16 output, optional session photo background, editable card-only caption, and ShareLink image export.

## Folder structure

Inside the app source folder: App/ (entry, RootView with Home, Stats, Log, Recap tabs and shared app state), DesignSystem/, Models/, Features/Home, Features/Stats, Features/Log, Features/Recap/Cards, Shared/. Keep files near 200 lines. Views include `#Preview` blocks.

## MVP scope

(a) activities + session logging: DONE; (b) Home: DONE; (c) activity detail: DONE; (d) score logging, score charts, and Stats: DONE; (e) recap card image export: DONE.

Score changes use a higher-is-better assumption for coloring; lower-is-better support is not implemented.

## Current status

Task 6f: Audited save observers, model holders, and every deletion flow. The DEBUG save observer now listens only to `ModelContext.didSave`, reads identifier counts from the notification, and stores count-only events; no save observer accesses model attributes or caches model instances. App state selections and detail/edit destinations store UUIDs, navigation paths reset before bulk changes, bulk deletion/replace/repair hides dependent content while seeding, and detail/edit sheets dismiss if their queried model disappears. Recent-log presentation copies display values into plain records and re-fetches a model by UUID only for a delete action. DESIGN’s “Churn test” runs ten cycles against the app’s real model context through the same load/clear/repair operations, with 300 ms pauses and final count validation.

Task 6f simulator verification (iPhone 18 Pro, iOS 27.0): Debug build and `build-for-testing` succeeded. The simulator churn test passed 10 cycles; final state was sessions=171, activities=7, metrics=3, entries=75, invalid=0. The final clean verification run (after building current sources) passed all 10 cycles with final sessions=171, activities=7, metrics=3, entries=75, invalid=0. Final post-edit simulator run cycle timings were 1430.5, 869.4, 992.0, 876.6, 963.9, 860.9, 937.7, 864.3, 1047.7, and 852.8 ms; no invalidated-model fatal message occurred. The fixture was present before the first cycle. The test uses an existing session ID to select the Recap tab before each replacement, then clears selection and resets all navigation paths before destructive operations. Activity detail is not simultaneously open because reset-to-root is required before each bulk operation. “Check sample generator” and “Run analytics sweep” remain in DESIGN. The build still reports the existing AppIntents metadata warning; the save observer no longer captures ModelContext in its callback. The final churn run was performed with the latest built simulator app after the last diagnostics UI changes.

Audit inventory: the sole SwiftData notification observer is `Features/Log/DebugDiagnostics.swift` `ModelContext.didSave`; it does not resolve identifiers into models. `Session`, `Activity`, `Metric`, and `MetricEntry` references in query-backed views/one-action callbacks remain transient; saved navigation/edit selection is UUID-based. Deletion behavior and remaining query-scoped model references are detailed in the Task 6f audit below.


DONE: Tasks 1 to 7. Task 6b adds session-hours validation (finite, >0 and <=24), bounded sample hours, and analytics safeguards for invalid/oversized stored hours. Metric-entry writes require finite numeric input.

Task 6 adds 360x450 and 360x640 Session and Market Close cards rendered at 3x, with dark/photo session backgrounds, deterministic skyline, header/ticker, activities and score summaries, live Recap controls and SwiftUI ShareLink export. Activity detail can route a selected session into Recap. DEBUG sample data now includes seven positions, very long text, photos, a high-hour day, and multiple same-day Sleep Score entries.

Task 6 also contains fixed-height, clipped, explicitly scaled chart plots. Stats chart tooltip is overlaid and clamped within the plot frame; metric chart axis labels are limited and switch to distinct times for entries within two days. Chart overflow and duplicate same-day metric axis labels are resolved.

Task 6b: Task 6 change-set audit found no analytics feedback loop, SwiftData writes from Recap rendering, or repeated sample-data execution. The chart's 1.15 headroom is computed from fresh data and never stored. The observed exponential totals were not reproducible from the code path; if data was already corrupted, use DEBUG > DESIGN > Fix bad data to delete invalid/non-positive sessions and clamp sessions above 24 hours. Analytics ignores non-finite session values and clamps each finite contribution to 0...24. Percent changes are omitted when the prior value is zero or the result is non-finite; display formatters guard non-finite and extremely large values. DEBUG > DESIGN exposes counts/totals/recompute rate and a repair action.

Task 6b verification: the iPhone 18 Pro simulator build succeeded and the app installed and launched. Focused DEBUG runtime assertions passed for capped totals, NaN filtering, percent guards, formatter limits, session input validation, and the sample-data activity/hour bounds. Manual interactive review of data repair, chart scrubbing, navigation, share sheet destinations, and haptics remains. There is no test target; local assertion harnesses are kept in ignored DerivedData. Xcode emits an AppIntents metadata warning because the app has no AppIntents dependency.

Task 6d: the DEBUG sample generator is deterministic and bounded at 171 sessions (3 per active day across 57 of 60 days), 7 activities, 3 metrics, and 75 metric entries. Each session hours value is derived from a seeded hash of day/activity indices (not prior values) and constrained to 0.25...12. One generated 320x400 JPEG is reused by at most four sessions. The generator saves once after insertion, and requires explicit confirmation before replacing existing data. The Load sample data control is disabled while loading. DEBUG `runSampleDataSelfCheck()` builds an in-memory container and verifies counts, hours, and replace semantics. The recap rendering Self-test now uses model-free card values and checks hours, session count, tab, save events, and image output after a three-second wait; it can run on an empty database.

Task 6d verification: iPhone 18 Pro simulator build succeeded. The DEBUG launch argument `--sample-data-self-check` passed in the running simulator: first run and replacement run each reported sessions=171, activities=7, metrics=3, entries=75; invalid hours=0. The prior empty-database recap Self-test failure was caused by its `no session available` early return, rather than an observed SwiftData change. Manual checks of the DESIGN-sheet Self-test, replacement confirmation, and loading state remain.

Task 7: Polish, fixes, fonts, icon, launch — DONE. Shared tab-bar clearance, consistent custom serif page titles, round-half-up two-decimal hours formatting, constrained position rows, four-letter recap ticker abbreviations, single AppState tab selection, keyboard Done toolbars, reusable empty states, custom font registration with system fallbacks, Dynamic Type cap, 1024px app icon variants, launch background color asset, cold-launch splash, accessibility summaries/hit areas, and Reduce Motion support are implemented. Diagnostics, counters, data tools, and sample/test code remain DEBUG-only; DESIGN remains a DEBUG-only Home toolbar action.

Task 7 verification: JetBrains Mono Regular/Medium/SemiBold (official JetBrains Mono v2.304 release) and Playfair Display variable (official Google Fonts `ofl/playfairdisplay`) were downloaded to `lockedinmax/Resources/Fonts/` with both OFL licenses. The AppIcon catalog uses `AppIcon.png`, `AppIcon-dark.png`, and `AppIcon-tinted.png` (1024×1024 sRGB RGB PNGs; tinted is grayscale on black); target build setting is `AppIcon`. Launch background is #1C180D. Debug and Release simulator builds succeeded. Xcode continues to emit its existing AppIntents metadata warning because there is no AppIntents dependency; no Swift compile warnings remain after cleanup. The DEBUG simulator app should be tested at Home → DESIGN → Data Diagnostics; Self-test, Churn test, and analytics sweep controls retain their existing behavior. The last full in-app churn run remains the Task 6f verification above.

Lower-is-better metrics and a weekly recap are future options.

### Task 6f audit details

- **Save notifications:** `Features/Log/DebugDiagnostics.swift` registers a single `ModelContext.didSave` observer. It reads only inserted/updated/deleted identifier counts from `userInfo`, retains no model objects, and writes count-only events. No Combine observer or `objectsDidChange`/`willSave` listener exists. The prior implementation read `Session.hours` from `willSave` arrays and resolved deleted IDs back to invalidated objects in `didSave`; that is the direct root cause matching the reported `Session.hours.getter` crash stack.
- **Model-valued view data:** `@Query` arrays in Home, Stats, Recap, DESIGN, detail views, and recent logs are SwiftData’s live query results. Analytics/recap computations scan them during view evaluation and do not cache models in app state. Activity/metric detail routes (`ActivityDetailView`, `MetricDetailView`) store UUIDs and resolve against `@Query`; edit sheets (`SessionEditSheet`, `MetricEditSheet`, `MetricEntryEditSheet`) do the same and dismiss when the item disappears. Session/metric forms retain UUID selection, chart selection retains a metric-entry UUID, Recap stores selected session UUID, and recent-log rows store IDs plus copied display values. Recap card builders synchronously convert queried model values into plain `RecapSessionValue`/`RecapScoreValue` structs; `ShareLink` retains the rendered image, not a SwiftData model.
- **Other transient holders:** `ActivitySessionRow`, `MetricEntryRow`, chart input values, Home/Stats summary parameters, and analytics helper dictionaries temporarily hold queried objects while those views/actions are evaluated. `NewActivitySheet` resolves an optional activity UUID from its query when editing; it receives/sends only IDs across the sheet boundary. `NewMetricSheet` returns only the created metric UUID. Sample generator arrays exist only through generation/insertion/save; self-test snapshots only primitive values. Model relationship arrays in `Models/` are schema relationships, unchanged.
- **Deletion order:** Load/replace and Clear-all call `prepareForBulkDataChange()` first (clears `sessionActivityID` and `sessionRecapID`, selects Home, resets each `NavigationPath`); `DebugWorkState.isSeeding` then hides heavy model-backed screens; all four model types are deleted/inserted and saved once; finally the flag is cleared and refresh generation increments once. Invalid-session deletion and over-24 repair also reset navigation, hide content, fetch fresh sessions, mutate/delete, save once, and refresh. Activity/metric delete dismisses any child editor/photo, deletes (activity cascades sessions and metric cascades entries), saves, then dismisses detail; failure rolls the context back. Single-session/entry swipe deletion closes any matching editor, deletes and saves; query-driven rows disappear on refresh. At the delete/save boundary the list can briefly still have a SwiftUI row value for the deleted model; the active edit/recap/navigation holders are cleared or ID-resolved and no subsequent property read is made by the delete path. If the backing `@Query` publishes after save, stale detail routes render their deleted placeholder and dismiss.
- **Delete sources:** `Features/Log/SampleData.swift` replace and clear; `Features/Log/DebugDataTools.swift` invalid deletion and over-24 clamp; `Features/Home/ActivityDetailView.swift` activity cascade and session swipe; `Features/Stats/MetricDetailView.swift` metric cascade and entry swipe; `Features/Log/RecentLogs.swift` recent session/entry swipe. All bulk paths use the fresh fetch inside their operation rather than retaining a prior `@Query` snapshot.

## Working rules

- Read PROJECT.md first. Make only requested changes.
- Do not hand-edit project.pbxproj. Source files are automatically included through the synchronized project folder; if a new file is not picked up, stop.
- Do not commit.
- Do not add Mac, iPad, or visionOS support or change SwiftData models.
- Do not request Photos write permission or edit Info.plist; use ShareLink for export.
- Build with xcodebuild for an available iPhone simulator and fix build errors.

### Verified build command

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project lockedinmax.xcodeproj -scheme lockedinmax \
  -destination 'platform=iOS Simulator,id=5D56424B-7E7E-4542-96A2-8323A47AB06C' \
  -derivedDataPath DerivedData \
  IPHONEOS_DEPLOYMENT_TARGET=17.0 TARGETED_DEVICE_FAMILY=1 \
  SUPPORTED_PLATFORMS='iphoneos iphonesimulator' \
  INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone=UIInterfaceOrientationPortrait build
```
