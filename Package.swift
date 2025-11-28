// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "NotifyTool",
    platforms: [
        .macOS(.v11)
    ],
    products: [
        .executable(
            name: "notifytool",
            targets: ["NotifyTool"]
        )
    ],
    targets: [
        .executableTarget(
            name: "NotifyTool",
            dependencies: [],
            linkerSettings: [
                .linkedFramework("UserNotifications")
            ]
        )
    ]
)
