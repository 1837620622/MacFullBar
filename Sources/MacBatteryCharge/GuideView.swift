import SwiftUI
import BatteryCore

/// 第一次打开时的引导，共五页：是什么、怎么运行、怎么设置、怎么学习、其他。可以翻页，也能跳过；设置里能再看一次。
/// 每页上面一个图标，接着标题和一段话，整块放在中间，不在底下留一大片空白。
/// 「怎么设置」那一页直接放上两个数字，「怎么学习」那一页问一句平时几点拔电源，不靠猜。
struct GuideView: View {
    @ObservedObject var model: AppModel
    @State private var page = 0

    private var lastPage: Int { GuideCopy.titles.count - 1 }

    /// 每一页的图标，和标题一一对应。
    private static let symbols = ["battery.75", "menubar.rectangle", "slider.horizontal.3", "clock.arrow.circlepath", "sparkles"]

    var body: some View {
        VStack(spacing: 0) {
            topBar
            // 放得下就放在偏上一点的中间（上面一份空、下面两份空，看起来才是正中）；字放大了、或者英文太长放不下，才滚动。
            ViewThatFits(in: .vertical) {
                VStack(spacing: 0) {
                    Spacer(minLength: 16)
                    pageContent
                    Spacer(minLength: 8)
                    Spacer(minLength: 8)
                }
                ScrollView {
                    pageContent
                        .padding(.vertical, 16)
                }
                .scrollIndicators(.hidden)
            }
            .frame(maxHeight: .infinity)
            footer
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var topBar: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(T("欢迎使用%@", ["\(AppInfo.name)"]))
                .font(.headline)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            if page < lastPage {
                Button(T("跳过")) { model.finishGuide() }
                    .buttonStyle(.link)
                    .controlSize(.small)
            }
        }
    }

    private var pageContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            hero
                .padding(.bottom, 4)
            Text(GuideCopy.titles[page])
                .font(.title2.weight(.semibold))
            Text(GuideCopy.bodies[page])
                .font(.body)
                .foregroundStyle(.secondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
            if page == 0 {
                Label(GuideCopy.intro, systemImage: "lock.open")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            pageExtra
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 页面的图标。第一页用主窗口里那只会动的电池，停在 80%，一眼就知道它管什么；
    /// 其余几页是圆角方块里一个白色符号，底色是强调色的渐变。
    @ViewBuilder private var hero: some View {
        if page == 0 {
            ZStack {
                LiquidDisc(level: 0.8, limit: 80, tint: .accentColor, flow: .plugged, live: model.liveMotion)
                    .frame(width: 104, height: 104)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.primary.opacity(0.12), lineWidth: 1))
                Text("80%")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.18), radius: 1, y: 0.5)
            }
            .accessibilityHidden(true)
        } else {
            symbolHero
        }
    }

    private var symbolHero: some View {
        Image(systemName: Self.symbols[min(page, Self.symbols.count - 1)])
            .font(.system(size: 28, weight: .medium))
            .foregroundStyle(.white)
            .frame(width: 60, height: 60)
            .background(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(LinearGradient(colors: [Color.accentColor, Color.accentColor.opacity(0.7)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
            )
            .shadow(color: Color.accentColor.opacity(0.25), radius: 8, y: 3)
            .accessibilityHidden(true)
    }

    /// 这一页要的额外内容：「怎么设置」放上两个数字，「怎么学习」问一句平时几点拔电源。放在一块浅底上，和说明分开。
    @ViewBuilder private var pageExtra: some View {
        switch page {
        case 2:
            VStack(alignment: .leading, spacing: 10) {
                Text(T("平时停在多少"))
                    .font(.callout.weight(.semibold))
                LimitPicker(presets: SmartPolicy.dailyCapChoices, range: SmartPolicy.dailyCapRange,
                            value: $model.settings.smartDailyCap)
                Text(T("拔电源时要多少"))
                    .font(.callout.weight(.semibold))
                    .padding(.top, 4)
                LimitPicker(presets: ChargePlanner.targetChoices, range: ChargePlanner.targetRange,
                            value: $model.settings.unplugTarget)
                Text(T("随时可以在主窗口里改。"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.primary.opacity(0.05)))
        case 3:
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    Text(T("你平时大约几点拔电源？"))
                        .font(.callout.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    DatePicker("", selection: ClockPicker.binding($model.settings.deadline),
                               displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                        .fixedSize()
                        .environment(\.locale, ClockPicker.locale)
                }
                Text(T("随便填一个就行，之后会自己学。"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.primary.opacity(0.05)))
        default:
            EmptyView()
        }
    }

    /// 底下一行：左边上一页，右边下一页，中间是页码点。
    private var footer: some View {
        ZStack {
            pageDots
            HStack {
                if page > 0 {
                    Button(T("上一页")) { page -= 1 }
                        .controlSize(.large)
                }
                Spacer(minLength: 0)
                if page < lastPage {
                    Button(T("下一页")) { page += 1 }
                        .keyboardShortcut(.defaultAction)
                        .controlSize(.large)
                } else {
                    Button(T("开始使用")) { model.finishGuide() }
                        .keyboardShortcut(.defaultAction)
                        .controlSize(.large)
                }
            }
        }
    }

    private var pageDots: some View {
        HStack(spacing: 6) {
            ForEach(0...lastPage, id: \.self) { index in
                Capsule()
                    .fill(index == page ? Color.accentColor : Color.primary.opacity(0.18))
                    .frame(width: index == page ? 16 : 7, height: 7)
            }
        }
        .animation(Motion.quick, value: page)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(T("第 %@ 页，共 %@ 页", ["\(page + 1)", "\(lastPage + 1)"]))
    }
}
