# Version 1.0 release checklist

## Prepared in the repository

- [x] App, widget, and Watch bundle identifiers are configured
- [x] App Group entitlement is shared by the app and widget
- [x] Version `1.0` and build `4` are configured
- [x] 1024×1024 iOS and Watch icons exist without alpha
- [x] Privacy manifest declares no tracking, collection, or accessed API reasons
- [x] Non-exempt encryption declaration is disabled
- [x] English, Polish, and Russian listing copy is drafted
- [x] Privacy, support, and marketing pages are ready under `docs/`
- [x] Review notes, privacy answers, age-rating answers, and export options are drafted
- [x] TestFlight beta description, feedback details, testing instructions, and review notes are drafted
- [x] Five IBM Plex-based iPhone screenshots are prepared in both accepted 6.9-inch and 6.5-inch sizes, plus one Apple Watch screenshot

## Developer account and signing

- [ ] Confirm active Apple Developer Program membership and all agreements
- [x] Register `com.dihnatovich.didi`, `.widget`, and `.watchapp`
- [x] Register and attach App Group `group.com.dihnatovich.didi` to app and widget IDs
- [ ] Verify automatic signing and App Group access on a physical signed device
- [ ] Confirm the Apple Watch app installs and syncs on a physical paired watch
- [ ] Complete the documented overnight 4:00 AM widget/device soak test
- [ ] Verify protected files before and after first unlock on a physical device

## Public URLs

- [ ] Enable GitHub Pages from the repository's `docs/` folder
- [ ] Verify marketing, support, and privacy URLs over HTTPS
- [ ] Confirm `ignatovich.dm@gmail.com` is monitored for support/privacy requests

## App Store Connect

- [ ] Create the app record with SKU `didi-ios-001`
- [x] Enter the legal copyright owner
- [ ] Add the review contact phone number; name and email are prepared
- [ ] Select Lifestyle primary and Utilities secondary categories
- [ ] Set price to Free and confirm territory availability
- [ ] Add localized metadata and URLs
- [ ] Upload iPhone 6.9-inch and Apple Watch screenshots
- [ ] Answer App Privacy: “No, we do not collect data”
- [ ] Complete the age-rating questionnaire using `age-rating.md`
- [ ] Confirm no third-party content rights are required
- [ ] Complete Digital Services Act trader-status requirements, if applicable
- [ ] Complete tax and banking details if Apple requires them for the account

## TestFlight

- [ ] Paste the prepared beta description, feedback details, testing instructions, and review notes
- [ ] Upload `AppStore/build/Did I 1.0 (4).ipa` and wait for build processing
- [ ] If prompted for export compliance, answer that the app does not use encryption
- [ ] Create an internal testing group, add build `4`, and invite internal testers
- [ ] For external testing, create an external group and submit build `4` for Beta App Review

## Build and submission

- [x] Run all automated tests and the Release archive build
- [x] Inspect the archive for app, widget, Watch app, icons, entitlements, and privacy manifest
- [x] Resolve Xcode's portrait-orientation archive warning by making the app and widget explicitly iPhone-only
- [x] Export a signed App Store distribution IPA with TestFlight entitlements
- [ ] Upload the archive and resolve every App Store validation warning
- [ ] Select build `4` for version `1.0`
- [ ] Paste the review notes and submit for review
- [ ] Keep the version in manual release until the approved build is smoke-tested
