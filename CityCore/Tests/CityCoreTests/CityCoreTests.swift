import XCTest
@testable import CityCore

final class CityCoreTests: XCTestCase {
    func testVersionIsSet() {
        XCTAssertEqual(CityCoreInfo.version, "1.0.0")
    }
}
