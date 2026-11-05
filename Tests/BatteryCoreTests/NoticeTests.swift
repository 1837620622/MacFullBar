import XCTest
@testable import BatteryCore

/// 主窗口的提醒和顶上那一排小读数：只说要留意、别处又没说的；正常的读数放在小读数里。
final class NoticeTests: XCTestCase {
    override func setUp() {
        super.setUp()
        pinChineseUI()
    }

    private func pluggedBattery() -> BatterySnapshot {
        var battery = BatterySnapshot()
        battery.present = true
        battery.percent = 80
        battery.externalConnected = true
        battery.milliamps = 0
        battery.temperatureRaw = 3000
        battery.designCapacity = 6000
        battery.nominalCapacity = 5500
        battery.cycles = 200
        battery.designCycles = 1000
        return battery
    }

    /// 一切正常时没有提醒：温度、健康放在小读数里，停在上限顶上已经写了。
    func testQuietWhenEverythingIsFine() {
        let notices = Advice.notices(battery: pluggedBattery(), memory: MemorySnapshot(), limit: 80, heatActive: false)
        XCTAssertTrue(notices.isEmpty, "\(notices.map(\.text))")
    }

    /// 充电器跟不上：这是要你做点什么的，要提醒。
    func testWeakChargerIsANotice() {
        var battery = pluggedBattery()
        battery.milliamps = -600
        battery.adapterWatts = 30
        let notices = Advice.notices(battery: battery, memory: MemorySnapshot(), limit: 80, heatActive: false)
        XCTAssertEqual(notices.first?.tone, .warn)
        XCTAssertTrue(notices.first?.text.contains("30 W") == true)
    }

    /// 高于上限、只停充：解释为什么电量比上限高，要说。
    func testAboveLimitExplainsItself() {
        var battery = pluggedBattery()
        battery.percent = 95
        let notices = Advice.notices(battery: battery, memory: MemorySnapshot(), limit: 80, heatActive: false)
        XCTAssertTrue(notices.contains { $0.text.contains("只停充") })
    }

    /// 偏热、健康低、循环用得多：小读数会变橙色，顶上也会说过热，提醒里不再重复。
    func testReadingsShownElsewhereStayOutOfNotices() {
        var battery = pluggedBattery()
        battery.temperatureRaw = 3700
        battery.nominalCapacity = 4500
        battery.cycles = 900
        for heat in [false, true] {
            let notices = Advice.notices(battery: battery, memory: MemorySnapshot(), limit: 80, heatActive: heat)
            XCTAssertFalse(notices.contains { $0.text.contains("偏热") || $0.text.contains("偏高") }, "heat \(heat)")
            XCTAssertFalse(notices.contains { $0.text.contains("健康") })
            XCTAssertFalse(notices.contains { $0.text.contains("循环") })
        }
    }

    /// 最多两条，警告在前。
    func testAtMostTwoWarningsFirst() {
        var battery = pluggedBattery()
        battery.percent = 95
        battery.milliamps = -600
        battery.adapterWatts = 30
        battery.temperatureRaw = 800
        let tight = MemorySnapshot(totalBytes: 8 << 30, pageSize: 4096, free: 10, active: 100_000, inactive: 10,
                                   wired: 100_000, compressed: 50_000, speculative: 0, pressure: 4)
        let notices = Advice.notices(battery: battery, memory: tight, limit: 80, heatActive: false)
        XCTAssertEqual(notices.count, 2)
        XCTAssertEqual(notices.first?.tone, .warn)
    }

    /// 小读数：三格都在，正常时不标橙色。
    func testStatsWhenHealthy() {
        let stats = Advice.stats(pluggedBattery())
        XCTAssertEqual(stats.map(\.kind), [.health, .cycles, .temperature])
        XCTAssertEqual(stats.map(\.value), ["92%", "200", "30.0°C"])
        XCTAssertFalse(stats.contains { $0.warn })
        XCTAssertTrue(stats[0].help.contains("估算"), "健康度是系统估算的，要说清楚")
    }

    /// 健康低于 80%、循环用掉八成、温度到 35°C：那一格标橙色，说明里说为什么。
    func testStatsWarn() {
        var battery = pluggedBattery()
        battery.nominalCapacity = 4500
        battery.cycles = 850
        battery.temperatureRaw = 3600
        let stats = Advice.stats(battery)
        XCTAssertTrue(stats.allSatisfy(\.warn))
        XCTAssertTrue(stats[0].help.contains("换电池"))
        XCTAssertTrue(stats[1].help.contains("大半"))
        XCTAssertTrue(stats[2].help.contains("偏高"))
    }

    /// 读不到的那一格就不放；没有电池时一格都没有。
    func testStatsSkipWhatIsMissing() {
        var battery = BatterySnapshot()
        battery.present = true
        battery.cycles = 12
        let stats = Advice.stats(battery)
        XCTAssertEqual(stats.map(\.kind), [.cycles])
        XCTAssertEqual(stats.first?.help, "循环 12")
        XCTAssertTrue(Advice.stats(BatterySnapshot()).isEmpty)
    }
}

/// 上限被临时改动时，三种模式顶上那一句说法一样；停电的日子说「停电」，不说「拔电源」。
final class ExplainOverrideTests: XCTestCase {
    override func setUp() {
        super.setUp()
        pinChineseUI()
    }

    func testOverrides() {
        let at = ClockTime(hour: 23, minute: 30)
        XCTAssertEqual(ChargePolicy.explainOverride(LimitDecision(limit: 80, reason: .heat, scheduled: 100), deadline: at, outage: false),
                       "电池偏热，先停在 80%")
        XCTAssertEqual(ChargePolicy.explainOverride(LimitDecision(limit: 100, reason: .topUp, scheduled: 80), deadline: nil, outage: false),
                       "临时充满到 100%")
        XCTAssertEqual(ChargePolicy.explainOverride(LimitDecision(limit: 100, reason: .deadline, scheduled: 80), deadline: at, outage: false),
                       "为 23:30 拔电源做准备，补到 100%")
        XCTAssertEqual(ChargePolicy.explainOverride(LimitDecision(limit: 100, reason: .deadline, scheduled: 80), deadline: at, outage: true),
                       "为 23:30 停电做准备，补到 100%")
    }

    /// 平常的情况由各模式自己说，这里不管。
    func testOrdinaryReasonsAreLeftToTheMode() {
        for reason in [LimitReason.schedule, .gap, .smart, .full] {
            XCTAssertNil(ChargePolicy.explainOverride(LimitDecision(limit: 80, reason: reason, scheduled: 80), deadline: nil, outage: false))
        }
    }

    /// 智能模式在停电的日子里提前补电，也说「停电」。
    func testSmartSaysPowerCutOnOutageDays() {
        let decision = SmartPolicy.decide(SmartInput(percent: 80, external: true, minute: 23 * 60, dailyCap: 80, unplugTarget: 100,
                                                     deadline: ClockTime(hour: 23, minute: 30)))
        XCTAssertEqual(decision.decision.reason, .deadline)
        XCTAssertEqual(SmartPolicy.explain(decision, target: 100, outage: true), "为 23:30 停电做准备，补到 100%")
        XCTAssertEqual(SmartPolicy.explain(decision, target: 100), "为 23:30 拔电源做准备，补到 100%")
    }
}
