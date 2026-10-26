import Darwin
import Foundation

#if os(iOS)
import UIKit
#elseif os(macOS)
import SystemConfiguration
#else
#error("AppleDeviceInfo supports iOS and macOS only.")
#endif

public enum AppleDevice {
    /// Hardware identity does not require UIKit or a main-thread hop.
    public static var modelIdentifier: String {
        #if targetEnvironment(simulator)
        if let identifier = nonEmpty(ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"]) {
            return identifier
        }
        #endif

        #if os(macOS)
        var size = 0
        guard sysctlbyname("hw.model", nil, &size, nil, 0) == 0, size > 0 else {
            return "unknown"
        }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname("hw.model", &buffer, &size, nil, 0) == 0 else {
            return "unknown"
        }
        return nonEmpty(String(cString: buffer)) ?? "unknown"
        #else
        var system = utsname()
        guard uname(&system) == 0 else { return "unknown" }
        let capacity = MemoryLayout.size(ofValue: system.machine)
        return withUnsafePointer(to: &system.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: capacity) {
                nonEmpty(String(cString: $0)) ?? "unknown"
            }
        }
        #endif
    }

    public static var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    public static func modelName(for identifier: String) -> String? {
        ModelNames.name(for: identifier)
    }

    #if os(iOS)
    /// Call with `await` from another actor. No synchronous main-queue dispatch is used.
    @MainActor
    public static func current(nameAccess: IOSDeviceNameAccess = .unavailable) -> DeviceSnapshot {
        snapshot(systemDeviceName: UIDevice.current.name, nameAccess: nameAccess)
    }

    /// For adapters that already obtain the system name in their own lifecycle/threading context.
    /// The caller is responsible for reading UIKit values on the appropriate actor.
    public static func snapshot(
        systemDeviceName: String?,
        nameAccess: IOSDeviceNameAccess = .unavailable
    ) -> DeviceSnapshot {
        makeIOSSnapshot(
            identifier: modelIdentifier,
            systemDeviceName: systemDeviceName,
            majorVersion: ProcessInfo.processInfo.operatingSystemVersion.majorVersion,
            simulator: isSimulator,
            nameAccess: nameAccess
        )
    }
    #elseif os(macOS)
    /// Re-reads ComputerName on every call, including after a user renames their Mac.
    public static func current() -> DeviceSnapshot {
        let name = nonEmpty(SCDynamicStoreCopyComputerName(nil, nil) as String?)
        let identifier = modelIdentifier
        return DeviceSnapshot(
            modelIdentifier: identifier,
            modelName: modelName(for: identifier),
            deviceName: name,
            userAssignedName: name
        )
    }
    #endif

    static func makeIOSSnapshot(
        identifier: String,
        systemDeviceName: String?,
        majorVersion: Int,
        simulator: Bool,
        nameAccess: IOSDeviceNameAccess
    ) -> DeviceSnapshot {
        let name = nonEmpty(systemDeviceName)
        let canReadAssignedName = !simulator && (majorVersion < 16 || nameAccess == .grantedByApple)
        return DeviceSnapshot(
            modelIdentifier: identifier,
            modelName: modelName(for: identifier),
            deviceName: name,
            userAssignedName: canReadAssignedName ? name : nil,
            isSimulator: simulator
        )
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return value
    }
}
