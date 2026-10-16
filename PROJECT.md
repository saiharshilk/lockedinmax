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

Task 6e: Audited all in-project Swift loops/date iteration and view observation hooks. Analytics date-bucket and streak loops now use a 100,000-iteration `LoopGuard`; the DEBUG analytics sweep runs 103 representative data-backed calls and reports timings/guard trips. Sample loading generates the 171-session/75-entry fixture off the SwiftData context first, disables autosave during insertion/save, performs one explicit save, times generation/insertion/save, and exposes a non-observable seeding flag; Home, Stats, Recap, activity/metric detail views, and DESIGN diagnostics show a loading state or skip heavy work until the batch completes. DESIGN includes “Run analytics sweep” and last sample-load timings.

Task 6e simulator verification (iPhone 18 Pro): Debug build and `build-for-testing` succeeded. The in-app/headless analytics sweep passed: 103 calls; final verified run slowest were Home 3M cumulative 45.5 ms, Home 3M per-day 45.4 ms, Home 1Y per-day 28.8 ms, Home 1Y cumulative 28.8 ms, and Home 1M per-day 14.5 ms; no loop-guard messages. Sample-data self-check passed twice at 171 sessions, 7 activities, 3 metrics, 75 entries, 0 invalid hours. Measured headless first load was 38.4 ms (generation 14.3, insertion 6.4, save 17.7); replacement was 54.5 ms (7.7, 6.9, 39.9). An earlier warmed/unwarmed run measured 158.9 ms first load, so repeated headless runs remained below 2 seconds. Interactive tapping of Load sample data and confirming the complete on-device UI update under 2 seconds remain to be checked manually; the headless timing is not an end-to-end UI measurement. A prior launch logged one AttributeGraph cycle. Heatmap generation has been moved out of body evaluation and is refreshed on the seeding-generation task after batch completion; clean-launch confirmation and manual load timing remain outstanding.

DONE: Tasks 1 to 6. Task 6b adds session-hours validation (finite, >0 and <=24), bounded sample hours, and analytics safeguards for invalid/oversized stored hours. Metric-entry writes require finite numeric input.

Task 6 adds 360x450 and 360x640 Session and Market Close cards rendered at 3x, with dark/photo session backgrounds, deterministic skyline, header/ticker, activities and score summaries, live Recap controls and SwiftUI ShareLink export. Activity detail can route a selected session into Recap. DEBUG sample data now includes seven positions, very long text, photos, a high-hour day, and multiple same-day Sleep Score entries.

Task 6 also contains fixed-height, clipped, explicitly scaled chart plots. Stats chart tooltip is overlaid and clamped within the plot frame; metric chart axis labels are limited and switch to distinct times for entries within two days. Chart overflow and duplicate same-day metric axis labels are resolved.

Task 6b: Task 6 change-set audit found no analytics feedback loop, SwiftData writes from Recap rendering, or repeated sample-data execution. The chart's 1.15 headroom is computed from fresh data and never stored. The observed exponential totals were not reproducible from the code path; if data was already corrupted, use DEBUG > DESIGN > Fix bad data to delete invalid/non-positive sessions and clamp sessions above 24 hours. Analytics ignores non-finite session values and clamps each finite contribution to 0...24. Percent changes are omitted when the prior value is zero or the result is non-finite; display formatters guard non-finite and extremely large values. DEBUG > DESIGN exposes counts/totals/recompute rate and a repair action.

Task 6b verification: the iPhone 18 Pro simulator build succeeded and the app installed and launched. Focused DEBUG runtime assertions passed for capped totals, NaN filtering, percent guards, formatter limits, session input validation, and the sample-data activity/hour bounds. Manual interactive review of data repair, chart scrubbing, navigation, share sheet destinations, and haptics remains. There is no test target; local assertion harnesses are kept in ignored DerivedData. Xcode emits an AppIntents metadata warning because the app has no AppIntents dependency.

Task 6d: the DEBUG sample generator is deterministic and bounded at 171 sessions (3 per active day across 57 of 60 days), 7 activities, 3 metrics, and 75 metric entries. Each session hours value is derived from a seeded hash of day/activity indices (not prior values) and constrained to 0.25...12. One generated 320x400 JPEG is reused by at most four sessions. The generator saves once after insertion, and requires explicit confirmation before replacing existing data. The Load sample data control is disabled while loading. DEBUG `runSampleDataSelfCheck()` builds an in-memory container and verifies counts, hours, and replace semantics. The recap rendering Self-test now uses model-free card values and checks hours, session count, tab, save events, and image output after a three-second wait; it can run on an empty database.

Task 6d verification: iPhone 18 Pro simulator build succeeded. The DEBUG launch argument `--sample-data-self-check` passed in the running simulator: first run and replacement run each reported sessions=171, activities=7, metrics=3, entries=75; invalid hours=0. The prior empty-database recap Self-test failure was caused by its `no session available` early return, rather than an observed SwiftData change. Manual checks of the DESIGN-sheet Self-test, replacement confirmation, and loading state remain.

DONE: Task 7 remains NEXT (app icon, launch screen, empty states, custom fonts); lower-is-better metrics and a weekly recap are future options.

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
