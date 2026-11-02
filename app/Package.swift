// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "KeepSMBOnline",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "KeepSMBOnline",
            path: "Sources/KeepSMBOnline"
        )
    ]
)
