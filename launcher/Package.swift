// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "AntigravityProxyLauncher",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "AntigravityProxyLauncher", targets: ["AntigravityProxyLauncher"])
    ],
    targets: [
        .executableTarget(
            name: "AntigravityProxyLauncher",
            path: "Sources",
            exclude: [
                "CLI"
            ],
            resources: [
                .copy("Compatibility/compatibility.json")
            ]
        )
    ]
)
