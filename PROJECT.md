# APP CONTEXT

lockedinmax is an iOS app (SwiftUI + SwiftData, iPhone only, portrait, iOS 17+, no third-party packages, local storage only, no backend or accounts). It lets people track hours spent on activities (math, real analysis, personal projects, chess, walks) and scores (sleep score, ZetaMac score, chess rating), then shows them in a dark Gotham / NYC finance style modeled on a Robinhood-like portfolio UI: a big number, a scrubbable line chart, range pills (1D 1W 1M 3M 1Y ALL), and watchlist-style rows with sparklines. The goal is motivation: seeing your effort as a "portfolio of time" so you lock in and do more. It also generates shareable "recap cards" (like TikTok study-log slides: activity title, hours, one line of text, optional photo or screenshot). A community/friends feature may come much later; do not build it.

Finance wording used in the UI: activities are "Positions", total hours are "Time Invested", the daily summary is "Market Close".

Scores are logged by attaching a screenshot from the photo library and typing the number by hand. There is NO syncing with other apps and no HealthKit.

## Data models (Models/, SwiftData, already implemented)

Activity (id, name, colorHex, iconName, createdAt, sessions), Session (id, date, hours, note, photoData?, activity?), Metric (id, name, unit, createdAt, entries), MetricEntry (id, date, value, screenshotData?, metric?). The Log tab (Features/Log) already lets the user create activities/metrics and log sessions/scores, and has DEBUG-only "Load sample data" and "Clear all data" buttons.

## Design tokens (in DesignSystem/Theme.swift; always use these, never hardcode colors or fonts)

background #1C180D, surface #26221A, hairline #3A3526, textPrimary #D4D0C9, textSecondary #8A8783, textTertiary #B4B1AB, accent #CCFF00 (brand, active states, "up"), onAccent #1C180D, up = accent, down #FF5A5F. Fonts: system monospaced for numbers/labels, system serif (semibold) for titles. Spacing 4/8/12/16/24/32, radii 8/12/20. Existing components in DesignSystem/Components: PrimaryButton, RangePillBar (cases 1D 1W 1M 3M 1Y ALL), DeltaLabel, SectionHeader, SurfaceCard modifier.

## Folder structure (inside the app source folder)

App/ (entry, RootView with 4 tabs: Home, Stats, Log, Recap), DesignSystem/, Models/, Features/Home, Features/Stats, Features/Log, Features/Recap, Shared/. Keep files under about 200 lines. Every view has a #Preview.

## MVP scope

(a) create activities and log sessions: DONE; (b) Home dashboard with big hours number, change vs previous period, scrubbable Swift Charts line chart, range pills; (c) activity list with sparklines and per-activity detail page; (d) score logging with screenshot: DONE (charts for scores come later); (e) recap card image export.

## Current status

DONE: Task 1: PROJECT.md, folders, design system, and 4-tab shell (Home, Stats, Log, Recap). Stats and Recap remain placeholders.

DONE: Task 2: Activity, Session, Metric, and MetricEntry SwiftData models are registered in the app container; the template Item model was removed. Log supports session/score forms, activity/metric creation, PhotosPicker attachments, validation, saves, recent records, and DEBUG sample/clear tools.

DONE: Task 3: Home dashboard is live from SwiftData @Query sessions. It includes calendar-aware rolling/ALL summaries, previous-period hour and percent deltas, continuous hourly/daily/weekly/monthly buckets, cumulative/per-day chart modes, date scrubbing with selection haptics, range pills, sorted activity totals, empty-session CTA to Log, and a DEBUG-only Design System sheet. DEBUG sample sessions span 60 days with realistic times, 3 zero days, multiple sessions today and yesterday, and an increasing hours-per-session trend.

Verification: xcodebuild succeeded for iPhone 18 Pro (`5D56424B-7E7E-4542-96A2-8323A47AB06C`, iOS 27 simulator) with iOS 17 deployment, iPhone-only, and portrait command-line overrides. The new source files were picked up automatically without project-file changes. Task 3 runtime assertions passed for 1D/1W/1M/1Y/ALL windows and buckets, previous-period calculations, zero previous-period handling, cumulative totals, sorted per-activity deltas, empty data, and sample-data dates/times/trend. The app installed and launched in the simulator; a screenshot was captured to ignored DerivedData. Xcode emitted only the AppIntents metadata-skipped warning because this app has no AppIntents dependency.

Manual UI verification remains: chart scrubbing, range/mode interaction, visual layout, and physical haptics have not been exercised interactively. There is no test target; local runtime assertion harnesses are kept in ignored DerivedData/.

Existing project settings still require adjustment in Xcode for Debug and Release: minimum iOS 17.0, supported destinations iPhone only, and portrait orientation only. The template currently specifies iOS 27.0, extra platforms/device families, and landscape. project.pbxproj was not edited; build overrides do not persist these settings.

DONE: Task 4: Home Positions now show downsampled per-range sparklines, delta colors, tactile press feedback, and navigation to a live activity detail page. The detail page includes the shared scrubbable chart, all-time and active-day stats, best-day and streak calculations, grouped session history, edit/delete/photo flows, activity edit/delete, and a preselected Log-tab empty state. Shared hour and delta formatters provide consistent one-decimal hour values and signed percentages; sample data has a two-session Chess position alongside long photo-less histories.

NEXT: Task 5 Stats tab (daily/weekly/monthly breakdowns, score charts); Task 6 recap card export; Task 7 polish.

## Working rules

- Read PROJECT.md first.
- Make only the changes this task asks for.
- Do not hand-edit project.pbxproj; if a new file isn't picked up by the build, stop and tell me.
- Do not run git commit (I do).
- Do not add Mac, iPad or visionOS support.
- Build with xcodebuild for an available iPhone simulator (find one with `xcrun simctl list devices available`) and fix all errors before finishing.

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
