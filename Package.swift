// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Catalyst",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Catalyst", targets: ["Catalyst"])
    ],
    targets: [
        .executableTarget(
            name: "Catalyst",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("Carbon"),
                .linkedFramework("CoreServices"),
                .linkedFramework("ServiceManagement")
            ]
        ),
        .testTarget(
            name: "CatalystTests",
            dependencies: ["Catalyst"]
        )
    ]
)
