import XCTest
@testable import DevCam

@MainActor
final class PermissionManagerTests: XCTestCase {

    func testPermissionManagerCanBeInstantiated() {
        let manager = PermissionManager()
        XCTAssertNotNil(manager)
    }

    func testPermissionStatusReturnsValidState() {
        let manager = PermissionManager()
        let status = manager.screenRecordingPermissionStatus()

        // In test mode, should return "notDetermined"
        XCTAssertEqual(status, "notDetermined")
    }
}
