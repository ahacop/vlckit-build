// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VLCKit",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "VLCKit", targets: ["VLCKit"])
    ],
    targets: [
        .binaryTarget(
            name: "VLCKit",
            url: "https://github.com/ahacop/vlckit-build/releases/download/4.0.0-a25.1/VLCKit.xcframework.zip",
            checksum: "6e7fd99f2dae553198bbbcc9b5a0e6f7d6da50a47a43d4edd37f2a61f44ac370"
        )
    ]
)
