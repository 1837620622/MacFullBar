import XCTest
@testable import BatteryCore

/// 装完新版本、自己重新打开以后，只在真的升级时说一句「已经更新到」。
final class JustUpdatedTests: XCTestCase {
    func testUpgradeIsNoticed() {
        XCTAssertTrue(AppVersion.justUpdated(from: "3.3.0", to: "3.3.1", usedBefore: true))
        XCTAssertTrue(AppVersion.justUpdated(from: "3.2.7", to: "3.3.0", usedBefore: false))
    }

    /// 同一版本重开、降级，都不算更新。
    func testSameOrOlderIsNotAnUpdate() {
        XCTAssertFalse(AppVersion.justUpdated(from: "3.3.1", to: "3.3.1", usedBefore: true))
        XCTAssertFalse(AppVersion.justUpdated(from: "3.4.0", to: "3.3.1", usedBefore: true))
    }

    /// 以前的版本没记过上次的版本号：看过引导说明是老用户，算升级；新装的不算。
    func testNoRecordFallsBackToGuide() {
        XCTAssertTrue(AppVersion.justUpdated(from: nil, to: "3.3.1", usedBefore: true))
        XCTAssertFalse(AppVersion.justUpdated(from: nil, to: "3.3.1", usedBefore: false))
        XCTAssertFalse(AppVersion.justUpdated(from: nil, to: "not a version", usedBefore: true))
    }
}
