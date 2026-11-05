import SwiftUI
import BatteryCore

/// 电量曲线：过去 16 小时的实线，接上「现在」之后 8 小时的虚线预测。
/// 实线是这台机器记下来的读数；虚线按时间表和充电速度推算，只是估计，底下有一句话说清楚。
struct ChargeCurve: View {
    /// 过去 16 小时的读数，按时间排好。
    var samples: [ChargeSample]
    /// 从现在起的预测。第一个点就是现在的电量。
    var forecast: [ForecastPoint]
    var now: Date
    /// 页面内容放得下时为 true：曲线占满剩下的高度，最低 96。放不下时固定 96。
    var fills = false

    static let pastMinutes = 16 * 60
    static let futureMinutes = 8 * 60
    /// 两次读数隔得超过这么久，就断开线，不把没记录的那段连起来。
    static let gapMinutes = 20.0
    /// 底下留给时间标签的高度。
    private static let labelHeight: CGFloat = 16

    var body: some View {
        Card {
            Text(T("电量曲线"))
                .font(.headline)
            Canvas { context, size in
                draw(in: &context, size: size)
            }
            .frame(minHeight: 96, maxHeight: fills ? .infinity : 96)
            .accessibilityElement()
            .accessibilityLabel(T("过去 16 小时的电量，和之后 8 小时的预测"))
            Text(T("实线是记下来的读数，虚线是按时间表和充电速度推算的，只是估计。"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func draw(in context: inout GraphicsContext, size: CGSize) {
        let total = Double(Self.pastMinutes + Self.futureMinutes)
        let plotHeight = size.height - Self.labelHeight
        // 横轴：从 16 小时前到 8 小时后，「现在」在三分之二的地方。纵轴：0 到 100%。
        func x(_ minutes: Double) -> CGFloat { CGFloat((minutes + Double(Self.pastMinutes)) / total) * size.width }
        func y(_ percent: Double) -> CGFloat { plotHeight * (1 - CGFloat(min(100, max(0, percent)) / 100)) }

        for level in [0.0, 50.0, 100.0] {
            var line = Path()
            line.move(to: CGPoint(x: 0, y: y(level)))
            line.addLine(to: CGPoint(x: size.width, y: y(level)))
            context.stroke(line, with: .color(.primary.opacity(0.08)), lineWidth: 1)
        }
        // 刻度写在线的右端下面：100% 那条线常被预测的虚线压着，写在下面不打架。
        Self.caption("100%", in: &context, at: CGPoint(x: size.width, y: y(100) + 2), anchor: .topTrailing, faint: true)
        Self.caption("50%", in: &context, at: CGPoint(x: size.width, y: y(50) + 2), anchor: .topTrailing, faint: true)

        var nowLine = Path()
        nowLine.move(to: CGPoint(x: x(0), y: 0))
        nowLine.addLine(to: CGPoint(x: x(0), y: plotHeight))
        context.stroke(nowLine, with: .color(.secondary.opacity(0.6)), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))

        // 记下来的读数：按时间连成几段（中间断了 20 分钟以上就断开），每段下面铺一层渐淡的底色。
        var segments: [[CGPoint]] = []
        var last: Date?
        for sample in samples {
            let point = CGPoint(x: x(sample.t.timeIntervalSince(now) / 60), y: y(Double(sample.p)))
            if let last, sample.t.timeIntervalSince(last) / 60 <= Self.gapMinutes, !segments.isEmpty {
                segments[segments.count - 1].append(point)
            } else {
                segments.append([point])
            }
            last = sample.t
        }
        let fade = Gradient(colors: [Color.accentColor.opacity(0.18), Color.accentColor.opacity(0)])
        var past = Path()
        for points in segments {
            guard let first = points.first, let end = points.last else { continue }
            past.move(to: first)
            points.dropFirst().forEach { past.addLine(to: $0) }
            guard points.count > 1 else { continue }
            var area = Path()
            area.move(to: CGPoint(x: first.x, y: plotHeight))
            points.forEach { area.addLine(to: $0) }
            area.addLine(to: CGPoint(x: end.x, y: plotHeight))
            area.closeSubpath()
            context.fill(area, with: .linearGradient(fade, startPoint: CGPoint(x: 0, y: y(100)), endPoint: CGPoint(x: 0, y: plotHeight)))
        }
        context.stroke(past, with: .color(.accentColor), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

        var future = Path()
        for (index, point) in forecast.enumerated() {
            let place = CGPoint(x: x(Double(point.minutesAhead)), y: y(point.percent))
            if index == 0 { future.move(to: place) } else { future.addLine(to: place) }
        }
        context.stroke(future, with: .color(.accentColor.opacity(0.7)),
                       style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round, dash: [4, 4]))

        // 「现在」的圆点：预测的第一个点就是现在；没有预测时用最后一个读数。
        if let percent = forecast.first?.percent ?? samples.last.map({ Double($0.p) }) {
            let dot = CGRect(x: x(0) - 3.5, y: y(percent) - 3.5, width: 7, height: 7)
            context.fill(Path(ellipseIn: dot), with: .color(.accentColor))
        }

        Self.caption(T("16 小时前"), in: &context, at: CGPoint(x: 0, y: size.height), anchor: .bottomLeading)
        Self.caption(T("现在"), in: &context, at: CGPoint(x: x(0), y: size.height), anchor: .bottom)
        Self.caption(T("之后 8 小时"), in: &context, at: CGPoint(x: size.width, y: size.height), anchor: .bottomTrailing)
    }

    /// 时间标签：小字，灰色。`Text.foregroundStyle` 只有 macOS 14 才有，我们最低支持 13，
    /// 所以先 resolve 成 ResolvedText，再把颜色设在上面。
    private static func caption(_ words: String, in context: inout GraphicsContext, at point: CGPoint, anchor: UnitPoint,
                                faint: Bool = false) {
        var resolved = context.resolve(Text(words).font(.caption2).monospacedDigit())
        resolved.shading = .color(faint ? Color.secondary.opacity(0.7) : Color.secondary)
        context.draw(resolved, at: point, anchor: anchor)
    }
}
