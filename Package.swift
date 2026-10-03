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
            url: "https://github.com/ahacop/vlckit-build/releases/download/4.0.0-a25/VLCKit.xcframework.zip",
            checksum: "b65ad176c861adde9855db9812031175f3ea230ee9328b1a3d4d08c3b379fc6b"
        )
    ]
)
