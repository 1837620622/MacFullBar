import AppKit
import SwiftUI
import BatteryCore

/// 主窗口：上面是现在的电量和正在做什么，中间是三种模式，下面是临时充满。
/// 其它设置收进右上角的齿轮。
struct RootView: View {
    /// 弹窗里的页面：主页，或者设置。第一次的引导由 model.showGuide 决定，盖在最上面。
    enum Page { case main, settings }

    /// 弹窗的高度固定；宽度跟着屏幕走，见 popoverSize(for:)。
    static let popoverHeight: CGFloat = 680
    /// 宽度的范围。下限是设置页的标准宽度，两排带标题的时间选择器要这么宽；上限是屏幕再宽，弹窗也不该大得不像菜单栏的弹窗。
    static let popoverWidths: ClosedRange<CGFloat> = 400...520

    /// 弹窗的大小：宽度取图标所在屏幕可用宽度的三成，再夹进 popoverWidths。屏幕不知道的时候取下限。
    @MainActor
    static func popoverSize(for screen: NSScreen?) -> NSSize {
        let wanted = ((screen?.visibleFrame.width ?? 0) * 0.3).rounded()
        let width = min(max(wanted, popoverWidths.lowerBound), popoverWidths.upperBound)
        return NSSize(width: width, height: popoverHeight)
    }

    @ObservedObject var model: AppModel
    @State private var page: Page

    init(model: AppModel, page: Page = .main) {
        self.model = model
        _page = State(initialValue: page)
    }

    var body: some View {
        ZStack {
            WindowBackdrop(look: model.settings.look, transparency: model.settings.transparency)
            if model.showGuide {
                GuideView(model: model)
            } else if page == .settings {
                SettingsView(model: model) { switchPage(.main) }
                    .transition(.opacity)
            } else {
                mainPage
                    .transition(.opacity)
            }
        }
        // 卡片按质感画底：纯色、磨砂、玻璃（macOS 26 起是系统的玻璃）。
        .environment(\.windowLook, model.settings.look)
        .environment(\.isPreview, model.preview)
    }

    /// 主页和设置之间淡入淡出，不硬切。
    private func switchPage(_ next: Page) {
        withAnimation(Motion.quick) { page = next }
    }

    private var mainPage: some View {
        VStack(spacing: 0) {
            header
            // 内容放得下就不滚动，曲线占满剩下的高度；放不下才滚动，曲线保持原来的高度。
            ViewThatFits(in: .vertical) {
                pageBody(fillsHeight: true)
                ScrollView {
                    pageBody(fillsHeight: false)
                }
                .scrollIndicators(.hidden)
            }
            .frame(maxHeight: .infinity)
        }
    }

    private func pageBody(fillsHeight: Bool) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // 动画只跟着这一条提示走。放在整页上，别的结构变化（比如时间选择器）也会跟着动。
            Group {
                if let message = model.message {
                    MessageLine(message: message) { model.dismissMessage() }
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(Motion.standard, value: model.message)
            // 时间表有错要改好才会消失，所以这一行没有「关掉」。
            if let error = model.scheduleError {
                MessageLine(message: AppModel.Message(tone: .error, text: error.message))
            }
            // 这台的上限谁都管不了时直说，不能装作在护电池。
            if model.limitUnenforceable {
                MessageLine(message: AppModel.Message(tone: .error, text: T("这台 Mac 的充电上限现在没人能管：系统不让改，放电帮手也碰不了这一代固件。电池会照常充满。")))
            } else if model.limitNeedsHelper {
                MessageLine(message: AppModel.Message(tone: .error, text: T("这台 Mac 的系统不能设充电上限，现在电池会照常充满。装上放电帮手后，由它来停充。")),
                            action: model.helperInstallable ? (title: T("安装放电帮手"), run: { model.installHelper() }) : nil)
                    .disabled(model.helperBusy)
            }
            // 用 DMG 覆盖安装后帮手还是旧的：放电和低电量模式停了，要在这里说，不能只藏在设置里。
            if model.helperOutdated && model.helperInstallable {
                MessageLine(message: AppModel.Message(tone: .info, text: T("放电帮手是旧版本：放电和低电量模式要重新安装一次。充电上限不受影响。")),
                            action: (title: T("安装放电帮手"), run: { model.installHelper() }))
                    .disabled(model.helperBusy)
            }
            // 不在「应用程序」里跑的时候，登录时打开和装完新版本后自己重新打开都用不了。
            if model.offerMove {
                MessageLine(message: AppModel.Message(tone: .info, text: T("现在不是从「应用程序」里打开的。放进去以后，登录时才会自己打开。")),
                            action: (title: T("放进“应用程序”"), run: { model.moveToApplications() }))
                    .disabled(model.moving)
            }
            // 读数里要你留意的：充电器跟不上、充得慢、高于上限只停充。条件没了自己消失。
            ForEach(model.notices) { notice in
                MessageLine(message: AppModel.Message(tone: notice.tone == .warn ? .error : .info, text: notice.text),
                            symbol: notice.symbol)
            }
            UpdateBanner(model: model)
            tonightCard
                .animation(Motion.standard, value: model.tonight)
            curve(fillsHeight: fillsHeight)
            ChoiceBar(options: ChargeMode.allCases, title: { $0.title }, selection: modeBinding)
            Text(model.settings.mode.tagline)
                .font(.callout)
                .foregroundStyle(.secondary)
            modePanel
            // 一直充满本来就是 100%，临时充满没有用，也就不放这一行。
            if model.settings.mode != .full {
                footer
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 18)
        .frame(maxHeight: fillsHeight ? .infinity : nil, alignment: .top)
    }

    private static let discSize: CGFloat = 96

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                LiquidDisc(level: level, limit: model.decision.limit,
                           tint: ringColor, flow: model.displayFlow, live: model.liveMotion)
                    .frame(width: Self.discSize, height: Self.discSize)
                    .animation(.easeInOut(duration: 0.8), value: model.battery.percent)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.primary.opacity(0.12), lineWidth: 1))
                // 数字一半在水里一半在水外时，水里那半是白的，水外那半是正文色，两边都看得清。
                percentLabel
                    .foregroundStyle(.primary)
                percentLabel
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.18), radius: 1, y: 0.5)
                    .mask {
                        VStack(spacing: 0) {
                            Spacer(minLength: 0)
                            Rectangle().frame(height: Self.discSize * level)
                        }
                    }
                    .animation(.easeInOut(duration: 0.8), value: model.battery.percent)
            }
            .frame(width: Self.discSize, height: Self.discSize)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(diskLabel)
            VStack(alignment: .leading, spacing: 4) {
                Text(model.statusTitle)
                    .font(.title3.weight(.semibold))
                    .contentTransition(.opacity)
                Text(model.statusDetail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(model.modeDescription)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                statRow
                    .padding(.top, 4)
            }
            // 文字这一栏占满中间，不再用 Spacer：Spacer 两边各吃一份间距，右上角多了按钮以后，温度那一格会被挤成两行。
            .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 10) {
                // 重新打开、退出：以前只有右键菜单栏图标才找得到。
                Menu {
                    Button(T("重新打开充电上限")) { model.restartApp() }
                        .disabled(!model.canRestart)
                    Button(T("退出充电上限")) { model.quitApp() }
                } label: {
                    Image(systemName: "power")
                        .font(.system(size: 15, weight: .medium))
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .help(T("重新打开或退出"))
                Button {
                    switchPage(.settings)
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 15, weight: .medium))
                }
                .buttonStyle(.plain)
                .help(T("设置"))
            }
            .padding(.top, 2)
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 14)
    }

    private var level: Double { Double(model.battery.percent ?? 0) / 100 }

    private var percentLabel: some View {
        Text(percentText)
            .font(.system(size: 26, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .numericTextTransition()
            .frame(width: Self.discSize, height: Self.discSize)
    }

    /// 健康、循环、温度三个小读数。要留意的那一格变橙色，鼠标停上去有一句说明。
    private var statRow: some View {
        HStack(spacing: 6) {
            ForEach(model.batteryStats) { stat in
                HStack(spacing: 3) {
                    Image(systemName: stat.symbol)
                        .font(.caption2.weight(.semibold))
                    Text(stat.value)
                        .font(.caption.weight(.medium))
                        .monospacedDigit()
                        .lineLimit(1)
                }
                .fixedSize()
                .foregroundStyle(stat.warn ? Color.orange : Color.secondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Capsule().fill(stat.warn ? Color.orange.opacity(0.14) : Color.primary.opacity(0.06)))
                .help(stat.help)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(stat.help)
            }
        }
    }

    /// 电量曲线：过去 16 小时和之后 8 小时的预测。还没有读数时不占地方。
    /// 「现在」用最近一次读数的时间，和记下来的读数是同一个钟，实线不会画过「现在」那条线。
    @ViewBuilder private func curve(fillsHeight: Bool) -> some View {
        let now = model.now
        let samples = model.history.samples(since: now.addingTimeInterval(-TimeInterval(ChargeCurve.pastMinutes * 60)))
        if !samples.isEmpty {
            ChargeCurve(samples: samples, forecast: model.forecast, now: now, fills: fillsHeight)
        }
    }

    @ViewBuilder private var tonightCard: some View {
        if let tonight = model.tonight {
            let tint = tonightTint(tonight.tone)
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: tonight.symbol)
                    .font(.title2)
                    .foregroundStyle(tint)
                VStack(alignment: .leading, spacing: 3) {
                    Text(tonight.title)
                        .font(.headline)
                    Text(tonight.detail)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(tint.opacity(0.1)))
            .accessibilityElement(children: .combine)
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    private func tonightTint(_ tone: AppModel.Message.Tone) -> Color {
        switch tone {
        case .info: return .accentColor
        case .success: return .green
        case .error: return .orange
        }
    }

    @ViewBuilder private var modePanel: some View {
        Group {
            switch model.settings.mode {
            case .smart:
                SmartPanel(model: model)
            case .fixed:
                FixedPanel(model: model)
            case .full:
                FullPanel()
            }
        }
        .id(model.settings.mode)
        .transition(.opacity)
    }

    /// 临时充满旁边那句话：固定模式说「这一段」，智能说「拔掉电源」。
    private var topUpHint: String {
        let fixed = model.settings.mode == .fixed
        if model.topUpActive { return fixed ? T("到下一段或拔掉电源时结束") : T("拔掉电源时结束") }
        return fixed ? T("这一段先充到 100%，拔掉电源时结束") : T("先充到 100%，拔掉电源时结束")
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Button {
                model.toggleTopUp()
            } label: {
                Label(model.topUpActive ? T("结束临时充满") : T("临时充满"), systemImage: "bolt.fill")
            }
            .disabled(!model.topUpAvailable)
            Text(topUpHint)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(.top, 2)
    }

    private var modeBinding: Binding<ChargeMode> {
        Binding(get: { model.settings.mode }, set: { mode in
            withAnimation(Motion.standard) { model.settings.mode = mode }
        })
    }

    private var percentText: String {
        model.battery.percent.map { "\($0)%" } ?? "—"
    }

    /// 给 VoiceOver 读的一句：电量和现在的状态。
    private var diskLabel: String {
        model.battery.percent.map { T("电量 %@%，%@", ["\($0)", model.statusTitle]) } ?? model.statusTitle
    }

    private var ringColor: Color {
        switch model.displayFlow {
        case .charging: return .green
        case .discharging: return (model.battery.percent ?? 100) <= 20 ? .red : .orange
        default: return .accentColor
        }
    }
}

/// 一行提示：出错、写上限失败、时间表有问题都从这里说。
struct MessageLine: View {
    var message: AppModel.Message
    /// 不给就按语气选一个。
    var symbol: String? = nil
    /// 文字下面的一个按钮：标题和要做的事。
    var action: (title: String, run: () -> Void)? = nil
    /// 有「关掉」动作才显示 ×。
    var dismiss: (() -> Void)? = nil

    init(message: AppModel.Message, symbol: String? = nil, action: (title: String, run: () -> Void)? = nil,
         dismiss: (() -> Void)? = nil) {
        self.message = message
        self.symbol = symbol
        self.action = action
        self.dismiss = dismiss
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: symbol ?? toneSymbol)
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 6) {
                Text(message.text)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                if let action {
                    Button(action.title, action: action.run)
                        .controlSize(.small)
                }
            }
            Spacer(minLength: 0)
            if let dismiss {
                Button(action: dismiss) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(T("关掉这条提示"))
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(tint.opacity(0.12)))
    }

    private var toneSymbol: String {
        switch message.tone {
        case .info: return "info.circle.fill"
        case .success: return "checkmark.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        }
    }

    private var tint: Color {
        switch message.tone {
        case .info: return .accentColor
        case .success: return .green
        case .error: return .orange
        }
    }
}

/// 时间和 Date 互相转换，给 DatePicker 用。只用到小时和分钟。
enum ClockPicker {
    static func date(_ time: ClockTime) -> Date {
        var parts = DateComponents()
        parts.hour = time.hour
        parts.minute = time.minute
        return Calendar.current.date(from: parts) ?? Date()
    }

    static func clock(_ date: Date) -> ClockTime {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        return ClockTime(hour: parts.hour ?? 0, minute: parts.minute ?? 0)
    }

    static func binding(_ time: Binding<ClockTime>) -> Binding<Date> {
        Binding(get: { date(time.wrappedValue) }, set: { time.wrappedValue = clock($0) })
    }

    /// 时间选择器的语言跟着界面语言走，不跟着系统。系统是英文、界面是中文时，时间也不该显示成 AM/PM。
    static var locale: Locale {
        switch Lang.resolved {
        case .zh: return Locale(identifier: "zh_CN")
        case .zhHant: return Locale(identifier: "zh_TW")
        case .en, .auto: return Locale(identifier: "en_US")
        }
    }
}
