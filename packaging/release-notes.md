# 充电上限 3.3.0

这一版把窗口里缺的东西补回来，修了几处细节，引导页也重做了。

## 变化

- **电池健康、循环次数和温度回到窗口顶上。** 一排小读数，哪一项该留意了会变成橙色，鼠标停上去有一句说明。
- **该提醒的会提醒。** 充电器跟不上、充得慢、电量比上限高只停充，窗口里会多一行说明原因。系统在这台 Mac 上设不了充电上限、又没装放电帮手时，也会直说，并给一个安装按钮。
- **「质感」真的生效了。** 纯色、磨砂、玻璃以前看起来一样，现在卡片会跟着变，macOS 26 上用系统的玻璃。
- **一直充满模式更干净。** 不再借用别的模式的拔电源时间，只在工作日停电的日子显示今晚的计划。
- **说清楚为什么。** 固定时间表和一直充满模式在过热、临时充满、提前补电时，顶上那句话会写明原因；停电的日子说「停电」。
- **曲线和引导页。** 曲线下面加了浅色底和刻度，不会再画过「现在」；引导页每页一个图标，第一页是会动的电池。
- **繁體中文用词修正。** 「循環」「進階」「選單列」「回報問題」。

## 升级

直接覆盖安装即可，设置保留。放电帮手跟着 App 版本走，升级到 3.3.0 后要在「设置 → 高级」里重新装一次；装好之前充电上限照样生效，放电和低电量模式要等装好才会用。PKG 会自己换掉它。

---

## 繁體中文

Charge Limit 3.3.0 把視窗裡缺的東西補回來，修了幾處細節，引導頁也重做了。

## 變化

- **電池健康度、循環次數和溫度回到視窗頂端。** 一排小讀數，哪一項該留意了會變成橘色，滑鼠停上去有一句說明。
- **該提醒的會提醒。** 充電器跟不上、充得慢、電量比上限高只停充，視窗裡會多一行說明原因。系統在這台 Mac 上設不了充電上限、又沒裝放電幫手時，也會直說，並給一個安裝按鈕。
- **「質感」真的生效了。** 純色、磨砂、玻璃以前看起來一樣，現在卡片會跟著變，macOS 26 上用系統的玻璃。
- **一直充滿模式更乾淨。** 不再借用別的模式的拔電源時間，只在工作日停電的日子顯示今晚的計畫。
- **說清楚為什麼。** 固定時間表和一直充滿模式在過熱、臨時充滿、提前補電時，頂端那句話會寫明原因；停電的日子說「停電」。
- **曲線和引導頁。** 曲線下面加了淺色底和刻度，不會再畫過「現在」；引導頁每頁一個圖示，第一頁是會動的電池。
- **繁體中文用詞修正。** 「循環」「進階」「選單列」「回報問題」。

## 升級

直接覆蓋安裝即可，設定保留。放電幫手跟著 App 版本走，升級到 3.3.0 後要在「設定 → 進階」裡重新裝一次；裝好之前充電上限照樣生效，放電和低電量模式要等裝好才會用。PKG 會自己換掉它。

---

## English

Charge Limit 3.3.0 brings back what was missing from the window, fixes a handful of details, and redoes the welcome guide.

## Changes

- **Battery health, cycle count and temperature are back at the top of the window.** A small row of readings; any of them turns orange when it's worth a look, and hovering shows a short explanation.
- **It tells you when something's off.** A weak charger, slow charging, or a battery above the limit that's only paused rather than drained now gets a line in the window explaining why. If macOS can't set a charge limit on your Mac and the discharge helper isn't installed, the window says so and offers to install it.
- **"Finish" actually does something now.** Solid, Frosted and Glass used to look the same. The cards now follow the setting, with the system glass on macOS 26.
- **Always full is simpler.** It no longer borrows the unplug time from the other modes; tonight's plan only shows on weekday power-cut days.
- **It says why.** In Fixed schedule and Always full, when heat protection, Top up or an early top-up changes the limit, the line at the top says so. On power-cut days it talks about the power cut, not unplugging.
- **Chart and guide.** The chart has a soft fill and 100% / 50% marks and no longer runs past "Now". The welcome guide has an icon on every page, starting with the animated battery.

## Upgrading

Install over the existing app and your settings are kept. The discharge helper is tied to the app version, so after upgrading to 3.3.0, reinstall it in Settings → Advanced. The charge limit keeps working until then; discharging and Low Power Mode need the reinstalled helper. The PKG replaces it automatically.
