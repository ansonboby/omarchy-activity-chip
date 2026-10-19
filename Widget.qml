import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Telemetry readouts for GPU, CPU, Temperatures, and Memory in the Omarchy bar
// with rich per-item data selection, ordering, and formatting controls.
//
// Left click opens the Omarchy system panel popup (or runs clickCommand if set).
// Right click walks the display modes and remembers the choice; middle click resamples.
Panel {
  id: root
  moduleName: "anson.activity-monitor"
  ipcTarget: "anson.activity-monitor"
  manageIpc: false

  readonly property bool vertical: bar ? bar.vertical : false

  function broadcast(method) {
    var items = bar && typeof bar.moduleWidgets === "function"
      ? bar.moduleWidgets(moduleName) : [root]
    for (var i = 0; i < items.length; i++) {
      if (items[i] && typeof items[i][method] === "function") items[i][method]()
    }
  }

  // Four states, cycled by right click:
  //   icons    Sleek component glyphs + live figures (Noctalia-style readout, default)
  //   compact  glyphs + gauges
  //   full     glyphs + gauges + temperatures
  //   labels   Waybar-style text readout — GPU 0% · CPU 34% · TEMP 46°C · RAM 11/23G
  readonly property var modes: ["icons", "compact", "full", "labels"]
  readonly property string mode: {
    var want = String(setting("mode", "icons")).trim().toLowerCase()
    return modes.indexOf(want) === -1 ? "icons" : want
  }

  readonly property string nextMode: modes[(modes.indexOf(mode) + 1) % modes.length]
  readonly property bool labelled: mode === "labels" && !vertical
  readonly property bool showTemps: mode !== "compact" && !vertical
  readonly property bool showValues: (labelled || mode === "icons" || boolSetting("showValues", false)) && !vertical
  readonly property bool showGauges: boolSetting("showGauges", mode !== "icons" && mode !== "labels")

  readonly property var monitors: {
    var raw = setting("monitors", [])
    if (raw === undefined || raw === null) return []
    if (raw instanceof Array) return raw.map(String)
    var text = String(raw).trim()
    return text === "" ? [] : text.split(/[,\s]+/)
  }

  readonly property string screenName: {
    var window = root.QsWindow ? root.QsWindow.window : null
    return window && window.screen ? String(window.screen.name) : ""
  }

  readonly property bool onThisScreen: monitors.length === 0 || screenName === ""
    || monitors.indexOf(screenName) !== -1

  // -------------------------------------------------------- data selection

  readonly property bool showGpu: boolSetting("showGpu", true)
  readonly property bool showCpu: boolSetting("showCpu", true)
  readonly property bool showCpuTemp: boolSetting("showCpuTemp", true)
  readonly property bool showGpuTemp: boolSetting("showGpuTemp", false)
  readonly property bool showRam: boolSetting("showRam", true)
  readonly property bool showFan: boolSetting("showFan", true)

  readonly property var itemOrder: {
    // Load figures first; anything thermal or spinning goes on the right.
    // Matches manifest defaults; items without a live cell are skipped.
    var fallback = ["gpu", "gpu-temp", "cpu", "ram", "cpu-temp", "fan"]
    var raw = setting("itemsOrder", fallback)
    if (raw instanceof Array) return raw.map(function(s) { return String(s).trim().toLowerCase() })
    var text = String(raw || "").trim().toLowerCase()
    return text === "" ? fallback : text.split(/[,\s]+/)
  }

  // ------------------------------------------------------------ formatting

  readonly property bool fahrenheit: boolSetting("fahrenheit", false)
  readonly property string ramFormat: {
    var want = String(setting("ramFormat", "used/total")).trim().toLowerCase()
    return ["used/total", "used", "percent", "free", "available"].indexOf(want) === -1 ? "used/total" : want
  }

  readonly property string tempFormat: {
    var want = String(setting("tempFormat", "degree-unit")).trim().toLowerCase()
    return ["degree-unit", "degree", "unit", "unit-lower", "bare"].indexOf(want) === -1 ? "degree-unit" : want
  }

  readonly property string percentPad: {
    var want = String(setting("percentPad", mode === "icons" ? "none" : "zero")).trim().toLowerCase()
    if (want === "space") want = "trail"
    return ["lead", "zero", "trail", "none"].indexOf(want) === -1 ? (mode === "icons" ? "none" : "zero") : want
  }

  readonly property real padOpacity: {
    var n = Number(setting("padOpacity", 0.3))
    return isFinite(n) ? Math.max(0, Math.min(1, n)) : 0.3
  }

  readonly property int iconSizeSetting: intSetting("iconSize", 0, 0, 48)
  readonly property int iconSize: iconSizeSetting > 0 ? iconSizeSetting : Style.bar.iconFont
  readonly property int valueSize: Math.max(9, Math.round(iconSize * 0.92))

  readonly property int warnPercent: intSetting("warnPercent", 70, 1, 100)
  readonly property int criticalPercent: intSetting("criticalPercent", 90, 1, 100)
  readonly property int warnTempC: intSetting("warnTempC", 75, 1, 150)
  readonly property int criticalTempC: intSetting("criticalTempC", 90, 1, 150)
  readonly property int warnFanRpm: intSetting("warnFanRpm", 3500, 0, 20000)
  readonly property int criticalFanRpm: intSetting("criticalFanRpm", 5000, 0, 20000)

  // --------------------------------------------------------------- theming
  //
  // severityColors toggles the warm-toward-urgent ramp on figures, gauges
  // and icons: off = everything stays the neutral bar foreground (values
  // still live, just uncolored). iconColor overrides the idle icon/figure
  // tint with any hex color (config-file only) — "" follows the bar.
  readonly property bool severityColors: boolSetting("severityColors", true)

  // Let QML parse supported hex colors; an unset or invalid override follows
  // the bar foreground. An empty string in a color property becomes black.
  readonly property color glyphIdleColor: {
    var hex = String(setting("iconColor", "")).trim()
    return /^#(?:[0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/.test(hex) ? hex : base
  }

  // The popup's process lists: how many rows per list and how often Service
  // re-runs the process survey script. Capped at 5 everywhere (manifest,
  // panel, and here) so a larger value can never silently clamp.
  readonly property int topProcessCount: intSetting("topProcessCount", 5, 1, 5)
  readonly property int cpuThresholdPct: intSetting("cpuThresholdPct", 10, 1, 400)
  readonly property int memThresholdMib: intSetting("memThresholdMib", 0, 0, 8192)

  readonly property string clickCommand: String(setting("clickCommand", ""))

  // ----------------------------------------------------------------- glyphs

  readonly property string gpuIcon: String(setting("gpuIcon", "󰾲"))
  readonly property string cpuIcon: String(setting("cpuIcon", ""))
  readonly property string tempIcon: String(setting("tempIcon", ""))
  readonly property string gpuTempIcon: String(setting("gpuTempIcon", "󰔏"))
  readonly property string ramIcon: String(setting("ramIcon", ""))
  readonly property string fanIcon: String(setting("fanIcon", "\uDB80\uDE10"))

  readonly property int gpuIconRotation: intSetting("gpuIconRotation", 0, -360, 360)
  readonly property int cpuIconRotation: intSetting("cpuIconRotation", 0, -360, 360)
  readonly property int tempIconRotation: intSetting("tempIconRotation", 0, -360, 360)
  readonly property int gpuTempIconRotation: intSetting("gpuTempIconRotation", 0, -360, 360)
  readonly property int ramIconRotation: intSetting("ramIconRotation", 0, -360, 360)
  readonly property int fanIconRotation: intSetting("fanIconRotation", 0, -360, 360)

  function boolSetting(name, fallback) {
    var value = setting(name, fallback)
    if (typeof value === "boolean") return value
    var text = String(value).trim().toLowerCase()
    if (["true", "1", "yes", "on"].indexOf(text) !== -1) return true
    if (["false", "0", "no", "off"].indexOf(text) !== -1) return false
    return fallback
  }

  function intSetting(name, fallback, min, max) {
    var n = parseInt(String(setting(name, fallback)), 10)
    if (!isFinite(n)) n = fallback
    return Math.max(min, Math.min(max, n))
  }

  // ------------------------------------------------------------------ color

  readonly property color base: bar ? bar.barForeground : Color.foreground
  readonly property color hot: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(base, 1.45)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  function warm(from, amount) {
    if (!severityColors) return from
    if (!(amount > 0)) return from
    var t = Math.min(1, amount)
    return Qt.rgba(from.r + (hot.r - from.r) * t,
                   from.g + (hot.g - from.g) * t,
                   from.b + (hot.b - from.b) * t,
                   from.a)
  }

  function tempColor(tempC) {
    if (!severityColors) return glyphIdleColor
    // No reading yet: keep the dim marker. Cool-but-real temps render at full
    // idle brightness; only the warn→critical ramp warms them toward urgent.
    if (!isFinite(tempC) || tempC <= 0) return dim
    if (tempC <= warnTempC) return glyphIdleColor
    var t = Math.min(1, Math.max(0, (tempC - warnTempC) / Math.max(1, criticalTempC - warnTempC)))
    return Qt.rgba(base.r + (hot.r - base.r) * t,
                   base.g + (hot.g - base.g) * t,
                   base.b + (hot.b - base.b) * t,
                   base.a)
  }

  function fanSeverity(rpm) {
    if (!isFinite(rpm) || rpm < 0) return 0
    return Math.min(1, Math.max(0, (rpm - warnFanRpm) / Math.max(1, criticalFanRpm - warnFanRpm)))
  }

  // Live per-cell severity. The Repeater delegates persist for the life of the
  // cells array (a re-evaluated `var` array does not reliably rebuild them), so
  // per-cell severity snapshots captured at delegate creation go stale; resolving
  // by key keeps icon/gauge/value colors bound to live readings.
  function cellSeverity(key) {
    if (key === "cpu") return Model.severity(hw.cpuPercent, warnPercent, criticalPercent)
    if (key === "gpu") return Model.severity((hw.gpuPercent >= 0 ? hw.gpuPercent : hw.gpuVramPercent), warnPercent, criticalPercent)
    if (key === "ram") return Model.severity(hw.memPercent, warnPercent, criticalPercent)
    if (key === "cpu-temp") return Math.min(1, Math.max(0, (hw.cpuTempC - warnTempC) / Math.max(1, criticalTempC - warnTempC)))
    if (key === "gpu-temp") return Model.severity(hw.gpuTempC, warnTempC, criticalTempC)
    if (key === "fan") return fanSeverity(hw.fanRpm)
    if (key === "gpu-fan") return fanSeverity(hw.gpuRpm)
    return 0
  }

  function cellTempC(key) {
    if (key === "cpu-temp") return hw.cpuTempC
    if (key === "gpu-temp") return hw.gpuTempC
    return -1
  }

  readonly property int percentSlot: Math.ceil(percentMetrics.advanceWidth)

  TextMetrics {
    id: percentMetrics
    font.family: root.fontFamily
    font.pixelSize: root.valueSize
    text: "100%"
  }

  // --------------------------------------------------------------- readings

  Service {
    id: hw
    settings: root.settings
    active: root.onThisScreen
  }

  function percentPadFor(value) {
    if (percentPad !== "zero") return ""
    if (!isFinite(value) || value < 0) return ""
    return Math.round(value) < 10 ? "0" : ""
  }

  function percentText(value) {
    if (percentPad === "lead") return Model.padLeft(Model.formatPercent(value), 3)
    return Model.formatPercent(value)
  }

  function tempText(celsius) {
    var figure = Model.tempNumber(celsius, fahrenheit)
    if (figure === "–") return Model.padLeft(figure, 3)

    var unit = fahrenheit ? "F" : "C"
    var text = figure
    if (tempFormat === "degree-unit") text += "°" + unit
    else if (tempFormat === "degree") text += "°"
    else if (tempFormat === "unit") text += unit
    else if (tempFormat === "unit-lower") text += unit.toLowerCase()
    return (labelled || percentPad === "lead") ? Model.padLeft(text, 3) : text
  }

  function ramText() {
    if (ramFormat === "percent") return percentText(hw.memPercent)
    if (!hw.memory) return "–"

    var usedGib = Model.gibFromKib(hw.memory.usedKib)
    var totalGib = Model.gibFromKib(hw.memory.totalKib)
    var availGib = Model.gibFromKib(hw.memory.availableKib)

    if (ramFormat === "used") {
      return Model.formatGibPrecise(usedGib) + "G"
    }

    if (ramFormat === "free" || ramFormat === "available") {
      return Model.formatGibPrecise(availGib) + "G"
    }

    if (labelled) {
      return Model.formatGibPrecise(usedGib) + "/" + Model.formatGib(totalGib) + "G"
    }

    if (mode === "icons") {
      return Model.formatGib(usedGib) + "/" + Model.formatGib(totalGib) + "G"
    }

    var used = Model.formatGib(usedGib)
    var total = Model.formatGib(totalGib)
    return Model.padLeft(used, 3) + "/" + total
  }

  // ------------------------------------------------------------- cell output

  readonly property var cells: {
    var cellMap = {}

    // GPU Load
    if (showGpu && hw.hasGpu) {
      var busy = hw.gpuPercent
      var meterValue = busy >= 0 ? busy : hw.gpuVramPercent
      cellMap["gpu"] = {
        key: "gpu",
        label: "GPU",
        icon: gpuIcon,
        iconRotation: gpuIconRotation,
        value: percentText(meterValue),
        pad: percentPadFor(meterValue),
        slotted: percentPad === "trail",
        temp: (mode === "full" || mode === "labels") && hw.gpuTempC > 0 ? tempText(hw.gpuTempC) : "",
        tempC: hw.gpuTempC,
        ratio: meterValue >= 0 ? meterValue / 100 : 0,
        // Severity follows the same fallback figure the cell shows, so a card
        // reporting via VRAM still warms up instead of staying cool.
        severity: Model.severity(meterValue, warnPercent, criticalPercent)
      }
    }

    // CPU Load
    if (showCpu) {
      cellMap["cpu"] = {
        key: "cpu",
        label: "CPU",
        icon: cpuIcon,
        iconRotation: cpuIconRotation,
        value: percentText(hw.cpuPercent),
        pad: percentPadFor(hw.cpuPercent),
        slotted: percentPad === "trail",
        temp: (mode === "full" || mode === "labels") && hw.cpuTempC > 0 ? tempText(hw.cpuTempC) : "",
        tempC: hw.cpuTempC,
        ratio: hw.cpuPercent >= 0 ? hw.cpuPercent / 100 : 0,
        severity: Model.severity(hw.cpuPercent, warnPercent, criticalPercent)
      }
    }

    // CPU Temperature (standalone cell used in 'icons' mode). Always present
    // when a heat reading exists, coloured by the same ramp as the GPU temp.
    // In compact mode temperatures are omitted by design; full/labels embed
    // the temperature inline in the CPU cell instead.
    if (showCpuTemp && hw.cpuTempC > 0 && showTemps && mode === "icons") {
      cellMap["cpu-temp"] = {
        key: "cpu-temp",
        label: "TEMP",
        icon: tempIcon,
        iconRotation: tempIconRotation,
        value: tempText(hw.cpuTempC),
        pad: "",
        slotted: false,
        temp: "",
        tempC: hw.cpuTempC,
        ratio: Math.min(1, Math.max(0, (hw.cpuTempC - warnTempC) / Math.max(1, criticalTempC - warnTempC))),
        severity: Math.min(1, Math.max(0, (hw.cpuTempC - warnTempC) / Math.max(1, criticalTempC - warnTempC)))
      }
    }

    // System fan, right of the CPU temperature. Shown in every mode except
    // compact (which is glyphs + load gauges only) whenever a fan reading
    // exists and showFan is set.
    if (root.showFan && hw.fanRpm >= 0 && mode !== "compact") {
      cellMap["fan"] = {
        key: "fan",
        label: "FAN",
        icon: fanIcon,
        iconRotation: fanIconRotation,
        value: Model.formatRpm(hw.fanRpm),
        pad: "",
        slotted: false,
        temp: "",
        tempC: -1,
        ratio: root.fanSeverity(hw.fanRpm),
        severity: root.fanSeverity(hw.fanRpm)
      }
    }

    // GPU Temperature (standalone cell used in 'icons' mode; full/labels embed
    // it inline in the GPU cell instead, like the CPU temperature above)
    if (showGpuTemp && hw.hasGpu && hw.gpuTempC > 0 && showTemps && mode === "icons") {
      cellMap["gpu-temp"] = {
        key: "gpu-temp",
        label: "GPU°",
        icon: gpuTempIcon,
        iconRotation: gpuTempIconRotation,
        value: tempText(hw.gpuTempC),
        pad: "",
        slotted: false,
        temp: "",
        tempC: hw.gpuTempC,
        ratio: Math.min(1, Math.max(0, (hw.gpuTempC - warnTempC) / Math.max(1, criticalTempC - warnTempC))),
        severity: Model.severity(hw.gpuTempC, warnTempC, criticalTempC)
      }
    }

    // RAM
    if (showRam) {
      cellMap["ram"] = {
        key: "ram",
        label: "RAM",
        icon: ramIcon,
        iconRotation: ramIconRotation,
        value: ramText(),
        pad: "",
        slotted: false,
        temp: "",
        tempC: -1,
        ratio: hw.memPercent >= 0 ? hw.memPercent / 100 : 0,
        severity: Model.severity(hw.memPercent, warnPercent, criticalPercent)
      }
    }

    var out = []
    var added = {}
    for (var i = 0; i < itemOrder.length; i++) {
      var k = itemOrder[i]
      if (cellMap[k] && !added[k]) {
        out.push(cellMap[k])
        added[k] = true
      }
    }
    // Append any enabled items not in itemOrder
    var fallbackOrder = ["gpu", "cpu", "ram", "cpu-temp", "fan", "gpu-temp"]
    for (var j = 0; j < fallbackOrder.length; j++) {
      var fk = fallbackOrder[j]
      if (cellMap[fk] && !added[fk]) {
        out.push(cellMap[fk])
        added[fk] = true
      }
    }

    return out
  }

  // ---------------------------------------------------------------- tooltip

  readonly property string monitorName: {
    var parts = clickCommand.split(/\s+/)
    var last = String(parts[parts.length - 1] || "")
    return last.substring(last.lastIndexOf("/") + 1)
  }

  readonly property string hint: clickCommand === ""
    ? (vertical ? "Activity Monitor · click to open the panel"
                : "Activity Monitor · right click for " + nextMode)
    : (vertical ? "Click for " + monitorName
                : "Click for " + monitorName + " · right click for " + nextMode)

  function detail() {
    var lines = []

    var cpu = "CPU  " + Model.formatPercent(hw.cpuPercent)
    if (hw.cpuTempC > 0) cpu += "  ·  " + Model.formatTemp(hw.cpuTempC, fahrenheit)
    lines.push(cpu)
    if (hw.cpuInfo && hw.cpuInfo.model) {
      lines.push(hw.cpuInfo.model + " · " + hw.cpuInfo.cores + "C/" + hw.cpuInfo.threads + "T")
    }
    if (hw.load && isFinite(hw.load.one) && isFinite(hw.load.five) && isFinite(hw.load.fifteen)) {
      lines.push("Load " + hw.load.one.toFixed(2) + "  " + hw.load.five.toFixed(2) + "  " + hw.load.fifteen.toFixed(2))
    }
    if (hw.fanRpm >= 0) lines.push("Fan  " + Model.formatRpm(hw.fanRpm))

    if (hw.hasGpu) {
      lines.push("")
      var gpu = "GPU  " + Model.formatPercent(hw.gpuPercent)
      if (hw.gpuWatts >= 0) gpu += "  ·  " + Model.formatWatts(hw.gpuWatts)
      lines.push(gpu)
      lines.push(hw.gpuInfo && hw.gpuInfo.name ? String(hw.gpuInfo.name) : "Graphics Adapter")
      if (hw.gpuVramTotalBytes > 0) {
        lines.push("VRAM " + Model.formatGib(Model.gibFromBytes(hw.gpuVramUsedBytes)) + " / "
                   + Model.formatGib(Model.gibFromBytes(hw.gpuVramTotalBytes)) + " GiB  ·  "
                   + Model.formatPercent(hw.gpuVramPercent))
      }
      var extras = []
      if (hw.gpuRpm >= 0) extras.push("Fan " + Model.formatRpm(hw.gpuRpm))
      if (extras.length > 0) lines.push(extras.join("  ·  "))
    }

    if (hw.memory) {
      lines.push("")
      lines.push("RAM  " + Model.formatGib(Model.gibFromKib(hw.memory.usedKib)) + " / "
                 + Model.formatGib(Model.gibFromKib(hw.memory.totalKib)) + " GiB  ·  "
                 + Model.formatPercent(hw.memory.percent))
      lines.push("Cache " + Model.formatGib(Model.gibFromKib(hw.memory.cachedKib)) + " GiB"
                 + (hw.memory.swapTotalKib > 0
                    ? "  ·  Swap " + Model.formatGib(Model.gibFromKib(hw.memory.swapUsedKib)) + " / "
                      + Model.formatGib(Model.gibFromKib(hw.memory.swapTotalKib)) + " GiB"
                    : ""))
    }

    if (hw.processReport && hw.processReport.ok) {
      var top = hw.processReport.cpu[0]
      var topMem = hw.processReport.mem[0]
      if (top || topMem) lines.push("")
      if (top) {
        lines.push("Top " + Model.clampText(top.comm, 20) + " " + Model.formatPercent(top.cpuPct))
      }
      if (topMem) {
        lines.push("TopMem " + Model.clampText(topMem.comm, 20) + " " + Model.formatKib(topMem.rssKib))
      }
    }

    return lines.join("\n")
  }

  // ----------------------------------------------------------------- actions

  function refresh() {
    hw.sample()
  }

  function currentEntry() {
    var config = root.bar && root.bar.shell ? root.bar.shell.shellConfig : null
    var layout = config && config.bar ? config.bar.layout : null
    var sections = ["left", "center", "right"]
    for (var s = 0; layout && s < sections.length; s++) {
      var entries = layout[sections[s]] || []
      for (var i = 0; i < entries.length; i++) {
        if (entries[i] && String(entries[i].id) === root.moduleName) return entries[i]
      }
    }
    return root.settings || {}
  }

  function persistSetting(key, value) {
    var live = currentEntry()
    var entry = { id: root.moduleName }
    for (var k in live) if (k !== "id") entry[k] = live[k]
    entry[key] = value
    root.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function") {
      root.bar.shell.updateEntryInline(root.moduleName, entry)
    }
  }

  function cycleMode() {
    var live = currentEntry()

    var from = String(live.mode === undefined || live.mode === null ? mode : live.mode).trim().toLowerCase()
    if (modes.indexOf(from) === -1) from = mode
    var next = modes[(modes.indexOf(from) + 1) % modes.length]

    persistSetting("mode", next)
  }

  function toggleFahrenheit() {
    persistSetting("fahrenheit", !fahrenheit)
  }

  function launchMonitor() {
    if (clickCommand === "") {
      root.toggle()
      return
    }
    if (root.bar) root.bar.run(clickCommand)
    else Quickshell.execDetached(["bash", "-lc", clickCommand])
  }

  IpcHandler {
    target: "anson.activity-monitor"

    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function toggleFahrenheit(): void { root.toggleFahrenheit() }
    function refresh(): void { root.broadcast("refresh") }
    function cycleMode(): void { root.cycleMode() }
    function status(): string { return root.detail() }
  }

  // ------------------------------------------------------- vertical bar chip
  //
  // A vertical bar renders one compact chip instead of the stacked cells.
  // chipStat picks the figure: "auto" promotes whichever enabled-and-readable
  // metric sits highest on the same severity ramp the cells colour with
  // (critical beats warned beats calm), so heat outranks load; ties prefer
  // cpu-temp → cpu → ram → gpu-temp → gpu → fan. Every show* toggle and
  // sensor-availability guard applies to a hand-picked stat too, falling back
  // to auto when the pick has no live reading.
  readonly property var chipStats: ["cpu-temp", "cpu", "ram", "gpu-temp", "gpu", "fan"]

  readonly property string chipStat: {
    var want = String(setting("chipStat", "auto")).trim().toLowerCase()
    return chipStats.indexOf(want) !== -1 || want === "auto" ? want : "auto"
  }

  function chipEnabled(key) {
    if (key === "cpu") return showCpu
    if (key === "ram") return showRam
    if (key === "cpu-temp") return showCpuTemp && hw.cpuTempC > 0
    if (key === "gpu") return showGpu && hw.hasGpu
    if (key === "gpu-temp") return showGpuTemp && hw.hasGpu && hw.gpuTempC > 0
    if (key === "fan") return showFan && hw.fanRpm >= 0
    return false
  }

  function chipLevel(key) {
    // Discrete staging of the continuous severity ramp: 3 critical, 2 warned,
    // 1 readable and calm, 0 disabled or without a live reading.
    if (!chipEnabled(key)) return 0
    var s = cellSeverity(key)
    if (s >= 1) return 3
    if (s > 0) return 2
    return 1
  }

  readonly property string chipKey: {
    if (chipStat !== "auto" && chipEnabled(chipStat)) return chipStat
    var best = ""
    var bestLevel = 0
    for (var i = 0; i < chipStats.length; i++) {
      var level = chipLevel(chipStats[i])
      if (level > bestLevel) {
        best = chipStats[i]
        bestLevel = level
      }
    }
    return best
  }

  readonly property var chipCell: chipKey === "" ? null : chipCellFor(chipKey)

  // The chip reuses the shared cell delegate, so it carries the same object
  // shape and formatting the stacked cells build — identical glyphs, figures,
  // ramp colors, and Style geometry.
  function chipCellFor(key) {
    if (key === "cpu") {
      return {
        key: "cpu",
        label: "CPU",
        icon: cpuIcon,
        iconRotation: cpuIconRotation,
        value: percentText(hw.cpuPercent),
        pad: percentPadFor(hw.cpuPercent),
        slotted: false,
        temp: "",
        tempC: hw.cpuTempC,
        ratio: hw.cpuPercent >= 0 ? hw.cpuPercent / 100 : 0,
        severity: Model.severity(hw.cpuPercent, warnPercent, criticalPercent),
        chip: true
      }
    }

    if (key === "cpu-temp") {
      var ramp = Math.min(1, Math.max(0, (hw.cpuTempC - warnTempC) / Math.max(1, criticalTempC - warnTempC)))
      return {
        key: "cpu-temp",
        label: "TEMP",
        icon: tempIcon,
        iconRotation: tempIconRotation,
        value: tempText(hw.cpuTempC),
        pad: "",
        slotted: false,
        temp: "",
        tempC: hw.cpuTempC,
        ratio: ramp,
        severity: ramp,
        chip: true
      }
    }

    if (key === "ram") {
      return {
        key: "ram",
        label: "RAM",
        icon: ramIcon,
        iconRotation: ramIconRotation,
        value: ramText(),
        pad: "",
        slotted: false,
        temp: "",
        tempC: -1,
        ratio: hw.memPercent >= 0 ? hw.memPercent / 100 : 0,
        severity: Model.severity(hw.memPercent, warnPercent, criticalPercent),
        chip: true
      }
    }

    if (key === "gpu") {
      var busy = hw.gpuPercent
      var meterValue = busy >= 0 ? busy : hw.gpuVramPercent
      return {
        key: "gpu",
        label: "GPU",
        icon: gpuIcon,
        iconRotation: gpuIconRotation,
        value: percentText(meterValue),
        pad: percentPadFor(meterValue),
        slotted: false,
        temp: "",
        tempC: hw.gpuTempC,
        ratio: meterValue >= 0 ? meterValue / 100 : 0,
        severity: Model.severity(meterValue, warnPercent, criticalPercent),
        chip: true
      }
    }

    if (key === "gpu-temp") {
      var gpuRamp = Math.min(1, Math.max(0, (hw.gpuTempC - warnTempC) / Math.max(1, criticalTempC - warnTempC)))
      return {
        key: "gpu-temp",
        label: "GPU°",
        icon: gpuTempIcon,
        iconRotation: gpuTempIconRotation,
        value: tempText(hw.gpuTempC),
        pad: "",
        slotted: false,
        temp: "",
        tempC: hw.gpuTempC,
        ratio: gpuRamp,
        severity: Model.severity(hw.gpuTempC, warnTempC, criticalTempC),
        chip: true
      }
    }

    // fan
    return {
      key: "fan",
      label: "FAN",
      icon: fanIcon,
      iconRotation: fanIconRotation,
      value: Model.formatRpm(hw.fanRpm),
      pad: "",
      slotted: false,
      temp: "",
      tempC: -1,
      ratio: root.fanSeverity(hw.fanRpm),
      severity: root.fanSeverity(hw.fanRpm),
      chip: true
    }
  }

  // ------------------------------------------------------------------ layout

  readonly property int glyphBox: Math.max(Style.bar.iconCanvas, iconSize + Style.space(2))
  readonly property int contentHeight: Math.max(glyphBox, Style.space(15))
  readonly property int gaugeWidth: Math.max(6, Math.round(iconSize * 0.45))
  readonly property int gaugeHeight: Math.max(11, Math.round(iconSize * 0.9))

  visible: onThisScreen
  implicitWidth: onThisScreen ? button.implicitWidth : 0
  implicitHeight: button.implicitHeight

  // An unknown connector name hides the widget entirely; say so loudly
  // instead of failing silent.
  onOnThisScreenChanged: {
    if (!onThisScreen && monitors.length > 0) {
      console.warn(moduleName + ": hidden, screen '" + screenName
        + "' is not in monitors [" + monitors.join(",") + "]")
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    labelVisible: false
    hasVisualContent: root.vertical ? root.chipCell !== null : root.cells.length > 0
    tooltipText: root.hint
    horizontalMargin: 6
    fixedWidth: root.vertical ? -1 : Math.ceil(horizontalCells.implicitWidth + button.scaledHorizontalMargin * 2)
    fixedHeight: root.vertical ? Math.ceil(verticalCells.implicitHeight + Style.space(8)) : -1

    onPressed: function(pressedButton) {
      if (root.vertical) {
        // One chip, one job: either button opens the panel — no mode to
        // cycle through here. Middle click still resamples.
        if (pressedButton === Qt.MiddleButton) root.refresh()
        else root.launchMonitor()
      } else if (pressedButton === Qt.RightButton) root.cycleMode()
      else if (pressedButton === Qt.MiddleButton) root.refresh()
      else root.launchMonitor()
    }

    Row {
      id: horizontalCells
      visible: !root.vertical
      anchors.centerIn: parent
      spacing: Style.space(root.mode === "icons" ? 14 : 8)

      Repeater {
        model: root.cells
        delegate: cell
      }
    }

    Column {
      id: verticalCells
      visible: root.vertical
      anchors.centerIn: parent
      spacing: Style.space(5)

      // The vertical bar shows a single compact chip (one cell of the same
      // visual style) instead of the stacked telemetry cells.
      Repeater {
        model: root.chipCell ? [root.chipCell] : []
        delegate: cell
      }
    }
  }

  SystemPanel {
    id: systemPanel
    anchorItem: button
    bar: root.bar
    owner: root
    open: root.opened
    hw: hw
    mode: root.mode
    showGpu: root.showGpu
    showCpu: root.showCpu
    showCpuTemp: root.showCpuTemp
    showGpuTemp: root.showGpuTemp
    showRam: root.showRam
    showFan: root.showFan
    severityColors: root.severityColors
    ramFormat: root.ramFormat
    tempFormat: root.tempFormat
    showGauges: root.showGauges
    showValues: root.showValues
    fahrenheit: root.fahrenheit
    warnPercent: root.warnPercent
    criticalPercent: root.criticalPercent
    warnTempC: root.warnTempC
    criticalTempC: root.criticalTempC
    warnFanRpm: root.warnFanRpm
    criticalFanRpm: root.criticalFanRpm
    topProcessCount: root.topProcessCount
    cpuThresholdPct: root.cpuThresholdPct
    memThresholdMib: root.memThresholdMib
  }

  // A component group: glyph + figure (+ temp)
  Component {
    id: cell

    Row {
      id: group
      required property var modelData
      spacing: Style.space(4)

      readonly property real slack: root.showValues && modelData.slotted
        ? Math.max(0, root.percentSlot - valueText.implicitWidth - spacing)
        : 0

      readonly property bool isTempCell: modelData.key === "cpu-temp" || modelData.key === "gpu-temp"

      TextMetrics {
        id: glyphMetrics
        font.family: root.fontFamily
        font.pixelSize: root.iconSize
        text: modelData.icon
      }

      Item {
        readonly property bool turned: Math.abs(modelData.iconRotation % 180) === 90
        readonly property real inkWidth: turned
          ? glyphMetrics.tightBoundingRect.height
          : glyphMetrics.tightBoundingRect.width

        visible: !root.labelled
        width: visible ? Math.max(1, Math.ceil(inkWidth)) : 0
        height: root.contentHeight

        OpticalGlyph {
          anchors.fill: parent
          visible: modelData.iconRotation === 0
          text: modelData.icon
          fontFamily: root.fontFamily
          fontSize: root.iconSize
          color: group.isTempCell
            ? root.tempColor(root.cellTempC(modelData.key))
            : root.warm(root.glyphIdleColor, root.cellSeverity(modelData.key))
          Behavior on color { ColorAnimation { duration: 240 } }
        }

        Text {
          anchors.centerIn: parent
          visible: modelData.iconRotation !== 0
          rotation: modelData.iconRotation
          text: modelData.icon
          color: group.isTempCell
            ? root.tempColor(root.cellTempC(modelData.key))
            : root.warm(root.glyphIdleColor, root.cellSeverity(modelData.key))
          font.family: root.fontFamily
          font.pixelSize: root.iconSize
          renderType: Text.NativeRendering
          Behavior on color { ColorAnimation { duration: 240 } }
        }
      }

      Gauge {
        visible: root.showGauges && !root.labelled
        height: root.contentHeight
        bodyWidth: root.gaugeWidth
        bodyHeight: root.gaugeHeight
        ratio: modelData.ratio
        fillColor: group.isTempCell
          ? root.tempColor(root.cellTempC(modelData.key))
          : root.warm(root.glyphIdleColor, root.cellSeverity(modelData.key))
        trackColor: Qt.rgba(root.base.r, root.base.g, root.base.b, 0.14)
        borderColor: Qt.rgba(root.base.r, root.base.g, root.base.b, 0.4)
        glow: modelData.severity >= 1
      }

      Text {
        visible: root.labelled
        height: root.contentHeight
        text: modelData.label
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: root.valueSize
        font.bold: true
        verticalAlignment: Text.AlignVCenter
        renderType: Text.NativeRendering
      }

      Row {
        // Chip cells always show their figure, even in the vertical bar where
        // the global showValues switch is forced off.
        visible: root.showValues || modelData.chip === true
        height: root.contentHeight
        spacing: 0

        Text {
          visible: modelData.pad !== ""
          height: root.contentHeight
          text: modelData.pad
          color: root.warm(root.base, root.cellSeverity(modelData.key))
          opacity: root.padOpacity
          font.family: root.fontFamily
          font.pixelSize: root.valueSize
          verticalAlignment: Text.AlignVCenter
          renderType: Text.NativeRendering
        }

        Text {
          id: valueText
          height: root.contentHeight
          text: modelData.value
          color: group.isTempCell
            ? root.tempColor(root.cellTempC(modelData.key))
            : root.warm(root.glyphIdleColor, root.cellSeverity(modelData.key))
          font.family: root.fontFamily
          font.pixelSize: root.valueSize
          font.bold: !group.isTempCell
          verticalAlignment: Text.AlignVCenter
          renderType: Text.NativeRendering
          Behavior on color { ColorAnimation { duration: 240 } }
        }
      }

      Row {
        visible: root.showTemps && modelData.temp !== ""
        height: root.contentHeight
        spacing: Style.space(3)

        Text {
          textFormat: Text.PlainText
          height: root.contentHeight
          text: "·"
          color: Qt.darker(root.base, 1.8)
          font.family: root.fontFamily
          font.pixelSize: root.valueSize
          verticalAlignment: Text.AlignVCenter
          renderType: Text.NativeRendering
        }

        Text {
          textFormat: Text.PlainText
          height: root.contentHeight
          text: modelData.temp
          color: root.tempColor(root.cellTempC(modelData.key))
          font.family: root.fontFamily
          font.pixelSize: root.valueSize
          font.bold: false
          verticalAlignment: Text.AlignVCenter
          renderType: Text.NativeRendering
          Behavior on color { ColorAnimation { duration: 240 } }
        }
      }

      Item {
        visible: group.slack > 0
        width: visible ? group.slack : 0
        height: 1
      }
    }
  }
}
