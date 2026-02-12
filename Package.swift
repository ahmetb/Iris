// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Iris",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "Iris",
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
