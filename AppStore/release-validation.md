# Release validation — September 2, 2026

## Passed

- XcodeGen project generation
- Privacy manifest and export plist syntax validation
- 168 DidICore tests
- 10 widget snapshot tests on the pinned iPhone 16 / iOS 18.6 simulator
- 2 end-to-end UI tests, including the App Store screenshot flow and confirmation undo
- iPhone Release archive for a generic iOS device using Xcode 26.2 and the iOS 26.2 SDK
- Embedded widget and Watch app validation during archive
- App icon audit: iOS and Watch source icons are 1024×1024 without alpha
- Screenshot audit: five 1320×2868 iPhone PNGs, five 1284×2778 iPhone PNGs, and one 416×496 Watch JPEG, all without alpha
- Archive contents: app, widget extension, Watch app, privacy manifest, version `1.0`, build `5`, and `ITSAppUsesNonExemptEncryption = false`
- Device-family audit: iPhone app `1`, widget `1`, and Watch companion `4`
- Signed App Store export using Cloud Managed Apple Distribution and Store provisioning profiles for all three bundle IDs
- Distribution entitlements: `beta-reports-active = true`, `get-task-allow = false`, Time Sensitive Notifications on the app, and the shared App Group on the app and widget

The earlier portrait-orientation archive warning is resolved. The generated app and
widget targets are now explicitly iPhone-only, while the companion remains Watch-only.

## Distribution artifact

The upload-ready IPA is available locally at:

`AppStore/build/Did I 1.0 (5).ipa`

The matching archive is at:

`/tmp/DidI-TestFlight-1.0-5-final-20260902.xcarchive`

## Publication blocker

The three proposed GitHub Pages URLs currently return HTTP 404. The files are ready
under `docs/`, but the release owner must commit/push them and enable GitHub Pages
before entering the support and privacy URLs in App Store Connect.
