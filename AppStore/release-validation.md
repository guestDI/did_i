# Release validation — August 20, 2026

## Passed

- XcodeGen project generation
- Privacy manifest and export plist syntax validation
- 159 DidICore tests
- App Store screenshot UI test
- iPhone Release archive for generic iOS device
- Embedded widget and Watch app validation during archive
- App icon audit: iOS and Watch source icons are 1024×1024 without alpha
- Screenshot audit: five 1320×2868 iPhone PNGs and one 416×496 Watch JPEG, all without alpha
- Archive contents: app, widget extension, Watch app, privacy manifest, version `1.0`, build `1`, and `ITSAppUsesNonExemptEncryption = false`

The archive emits one non-fatal warning that all interface orientations should be
supported unless the app requires full screen. The app is intentionally iPhone-only
and portrait-only; confirm this policy in App Store validation or add an explicit
full-screen declaration before upload.

## Account-side blocker

The App Store export reached Apple's signing service but could not create an IPA:

- The signed-in Apple ID has no App Store Connect provider
- Team “Dzmitry Ihnatovich” lacks permission to create iOS App Store provisioning profiles
- App Store distribution profiles are missing for the app, widget, and Watch bundle IDs

Resolve this by activating or renewing Apple Developer Program membership, accepting
pending agreements, ensuring the Apple ID has an App Store Connect provider and the
Account Holder/Admin role needed for certificates, and registering the three App IDs
and shared App Group. Then rerun:

```sh
xcodebuild archive \
  -project DidI.xcodeproj \
  -scheme DidI \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath /tmp/DidI-1.0.xcarchive \
  -allowProvisioningUpdates

xcodebuild -exportArchive \
  -archivePath /tmp/DidI-1.0.xcarchive \
  -exportPath AppStore/build \
  -exportOptionsPlist AppStore/ExportOptions.plist \
  -allowProvisioningUpdates
```

The first command currently succeeds. The second should produce the submission IPA
after the account and distribution-profile blocker is resolved.

## Publication blocker

The three proposed GitHub Pages URLs currently return HTTP 404. The files are ready
under `docs/`, but the release owner must commit/push them and enable GitHub Pages
before entering the support and privacy URLs in App Store Connect.
