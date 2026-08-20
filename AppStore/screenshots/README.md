# Screenshot upload set

Upload the files in display order:

## iPhone 6.9-inch display

1. `en-US/iPhone-6.9/01-choose-what-matters.png`
2. `en-US/iPhone-6.9/02-one-tap-confirmation.png`
3. `en-US/iPhone-6.9/03-current-at-a-glance.png`
4. `en-US/iPhone-6.9/04-expiry-you-control.png`
5. `en-US/iPhone-6.9/05-private-by-design.png`

These are 1320×2868 PNG files without alpha, captured on an iPhone 16 Pro Max.
Use this English set for all three storefront localizations for version 1.0.

## Apple Watch

1. `en-US/Apple-Watch/01-recent-status.jpg`

This is a 416×496 JPEG without alpha, captured on a 46 mm Apple Watch Series 10.

The reproducible iPhone capture flow is
`Tests/UI/AppStoreScreenshotUITests.swift`. Screenshot-only sample data is compiled
under `#if DEBUG` and is excluded from Release builds.
