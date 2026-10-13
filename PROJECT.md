# APP CONTEXT

lockedinmax is an iOS app (SwiftUI + SwiftData, iPhone only, portrait, iOS 17+, no third-party packages, local storage only, no backend or accounts). It lets people track hours spent on activities (math, real analysis, personal projects, chess, walks) and scores (sleep score, ZetaMac score, chess rating), then shows them in a dark Gotham / NYC finance style modeled on a Robinhood-like portfolio UI: a big number, a scrubbable line chart, range pills (1D 1W 1M 3M 1Y ALL), and watchlist-style rows with sparklines. The goal is motivation: seeing your effort as a "portfolio of time" so you lock in and do more. It also generates shareable "recap cards" (like TikTok study-log slides: activity title, hours, one line of text, optional photo or screenshot). A community/friends feature may come much later; do not build it.

Finance wording used in the UI: activities are "Positions", total hours are "Time Invested", the daily summary is "Market Close".

Scores are logged by attaching a screenshot from the photo library and typing the number by hand. There is NO syncing with other apps and no HealthKit.

## Design tokens

Already in code in DesignSystem/Theme.swift; always use these, never hardcode colors or fonts.

background #1C180D, surface #26221A, hairline #3A3526, textPrimary #D4D0C9, textSecondary #8A8783, textTertiary #B4B1AB, accent #CCFF00 (brand, active states, "up"), onAccent #1C180D, up = accent, down #FF5A5F. Fonts: system monospaced for numbers/labels, system serif (semibold) for titles. Spacing 4/8/12/16/24/32, radii 8/12/20. Existing components in DesignSystem/Components: PrimaryButton, RangePillBar, DeltaLabel, SectionHeader, SurfaceCard modifier.

## Folder structure (inside the app source folder)

App/ (entry, RootView), DesignSystem/, Models/, Features/Home, Features/Stats, Features/Log, Features/Recap, Shared/. Keep files under about 200 lines. Every view has a #Preview.

## MVP scope

(a) create activities (name, color, icon) and log sessions (hours, note, optional photo); (b) Home dashboard: big hours number, change vs previous period, scrubbable Swift Charts line chart, range pills; (c) activity list with sparklines and a per-activity detail page; (d) log a score with a screenshot plus a typed number; (e) export a recap card image for sharing.

## Current status

DONE: Task 1: PROJECT.md, folders, design system, 4-tab shell (Home, Stats, Log, Recap). Home currently shows a "Design System Preview"; Stats and Recap are "Coming soon" placeholders.

DONE: Task 2: Activity, Session, Metric, and MetricEntry SwiftData models registered in the app container; template Item removed. Log has Session/Score forms, position and metric creation, eight preset colors, twelve icons, PhotosPicker attachments with removal, positive-number validation, explicit saves with error alerts, form reset and light haptic feedback, and the latest ten combined records with swipe-to-delete. DEBUG tools load four activities and two metrics across 60 days (207 sessions and 120 scores) or clear all data with confirmation.

Verification: xcodebuild succeeded for iPhone 18 Pro (`5D56424B-7E7E-4542-96A2-8323A47AB06C`, iOS 27 simulator) with iOS 17 deployment, iPhone-only, and portrait command-line overrides. All source files were picked up automatically. The app installed, launched, and remained running. Simulator runtime checks passed for sample-data counts and dates, repeat-load protection, inverse relationships, cascade deletion, clearing all models, localized numeric validation, and disk persistence including external image data. No Swift compiler warnings; Xcode emitted only its AppIntents metadata-skipped warning because this app has no AppIntents dependency.

Manual UI verification remains: the Simulator GUI is absent from this Xcode installation and macOS UI automation is unavailable. Tap, swipe, PhotosPicker, visual layout, and physical haptic checks were not performed. There is no test target; the runtime check harness is kept in ignored DerivedData/.

Existing project settings still require adjustment in Xcode for Debug and Release: minimum iOS 17.0, supported destinations iPhone only, and portrait orientation only. The template currently specifies iOS 27.0, extra platforms/device families, and landscape. project.pbxproj was not edited; build overrides do not persist these settings.

NEXT: Task 3 Home dashboard + charts, Task 4 activity list/detail, Task 5 recap card export.

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
