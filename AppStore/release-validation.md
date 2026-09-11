# Release validation — September 10, 2026

## Passed

- XcodeGen project generation
- Privacy manifest and export plist syntax validation
- 192 DidICore tests, including workspace creation, migration, limits, moving items, archiving, and ordering
- 10 widget snapshot tests on the pinned iPhone 16 / iOS 18.6 simulator
- iPhone Release archive for a generic iOS device using Xcode 26.3 and the iOS 26.2 SDK
- Embedded widget and Watch app validation during archive
- App icon audit: iOS and Watch source icons are 1024×1024 without alpha
- Screenshot audit: five 1320×2868 iPhone PNGs, five 1284×2778 iPhone PNGs, and one 416×496 Watch JPEG, all without alpha
- Archive contents: app, widget extension, Watch app, privacy manifest, version `1.0`, build `9`, and `ITSAppUsesNonExemptEncryption = false`
- Device-family audit: iPhone app `1`, widget `1`, and Watch companion `4`
- Signed App Store export using Cloud Managed Apple Distribution and Store provisioning profiles for all three bundle IDs
- Distribution entitlements: `beta-reports-active = true`, `get-task-allow = false`, Time Sensitive Notifications on the app, and the shared App Group on the app and widget
- App Store Connect accepted build `9` on September 10, 2026; server-side TestFlight processing is pending. Build `9` adds user-created workspaces and supersedes build `8`.

The earlier portrait-orientation archive warning is resolved. The generated app and
widget targets are now explicitly iPhone-only, while the companion remains Watch-only.

## Distribution artifact

The upload-ready IPA is available locally at:

`AppStore/build/Did I 1.0 (9).ipa`

The matching archive is at:

`/tmp/DidI-TestFlight-1.0-9-20260910.xcarchive`

SHA-256: `57a69e834cbd04aee3d78478e3e05ea4c9821d31199ae9aae3e07f877ea0195d`

## Known validation limitation

The UI test suite was attempted repeatedly, but Xcode's simulator workers did not
materialize and the run stalled before executing tests. No UI assertion failed;
this was test-runner infrastructure, but build `9` should still receive a TestFlight
smoke test covering workspace creation, switching, item moves, widgets, and migration.

## Publication blocker

The three proposed GitHub Pages URLs currently return HTTP 404. The files are ready
under `docs/`, but the release owner must commit/push them and enable GitHub Pages
before entering the support and privacy URLs in App Store Connect.
