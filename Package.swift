// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "MobileFuseAdMobAdapter",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(name: "MobileFuseAdMobAdapter", targets: ["MobileFuseAdMobAdapter"])
    ],
    dependencies: [
        .package(url: "https://github.com/mobilefuse/mobilefuse-ios-sdk-spm.git", exact: "1.13.0"),
        .package(url: "https://github.com/googleads/swift-package-manager-google-mobile-ads.git", "11.0.0"..<"12.0.0")
    ],
    targets: [
        .target(
            name: "MobileFuseAdMobAdapter",
            dependencies: [
                .product(name: "MobileFuseSDK", package: "mobilefuse-ios-sdk-spm"),
                .product(name: "GoogleMobileAds", package: "swift-package-manager-google-mobile-ads")
            ]
        )
    ]
)
