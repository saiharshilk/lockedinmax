# lockedinmax

## Vision
lockedinmax is a dark, Gotham / NYC finance themed app for tracking hours spent on activities (math, projects, chess, walks) and scores (sleep score, ZetaMac, chess rating). Present the data like a Robinhood-style portfolio: big number, scrubbable line chart, range pills, and watchlist-style rows.

Generate shareable recap cards inspired by TikTok study-log slides: activity title, hours, one line of text, and an optional photo or screenshot.

Finance wording:
- Activities: **Positions**
- Daily summary: **Market Close**
- Hours total: **Time Invested**

## Tech rules
- SwiftUI only; no UIKit unless unavoidable.
- SwiftData storage, local only; no backend or accounts.
- Minimum iOS 17; Swift Charts for charts.
- No third-party packages and no force unwraps.
- The only UIKit bridge is `Theme.configureTabBarAppearance()`, needed because native SwiftUI TabView does not expose unselected item colors. Keep any appearance styling in the design system.
- Keep Swift files under about 200 lines each.
- Include previews for every view.
- Preserve the template Item model and SwiftData container until a later task replaces them.

### Existing project setting
The generated project currently specifies iOS 27.0. Do not hand-edit `project.pbxproj`. Set the minimum deployment target to 17.0 in Xcode's target Build Settings (Debug and Release). Until then, verify iOS 17 API compatibility using `IPHONEOS_DEPLOYMENT_TARGET=17.0` on the build command; that override does not persist the setting.

## Design tokens
All colors and fonts live in the design system. Colors are defined in code using `Color(hex:)`.

| Color | Hex | Purpose |
| --- | --- | --- |
| background | #1C180D | App background |
| surface | #26221A | Cards and inputs |
| hairline | #3A3526 | 1 pt dividers and borders |
| textPrimary | #D4D0C9 | Main text |
| textSecondary | #8A8783 | Secondary text and inactive tabs |
| textTertiary | #B4B1AB | Tertiary text |
| accent | #CCFF00 | Brand, active states, up moves |
| onAccent | #1C180D | Text on accent |
| up | #CCFF00 | Same as accent |
| down | #FF5A5F | Down moves |

Spacing: **4, 8, 12, 16, 24, 32 pt**.
Corner radii: **small 8, medium 12, large 20 pt**.

System typography for now (custom fonts come later). Numbers and labels are monospaced; titles are serif and semibold.

| Style | Size | Design / weight | Additional treatment |
| --- | --- | --- | --- |
| heroNumber | 48 pt | Monospaced semibold | |
| title | 30 pt | Serif semibold | |
| sectionLabel | 11 pt | Monospaced regular | Uppercase, 2 pt tracking |
| rowTitle | 13 pt | Monospaced semibold | |
| body | 15 pt | Monospaced regular | |
| caption | 12 pt | Monospaced regular | |

Components: `PrimaryButton(title:action:)`, a generic binding-driven `RangePillBar` with 1D/1W/1M/3M/1Y/ALL, `DeltaLabel(value:text:)`, `SectionHeader(title:)`, and the `SurfaceCard` view modifier. Each has its own file and preview.

## Folder structure
```text
PROJECT.md
lockedinmax/
  App/
    lockedinmaxApp.swift
    RootView.swift
  DesignSystem/
    Theme.swift
    Typography.swift
    Components/
      PrimaryButton.swift
      RangePillBar.swift
      DeltaLabel.swift
      SectionHeader.swift
      SurfaceCard.swift
  Models/
    .gitkeep
  Features/
    Home/
      DesignSystemPreview.swift
    Stats/
      StatsView.swift
    Log/
      LogView.swift
    Recap/
      RecapView.swift
  Shared/
    ComingSoonView.swift
  Item.swift
  Assets.xcassets/
```
`Shared` contains the reusable shell placeholder; no feature models exist yet. Only the empty `Models` folder keeps a `.gitkeep`: Xcode copies synced markers as resources, and two identical marker names cause duplicate bundle outputs. The app source folder is filesystem-synchronized by Xcode: new source files are automatically included.

## MVP scope
1. Create activities (name, color, icon) and log sessions (hours, note, optional photo).
2. Home dashboard: big hours number, change vs previous period, scrubbable line chart, range pills **1D / 1W / 1M / 3M / 1Y / ALL**.
3. Activity list with sparklines and a per-activity detail page.
4. Log a score by attaching a screenshot from the photo library and typing the number; no syncing with other apps.
5. Export a recap card as an image for sharing.

Task 1 is only structure, design system, and app shell. Home temporarily displays an interactive design-system gallery; Stats, Log, and Recap are placeholders. Do not implement real features yet.

## Working rules for the AI agent
- Read this file at the start of every task.
- Make only the changes the task asks for.
- Never use hardcoded colors or fonts outside the design system files.
- After changes, run `xcodebuild` and fix errors before finishing; fix warnings introduced by the task.
- Do not hand-edit `project.pbxproj`. If a newly created file produces “cannot find X in scope”, stop and report it instead of editing the project file.
- Do **not** run `git commit`; the user commits.
- Finish every task with a short report of files created, files changed, and how the user can test.

## Build and shell checks
Use the same available iPhone simulator for each check. Task 1 selected iPhone 18 Pro, UUID `5D56424B-7E7E-4542-96A2-8323A47AB06C`.

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project lockedinmax.xcodeproj \
  -scheme lockedinmax \
  -destination 'platform=iOS Simulator,id=5D56424B-7E7E-4542-96A2-8323A47AB06C' \
  -derivedDataPath DerivedData \
  IPHONEOS_DEPLOYMENT_TARGET=17.0 build
```

Run the app and inspect all four tabs, scroll Home through swatches and typography, select each range pill, and tap the sample primary button. Confirm dark backgrounds, accent selection, up/down labels, and “Coming soon” placeholders.
