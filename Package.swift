// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AppleDeviceInfo",
    platforms: [.iOS(.v13), .macOS(.v10_15)],
    products: [
        .library(name: "AppleDeviceInfo", targets: ["AppleDeviceInfo"]),
        .executable(name: "device-info", targets: ["DeviceInfoCLI"]),
    ],
    targets: [
        .target(name: "AppleDeviceInfo"),
        .executableTarget(name: "DeviceInfoCLI", dependencies: ["AppleDeviceInfo"]),
        .testTarget(name: "AppleDeviceInfoTests", dependencies: ["AppleDeviceInfo"]),
    ]
)
