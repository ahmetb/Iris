// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Iris",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.9.0"),
    ],
    targets: [
        .executableTarget(
            name: "Iris",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            path: "Iris/Iris",
            exclude: [
                "Assets.xcassets",
                "Info.plist",
                "Iris.entitlements",
            ],
            linkerSettings: [
                .linkedFramework("AVFoundation"),
                .linkedFramework("Carbon"),
                .linkedFramework("ServiceManagement"),
            ]
        )
    ]
)
