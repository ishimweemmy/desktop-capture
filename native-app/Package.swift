// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "DesktopCapture",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "DesktopCapture",
            dependencies: [],
            path: "Sources"
        )
    ]
)
