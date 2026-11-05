import Foundation

public struct AdviceItem: Identifiable, Equatable, Sendable {
    public enum Tone: Equatable, Sendable {
        case good
        case info
        case warn
    }

    public var tone: Tone
    /// SF Symbols 名称。
    public var symbol: String
    public var text: String
    /// 窗口别处已经说了的（顶上的状态、健康和温度那一排），或者只是旧事。不放进提醒，免得一句话说两遍。
    public var quiet: Bool
    public var id: String { text }

    public init(_ tone: Tone, _ symbol: String, _ text: String, quiet: Bool = false) {
        self.tone = tone
        self.symbol = symbol
        self.text = text
        self.quiet = quiet
    }
}

/// 窗口顶上那一排小读数：健康、循环、温度。鼠标停上去有一句话。
public struct BatteryStat: Identifiable, Equatable, Sendable {
    public enum Kind: String, Sendable {
        case health
        case cycles
        case temperature
    }

    public var kind: Kind
    public var symbol: String
    public var value: String
    public var help: String
    /// 要留意：健康低于 80%、循环用掉八成、温度到了过热保护的门槛。
    public var warn: Bool
    public var id: String { kind.rawValue }

    public init(_ kind: Kind, _ symbol: String, _ value: String, help: String, warn: Bool) {
        self.kind = kind
        self.symbol = symbol
        self.value = value
        self.help = help
        self.warn = warn
    }
}

/// 短句只从读数里来，不猜。每句尽量不超过一行。
public enum Advice {
    public static func items(battery: BatterySnapshot, memory: MemorySnapshot, limit: Int?, heatActive: Bool,
                             discharging: Bool = false) -> [AdviceItem] {
        guard battery.present else {
            return [AdviceItem(.info, "powerplug", T("没有内置电池。"), quiet: true)]
        }
        var items: [AdviceItem] = []
        let flow = battery.flow

        // 窗口顶上那句「现在在做什么」已经会说偏热，这里只留给完整列表。
        if heatActive {
            items.append(AdviceItem(.warn, "thermometer.high", T("电池偏热，先停在 80%。"), quiet: true))
        }

        if let percent = battery.percent, let limit {
            if discharging {
                items.append(AdviceItem(.info, "arrow.down.circle", T("放电中，放到 %@% 停。", ["\(limit)"]), quiet: true))
            } else if battery.externalConnected && percent > limit + 2 {
                items.append(AdviceItem(.info, "arrow.down.right", T("高于上限 %@%，只停充，不放电。", ["\(limit)"])))
            } else if flow == .plugged && percent >= limit - 1 {
                items.append(AdviceItem(.good, "checkmark.circle", T("停在上限，电源直接供电。")))
            }
        }

        if let watts = battery.adapterWatts, battery.externalConnected {
            if flow == .discharging && !discharging {
                items.append(AdviceItem(.warn, "bolt.trianglebadge.exclamationmark", T("充电器 %@ W 跟不上耗电。", ["\(watts)"])))
            } else if watts < 30 && flow == .charging {
                items.append(AdviceItem(.info, "tortoise", T("充电器 %@ W，充得慢。", ["\(watts)"])))
            }
        }

        // 偏热的时候上面已经有一句「电池偏热，先停在 80%」，这里不再说「正常」，免得两句打架。
        // 「偏高」和过热保护用同一个温度（ChargePolicy.heatOn），不能一边说偏高、一边说正常。
        // 温度、健康、循环在顶上那一排小读数里有，偏高时那一格会变橙色，所以这几句都不当提醒。
        // 只有「偏冷，充得慢」要额外说一句：它解释了为什么充得慢。
        if let celsius = battery.celsius, !heatActive {
            let text = Self.celsiusText(celsius)
            if celsius >= ChargePolicy.heatOn {
                items.append(AdviceItem(.warn, "thermometer.high", T("电池 %@，偏高。", ["\(text)"]), quiet: true))
            } else if celsius >= 10 {
                items.append(AdviceItem(.good, "thermometer.medium", T("电池 %@，正常。", ["\(text)"])))
            } else {
                items.append(AdviceItem(.info, "thermometer.low", T("电池 %@，偏冷，充得慢。", ["\(text)"])))
            }
        }
        // 这是电池记下来的累计时长，发生过一次就一直在，不是现在的事。
        if battery.thermallyLimited {
            items.append(AdviceItem(.info, "thermometer.sun", T("曾因过热放慢充电。"), quiet: true))
        }

        if let health = battery.health {
            if health < 80 {
                items.append(AdviceItem(.warn, "heart", T("健康约 %@%，可考虑换电池。", ["\(health)"]), quiet: true))
            } else {
                items.append(AdviceItem(.good, "heart", T("健康约 %@%（估算）。", ["\(health)"])))
            }
        }
        if let cycles = battery.cycles, let design = battery.designCycles, design > 0, Self.cyclesMostlyUsed(cycles, design) {
            items.append(AdviceItem(.warn, "arrow.triangle.2.circlepath", T("循环 %@ / %@ 次，已用掉大半。", ["\(cycles)", "\(design)"]), quiet: true))
        }

        if memory.pressure >= 4 && flow == .discharging {
            items.append(AdviceItem(.warn, "memorychip", T("放电中，内存也紧。关掉不用的软件。")))
        } else if memory.pressure >= 4 {
            items.append(AdviceItem(.info, "memorychip", T("内存压力高。"), quiet: true))
        }
        return items
    }

    /// 主窗口里的提醒：只放要你留意、窗口别处又没说的，最多两条，警告在前。
    public static func notices(battery: BatterySnapshot, memory: MemorySnapshot, limit: Int?, heatActive: Bool,
                               discharging: Bool = false, count: Int = 2) -> [AdviceItem] {
        let all = items(battery: battery, memory: memory, limit: limit, heatActive: heatActive, discharging: discharging)
        return top(all.filter { !$0.quiet && $0.tone != .good }, count: count)
    }

    /// 顶上那一排：健康、循环、温度。读不到的那一格就不放。
    public static func stats(_ battery: BatterySnapshot) -> [BatteryStat] {
        guard battery.present else { return [] }
        var stats: [BatteryStat] = []
        if let health = battery.health {
            let low = health < 80
            stats.append(BatteryStat(.health, "heart.fill", "\(health)%",
                                     help: low ? T("健康约 %@%，可考虑换电池。", ["\(health)"]) : T("健康约 %@%（估算）。", ["\(health)"]),
                                     warn: low))
        }
        if let cycles = battery.cycles {
            if let design = battery.designCycles, design > 0 {
                let used = cyclesMostlyUsed(cycles, design)
                stats.append(BatteryStat(.cycles, "arrow.triangle.2.circlepath", "\(cycles)",
                                         help: used ? T("循环 %@ / %@ 次，已用掉大半。", ["\(cycles)", "\(design)"])
                                                    : T("循环 %@ / %@", ["\(cycles)", "\(design)"]),
                                         warn: used))
            } else {
                stats.append(BatteryStat(.cycles, "arrow.triangle.2.circlepath", "\(cycles)",
                                         help: T("循环 %@", ["\(cycles)"]), warn: false))
            }
        }
        if let celsius = battery.celsius {
            let text = celsiusText(celsius)
            let hot = celsius >= ChargePolicy.heatOn
            let help: String
            if hot {
                help = T("电池 %@，偏高。", ["\(text)"])
            } else if celsius >= 10 {
                help = T("电池 %@，正常。", ["\(text)"])
            } else {
                help = T("电池 %@，偏冷，充得慢。", ["\(text)"])
            }
            stats.append(BatteryStat(.temperature, hot ? "thermometer.high" : "thermometer.medium", text, help: help, warn: hot))
        }
        return stats
    }

    /// 循环用掉八成以上。
    static func cyclesMostlyUsed(_ cycles: Int, _ design: Int) -> Bool { cycles * 10 >= design * 8 }

    static func celsiusText(_ celsius: Double) -> String { String(format: "%.1f°C", celsius) }

    /// 窗口里最多放几条：先警告，再提示，最后正常。同一类保持原来的顺序。
    public static func top(_ items: [AdviceItem], count: Int = 3) -> [AdviceItem] {
        func rank(_ tone: AdviceItem.Tone) -> Int {
            switch tone {
            case .warn: return 0
            case .info: return 1
            case .good: return 2
            }
        }
        let sorted = items.enumerated().sorted { lhs, rhs in
            let l = rank(lhs.element.tone)
            let r = rank(rhs.element.tone)
            return l != r ? l < r : lhs.offset < rhs.offset
        }
        return sorted.prefix(count).map(\.element)
    }
}
