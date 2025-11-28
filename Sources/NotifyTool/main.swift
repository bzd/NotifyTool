// ==========================================
// file: NotifyTool/Sources/NotifyTool/main.swift
// ==========================================

import Foundation
import UserNotifications
import ObjectiveC

// Global storage for the original implementations
private var originalBundleURLIMP: IMP?
private var originalBundleIdentifierIMP: IMP?

// Notification delegate to allow foreground presentation
class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        if #available(macOS 11.0, *) {
            completionHandler([.banner, .sound, .badge])
        } else {
            completionHandler([.alert, .sound, .badge])
        }
    }
}

// Keep a strong reference to the delegate
private var notificationDelegate: NotificationDelegate?

// Set up bundle information for command-line tool to work with UserNotifications
// Creates a permanent app bundle structure and uses method swizzling to make it the main bundle
func setupBundleForUserNotifications() {
    let executablePath = CommandLine.arguments[0]
    let executableURL = URL(fileURLWithPath: executablePath)
    let executableName = executableURL.lastPathComponent
    
    // Check if we're already running from inside a proper .app bundle
    // If so, no setup is needed - Bundle.main is already correct
    let executableDir = executableURL.deletingLastPathComponent()
    if executableDir.lastPathComponent == "MacOS" {
        let contentsDir = executableDir.deletingLastPathComponent()
        if contentsDir.lastPathComponent == "Contents" {
            let potentialBundlePath = contentsDir.deletingLastPathComponent()
            if potentialBundlePath.pathExtension == "app" {
                // We're running from inside a .app bundle, no setup needed
                return
            }
        }
    }
    
    // Create a permanent .app bundle structure in Application Support
    // This ensures macOS recognizes it as a real app for notification permissions
    let appSupportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    let bundleName = "NotifyTool.app"
    let bundlePath = appSupportDir.appendingPathComponent(bundleName)
    let contentsPath = bundlePath.appendingPathComponent("Contents")
    let macOSPath = contentsPath.appendingPathComponent("MacOS")
    
    // Only remove and recreate if bundle structure is invalid or executable changed
    let needsRecreate: Bool
    let bundleExecutablePath = bundlePath.appendingPathComponent("Contents/MacOS/\(executableName)")
    if FileManager.default.fileExists(atPath: bundlePath.path) && FileManager.default.fileExists(atPath: bundleExecutablePath.path) {
        // Check if executables are the same size (simple check for changes)
        let sourceAttrs = try? FileManager.default.attributesOfItem(atPath: executablePath)
        let bundleAttrs = try? FileManager.default.attributesOfItem(atPath: bundleExecutablePath.path)
        let sourceSize = sourceAttrs?[.size] as? Int ?? 0
        let bundleSize = bundleAttrs?[.size] as? Int ?? -1
        needsRecreate = (sourceSize != bundleSize)
    } else {
        needsRecreate = true
    }
    
    if needsRecreate {
        try? FileManager.default.removeItem(at: bundlePath)
    }
    
    // Create directory structure (only if needed)
    if needsRecreate {
        try? FileManager.default.createDirectory(at: macOSPath, withIntermediateDirectories: true)
    }
    
    // Try to load Info.plist from multiple locations:
    // 1. Executable's directory (for installed binaries)
    // 2. Project root (for development builds)
    var projectInfoPlistPath: URL?
    
    // Check executable directory first
    let execDirPlist = executableDir.appendingPathComponent("Info.plist")
    if FileManager.default.fileExists(atPath: execDirPlist.path) {
        projectInfoPlistPath = execDirPlist
    } else {
        // Try project root by going up from .build directory
        var searchDir = executableDir
        while searchDir.pathComponents.count > 1 {
            let plistPath = searchDir.appendingPathComponent("Info.plist")
            if FileManager.default.fileExists(atPath: plistPath.path) {
                projectInfoPlistPath = plistPath
                break
            }
            // Stop if we've gone too far up (past home directory)
            if searchDir.pathComponents.last == "Users" {
                break
            }
            searchDir = searchDir.deletingLastPathComponent()
        }
    }
    
    var infoPlist: [String: Any]
    
    // Check if Info.plist exists and is valid
    if let plistPath = projectInfoPlistPath,
       let plistData = try? Data(contentsOf: plistPath),
       let loadedPlist = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any] {
        infoPlist = loadedPlist
        // Ensure required keys are set
        if infoPlist["CFBundleExecutable"] == nil {
            infoPlist["CFBundleExecutable"] = executableName
        }
        if infoPlist["CFBundleIdentifier"] == nil {
            infoPlist["CFBundleIdentifier"] = "com.agilesv.notifytool"
        }
    } else {
        // Create default Info.plist
        infoPlist = [
            "CFBundleIdentifier": "com.agilesv.notifytool",
            "CFBundleName": "NotifyTool",
            "CFBundleExecutable": executableName,
            "CFBundlePackageType": "APPL",
            "CFBundleVersion": "1",
            "CFBundleShortVersionString": "1.0",
            "LSMinimumSystemVersion": "11.0"
        ]
    }
    
    // Write Info.plist to the bundle (only if needed or if it doesn't exist)
    let infoPlistPath = contentsPath.appendingPathComponent("Info.plist")
    if needsRecreate || !FileManager.default.fileExists(atPath: infoPlistPath.path) {
        if let plistData = try? PropertyListSerialization.data(fromPropertyList: infoPlist, format: .xml, options: 0) {
            try? plistData.write(to: infoPlistPath)
            // Set proper permissions
            try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: infoPlistPath.path)
        }
    }
    
    // Verify the bundle can be created and read
    guard let testBundle = Bundle(path: bundlePath.path) else {
        FileHandle.standardError.write(("Failed to create bundle at \(bundlePath.path)\n").data(using: .utf8)!)
        return
    }
    
    // Verify Info.plist is readable
    guard testBundle.bundleIdentifier == "com.agilesv.notifytool" else {
        FileHandle.standardError.write(("Bundle identifier not set correctly\n").data(using: .utf8)!)
        return
    }
    
    // Copy executable to bundle (required for proper bundle recognition) - only if needed
    if needsRecreate {
        let bundleExecutablePath = macOSPath.appendingPathComponent(executableName)
        try? FileManager.default.removeItem(at: bundleExecutablePath) // Remove old copy if exists
        try? FileManager.default.copyItem(at: executableURL, to: bundleExecutablePath)
        // Make it executable
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: bundleExecutablePath.path)
        
        // Sign the bundle with ad-hoc signature (required for notification permissions)
        let signProcess = Process()
        signProcess.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        signProcess.arguments = ["--force", "--deep", "--sign", "-", bundlePath.path]
        signProcess.standardOutput = FileHandle.nullDevice
        signProcess.standardError = FileHandle.nullDevice
        try? signProcess.run()
        signProcess.waitUntilExit()
        
        // Register with Launch Services
        let lsregisterPath = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
        if FileManager.default.fileExists(atPath: lsregisterPath) {
            let registerProcess = Process()
            registerProcess.executableURL = URL(fileURLWithPath: lsregisterPath)
            registerProcess.arguments = ["-f", bundlePath.path]
            registerProcess.standardOutput = FileHandle.nullDevice
            registerProcess.standardError = FileHandle.nullDevice
            try? registerProcess.run()
            registerProcess.waitUntilExit()
        }
    }
    
    // Store the bundle path in an associated object
    let bundlePathKey = UnsafeRawPointer(bitPattern: "bundlePath".hashValue)!
    objc_setAssociatedObject(Bundle.main, bundlePathKey, bundlePath.path, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    
    // Swizzle bundleURL method
    let bundleClass: AnyClass = Bundle.self
    let originalURLSelector = #selector(getter: Bundle.bundleURL)
    let swizzledURLSelector = #selector(Bundle._swizzled_bundleURL)
    
    let originalURLMethod = class_getInstanceMethod(bundleClass, originalURLSelector)
    let swizzledURLMethod = class_getInstanceMethod(bundleClass, swizzledURLSelector)
    
    if let original = originalURLMethod, let swizzled = swizzledURLMethod {
        originalBundleURLIMP = method_getImplementation(original)
        method_exchangeImplementations(original, swizzled)
    }
    
    // Swizzle bundleIdentifier method
    let originalIDSelector = #selector(getter: Bundle.bundleIdentifier)
    let swizzledIDSelector = #selector(Bundle._swizzled_bundleIdentifier)
    
    let originalIDMethod = class_getInstanceMethod(bundleClass, originalIDSelector)
    let swizzledIDMethod = class_getInstanceMethod(bundleClass, swizzledIDSelector)
    
    if let original = originalIDMethod, let swizzled = swizzledIDMethod {
        originalBundleIdentifierIMP = method_getImplementation(original)
        method_exchangeImplementations(original, swizzled)
    }
    
    // Also set the info dictionary using private API
    let bundle = Bundle.main
    let setInfoSelector = NSSelectorFromString("_setInfoDictionary:")
    if bundle.responds(to: setInfoSelector) {
        let method = class_getInstanceMethod(type(of: bundle), setInfoSelector)
        if let method = method {
            typealias SetInfoDictType = @convention(c) (AnyObject, Selector, [String: Any]) -> Void
            let implementation = method_getImplementation(method)
            let setInfo = unsafeBitCast(implementation, to: SetInfoDictType.self)
            setInfo(bundle, setInfoSelector, infoPlist)
        }
    }
}

// Extension to swizzle bundleURL and bundleIdentifier
extension Bundle {
    @objc func _swizzled_bundleURL() -> URL? {
        let bundlePathKey = UnsafeRawPointer(bitPattern: "bundlePath".hashValue)!
        if let path = objc_getAssociatedObject(self, bundlePathKey) as? String, self == Bundle.main {
            return URL(fileURLWithPath: path)
        }
        // Call original implementation
        if let originalIMP = originalBundleURLIMP {
            typealias OriginalType = @convention(c) (AnyObject, Selector) -> URL?
            let original = unsafeBitCast(originalIMP, to: OriginalType.self)
            return original(self, #selector(getter: Bundle.bundleURL))
        }
        return nil
    }
    
    // Swizzle bundleIdentifier to ensure it's read from our bundle
    @objc func _swizzled_bundleIdentifier() -> String? {
        let bundlePathKey = UnsafeRawPointer(bitPattern: "bundlePath".hashValue)!
        if let path = objc_getAssociatedObject(self, bundlePathKey) as? String, self == Bundle.main {
            if let bundle = Bundle(path: path) {
                return bundle.bundleIdentifier ?? "com.agilesv.notifytool"
            }
            // Fall back to hardcoded value if bundle can't be read
            return "com.agilesv.notifytool"
        }
        // Call original implementation for non-main bundles
        if let originalIMP = originalBundleIdentifierIMP {
            typealias OriginalType = @convention(c) (AnyObject, Selector) -> String?
            let original = unsafeBitCast(originalIMP, to: OriginalType.self)
            return original(self, #selector(getter: Bundle.bundleIdentifier))
        }
        return nil
    }
}

struct NotifyConfig {
    var title: String
    var subtitle: String?
    var body: String
    var sound: Bool
}

enum ArgParseError: Error {
    case missingValue(String)
    case missingRequired(String)
}

func parseArguments() throws -> NotifyConfig {
    var args = CommandLine.arguments.dropFirst().makeIterator()

    var title: String?
    var subtitle: String?
    var body: String?
    var sound = true

    while let arg = args.next() {
        switch arg {
        case "--title":
            guard let value = args.next() else { throw ArgParseError.missingValue("--title") }
            title = value
        case "--subtitle":
            guard let value = args.next() else { throw ArgParseError.missingValue("--subtitle") }
            subtitle = value
        case "--body", "--message":
            guard let value = args.next() else { throw ArgParseError.missingValue("--body") }
            body = value
        case "--no-sound":
            sound = false
        case "--help", "-h":
            printUsageAndExit()
        default:
            // Ignore unknown args to keep it flexible.
            continue
        }
    }

    guard let finalTitle = title else { throw ArgParseError.missingRequired("--title") }
    guard let finalBody = body else { throw ArgParseError.missingRequired("--body") }

    return NotifyConfig(
        title: finalTitle,
        subtitle: subtitle,
        body: finalBody,
        sound: sound
    )
}

func printUsageAndExit(_ message: String? = nil, exitCode: Int32 = 0) -> Never {
    if let message = message {
        FileHandle.standardError.write((message + "\n").data(using: .utf8)!)
    }
    let usage = """
    Usage:
      notifytool --title <title> --body <body> [--subtitle <subtitle>] [--no-sound]

    Examples:
      notifytool --title "Backup Complete" --body "Your backup finished successfully."
      notifytool --title "Job Done" --body "Task finished." --subtitle "Job #42"

    """
    FileHandle.standardError.write(usage.data(using: .utf8)!)
    exit(exitCode)
}

@main
struct NotifyToolMain {
    static func main() {
        // Set up bundle before using UserNotifications
        setupBundleForUserNotifications()
        
        // Print bundle location for debugging
        let appSupportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let bundlePath = appSupportDir.appendingPathComponent("NotifyTool.app")
        if FileManager.default.fileExists(atPath: bundlePath.path) {
            FileHandle.standardOutput.write("Bundle location: \(bundlePath.path)\n".data(using: .utf8)!)
        }
        
        do {
            let config = try parseArguments()
            let exitCode = sendNotification(config: config)
            exit(exitCode)
        } catch let error as ArgParseError {
            switch error {
            case .missingValue(let flag):
                printUsageAndExit("Missing value for \(flag)", exitCode: 1)
            case .missingRequired(let flag):
                printUsageAndExit("Missing required flag \(flag)", exitCode: 1)
            }
        } catch {
            printUsageAndExit("Error: \(error)", exitCode: 1)
        }
    }

    @discardableResult
    static func sendNotification(config: NotifyConfig) -> Int32 {
        let center = UNUserNotificationCenter.current()
        
        // Set up delegate to allow foreground presentation
        notificationDelegate = NotificationDelegate()
        center.delegate = notificationDelegate
        
        // Check current authorization status first
        let statusSemaphore = DispatchSemaphore(value: 0)
        var authStatus: UNAuthorizationStatus = .notDetermined
        
        center.getNotificationSettings { settings in
            authStatus = settings.authorizationStatus
            statusSemaphore.signal()
        }
        _ = statusSemaphore.wait(timeout: .now() + 2)
        
        // Request authorization if not determined
        if authStatus == .notDetermined {
            // Print message to user about the permission dialog
            FileHandle.standardOutput.write("Requesting notification permission...\n".data(using: .utf8)!)
            FileHandle.standardOutput.write("Please look for the permission dialog on your screen.\n".data(using: .utf8)!)
            
            let authSemaphore = DispatchSemaphore(value: 0)
            var grantedAuth = false
            var authError: Error?

            // Request authorization - this should trigger the system permission dialog
            center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                if let error = error {
                    authError = error
                    FileHandle.standardError.write(("Authorization error: \(error)\n").data(using: .utf8)!)
                }
                grantedAuth = granted
                authSemaphore.signal()
            }

            // Wait longer for user to respond to permission dialog (60 seconds)
            let result = authSemaphore.wait(timeout: .now() + 60)
            
            if result == .timedOut {
                FileHandle.standardError.write("Permission dialog timed out. The dialog may not have appeared.\n".data(using: .utf8)!)
                FileHandle.standardError.write("You may need to manually enable notifications in System Settings > Notifications.\n".data(using: .utf8)!)
                FileHandle.standardError.write("Look for 'NotifyTool' or 'com.agilesv.notifytool' in the list.\n".data(using: .utf8)!)
                return 1
            }
            
            if !grantedAuth {
                if let error = authError {
                    FileHandle.standardError.write(("Permission denied: \(error)\n").data(using: .utf8)!)
                } else {
                    FileHandle.standardError.write("Notification permission not granted.\n".data(using: .utf8)!)
                }
                FileHandle.standardError.write("Please grant permission in System Settings > Notifications.\n".data(using: .utf8)!)
                return 1
            }
            
            FileHandle.standardOutput.write("Notification permission granted!\n".data(using: .utf8)!)
        } else if authStatus == .denied {
            FileHandle.standardError.write("Notification permission denied. Please enable it in System Settings > Notifications > NotifyTool\n".data(using: .utf8)!)
            return 1
        } else if authStatus == .authorized {
            // Already authorized, continue
        }

        let content = UNMutableNotificationContent()
        content.title = config.title
        if let subtitle = config.subtitle {
            content.subtitle = subtitle
        }
        content.body = config.body
        if config.sound {
            content.sound = .default
        }
        
        // Set interruption level to make notification more prominent (macOS 12+)
        if #available(macOS 12.0, *) {
            content.interruptionLevel = .timeSensitive
        }

        // Use a short delay trigger instead of immediate delivery
        // This can help with notification display on some macOS versions
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        
        let requestId = UUID().uuidString
        let request = UNNotificationRequest(
            identifier: requestId,
            content: content,
            trigger: trigger
        )

        let sendSemaphore = DispatchSemaphore(value: 0)
        var exitCode: Int32 = 0

        center.add(request) { error in
            if let error = error {
                FileHandle.standardError.write(("Failed to schedule notification: \(error)\n").data(using: .utf8)!)
                exitCode = 1
            } else {
                FileHandle.standardOutput.write("Notification scheduled successfully (id: \(requestId))\n".data(using: .utf8)!)
            }
            sendSemaphore.signal()
        }

        _ = sendSemaphore.wait(timeout: .now() + 5)

        // Wait for the notification to be delivered
        Thread.sleep(forTimeInterval: 1.0)
        
        // Check if notification was delivered
        let checkSemaphore = DispatchSemaphore(value: 0)
        center.getDeliveredNotifications { notifications in
            let found = notifications.contains { $0.request.identifier == requestId }
            if found {
                FileHandle.standardOutput.write("Notification was delivered to Notification Center.\n".data(using: .utf8)!)
            } else {
                FileHandle.standardOutput.write("Notification not found in delivered notifications (may have been dismissed or not delivered yet).\n".data(using: .utf8)!)
            }
            checkSemaphore.signal()
        }
        _ = checkSemaphore.wait(timeout: .now() + 2)
        
        return exitCode
    }
}
