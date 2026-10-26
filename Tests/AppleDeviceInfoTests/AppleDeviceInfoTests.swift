import Foundation
import XCTest
@testable import AppleDeviceInfo

final class AppleDeviceInfoTests: XCTestCase {
    func testKnownAndUnknownModels() {
        XCTAssertEqual(AppleDevice.modelName(for: "iPhone15,2"), "iPhone 14 Pro")
        XCTAssertEqual(AppleDevice.modelName(for: "iPad14,5"), "iPad Pro 12.9 Inch6")
        XCTAssertEqual(AppleDevice.modelName(for: "iPad16,3"), "iPad Pro M4 11 Inch")
        XCTAssertEqual(AppleDevice.modelName(for: "iPad16,5"), "iPad Pro M4 13 Inch")
        XCTAssertNil(AppleDevice.modelName(for: "iPhone999,1"))
        XCTAssertNil(AppleDevice.modelName(for: "Mac999,1"))
    }

    func testIOSNamePermissionBoundary() {
        let legacy = iosSnapshot(version: 15, name: "工作手机")
        XCTAssertEqual(legacy.userAssignedName, "工作手机")
        let restricted = iosSnapshot(version: 16, name: "iPhone")
        XCTAssertNil(restricted.userAssignedName)
        XCTAssertEqual(restricted.deviceName, "iPhone")
        XCTAssertEqual(restricted.displayName, "iPhone")
        // A user is allowed to choose the literal name "iPhone"; never infer permission from text.
        let granted = iosSnapshot(version: 16, name: "iPhone", access: .grantedByApple)
        XCTAssertEqual(granted.userAssignedName, "iPhone")
        XCTAssertNil(iosSnapshot(version: 27, name: "工作手机").userAssignedName)
    }

    func testSimulatorDoesNotClaimAnAssignedName() {
        let result = AppleDevice.makeIOSSnapshot(
            identifier: "iPhone15,2", systemDeviceName: "Simulator", majorVersion: 15,
            simulator: true, nameAccess: .grantedByApple
        )
        XCTAssertTrue(result.isSimulator)
        XCTAssertNil(result.userAssignedName)
        XCTAssertEqual(result.displayModel, "iPhone 14 Pro")
    }

    func testMissingNameAndUnknownModelFallback() {
        let snapshot = AppleDevice.makeIOSSnapshot(
            identifier: "iPhone999,1", systemDeviceName: " \n ", majorVersion: 27,
            simulator: false, nameAccess: .unavailable
        )
        XCTAssertNil(snapshot.deviceName)
        XCTAssertNil(snapshot.modelName)
        XCTAssertEqual(snapshot.displayName, "iPhone999,1")
        XCTAssertEqual(iosSnapshot(version: 16, name: nil).displayName, "iPhone 14 Pro")
    }

    func testJSONIncludesNullsAndUnicodeRoundTrips() throws {
        let missing = iosSnapshot(version: 16, name: nil)
        let json = try JSONEncoder().encode(missing)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: json) as? [String: Any])
        XCTAssertTrue(object["deviceName"] is NSNull)
        XCTAssertTrue(object["userAssignedName"] is NSNull)
        XCTAssertEqual(object["displayModel"] as? String, "iPhone 14 Pro")
        XCTAssertEqual(try JSONDecoder().decode(DeviceSnapshot.self, from: json), missing)

        let unicode = iosSnapshot(version: 15, name: "我的 \"iPhone\" 🐱\n备用")
        let encoded = try JSONEncoder().encode(unicode)
        XCTAssertEqual(try JSONDecoder().decode(DeviceSnapshot.self, from: encoded), unicode)
    }

    #if os(macOS)
    func testCurrentMacIdentity() {
        let snapshot = AppleDevice.current()
        XCTAssertFalse(snapshot.modelIdentifier.isEmpty)
        XCTAssertNotEqual(snapshot.modelIdentifier, "unknown")
        XCTAssertFalse(snapshot.isSimulator)
        XCTAssertEqual(snapshot.deviceName, snapshot.userAssignedName)
    }
    #endif

    private func iosSnapshot(
        version: Int,
        name: String?,
        access: IOSDeviceNameAccess = .unavailable
    ) -> DeviceSnapshot {
        AppleDevice.makeIOSSnapshot(
            identifier: "iPhone15,2", systemDeviceName: name, majorVersion: version,
            simulator: false, nameAccess: access
        )
    }
}
