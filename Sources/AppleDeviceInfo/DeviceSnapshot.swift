import Foundation

/// A point-in-time device identity. Names are never persisted by this package.
public struct DeviceSnapshot: Codable, Equatable, Sendable {
    public let modelIdentifier: String
    public let modelName: String?
    /// The system API's value. On iOS 16+, this can be a generic name.
    public let deviceName: String?
    /// Only populated when access to the user-assigned name is known to be available.
    public let userAssignedName: String?
    public let isSimulator: Bool

    public var displayModel: String { modelName ?? modelIdentifier }
    public var displayName: String { userAssignedName ?? deviceName ?? displayModel }

    public init(
        modelIdentifier: String,
        modelName: String?,
        deviceName: String?,
        userAssignedName: String?,
        isSimulator: Bool = false
    ) {
        self.modelIdentifier = modelIdentifier
        self.modelName = modelName
        self.deviceName = deviceName
        self.userAssignedName = userAssignedName
        self.isSimulator = isSimulator
    }

    private enum CodingKeys: String, CodingKey {
        case modelIdentifier, modelName, deviceName, userAssignedName, isSimulator
        case displayModel, displayName
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        modelIdentifier = try values.decode(String.self, forKey: .modelIdentifier)
        modelName = try values.decodeIfPresent(String.self, forKey: .modelName)
        deviceName = try values.decodeIfPresent(String.self, forKey: .deviceName)
        userAssignedName = try values.decodeIfPresent(String.self, forKey: .userAssignedName)
        isSimulator = try values.decode(Bool.self, forKey: .isSimulator)
    }

    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(modelIdentifier, forKey: .modelIdentifier)
        // Explicit nulls keep the JSON keys consistent across platforms and permission states.
        try values.encode(modelName, forKey: .modelName)
        try values.encode(deviceName, forKey: .deviceName)
        try values.encode(userAssignedName, forKey: .userAssignedName)
        try values.encode(isSimulator, forKey: .isSimulator)
        try values.encode(displayModel, forKey: .displayModel)
        try values.encode(displayName, forKey: .displayName)
    }
}

/// A caller assertion about the iOS app's actual signing/provisioning configuration.
/// This does not request, detect, or grant an Apple entitlement.
public enum IOSDeviceNameAccess: Sendable {
    case unavailable
    case grantedByApple
}
