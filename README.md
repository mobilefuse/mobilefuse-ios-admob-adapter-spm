# MobileFuse AdMob Adapter Swift Package

This repository publishes the Swift Package Manager distribution of the MobileFuse adapter for Google Mobile Ads (AdMob) mediation.

## Package URL

`https://github.com/mobilefuse/mobilefuse-ios-admob-adapter-spm.git`

## Current Release

`1.13.0` (adapter version `1.13.0.0`)

## Package Details

The Swift package builds the MobileFuse AdMob adapter from source. It depends on:

- MobileFuse iOS SDK `1.13.0` via `https://github.com/mobilefuse/mobilefuse-ios-sdk-spm.git`
- Google Mobile Ads SDK `11.x` via `https://github.com/googleads/swift-package-manager-google-mobile-ads.git`

## Versioning

Adapter versions have four components (`SDK_MAJOR.SDK_MINOR.SDK_PATCH.ADAPTER_REVISION`), but Swift Package Manager requires three-component tags. Tags use `SDK_MAJOR.SDK_MINOR.(SDK_PATCH * 100 + ADAPTER_REVISION)`, the same encoding the adapter reports to Google Mobile Ads:

| Adapter version | Tag |
| --- | --- |
| `1.13.0.0` | `1.13.0` |
| `1.13.0.1` | `1.13.1` |
| `1.13.1.0` | `1.13.100` |
