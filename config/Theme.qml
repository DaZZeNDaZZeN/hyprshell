pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Design tokens. The base is neutral; only highlights use `accent`.
Singleton {
    id: root

    readonly property var statics: ({
        "nord":     { dark: true,  bg: "#2e3440", surface: "#3b4252", surface2: "#434c5e", text: "#eceff4", sub: "#a7b0c0", accent: "#88c0d0" },
        "gruvbox":  { dark: true,  bg: "#282828", surface: "#3c3836", surface2: "#504945", text: "#ebdbb2", sub: "#a89984", accent: "#d79921" },
        "mocha":    { dark: true,  bg: "#1e1e2e", surface: "#313244", surface2: "#45475a", text: "#cdd6f4", sub: "#a6adc8", accent: "#cba6f7" },
        "rosepine": { dark: true,  bg: "#191724", surface: "#26233a", surface2: "#312e48", text: "#e0def4", sub: "#908caa", accent: "#ebbcba" },
        "latte":    { dark: false, bg: "#eff1f5", surface: "#e6e9ef", surface2: "#ccd0da", text: "#4c4f69", sub: "#6c6f85", accent: "#8839ef" }
    })
    readonly property var staticNames: ["none", "nord", "gruvbox", "mocha", "rosepine", "latte"]

    readonly property var st: statics[Config.o.staticTheme] ?? null
    readonly property bool dark: st ? st.dark : Config.o.themeMode !== "light"

    // ---- user overrides (hot-reloaded JSON: any token below can be overridden) ----
    property var ov: ({})
    FileView {
        path: Config.dir + "/theme-overrides.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: { try { root.ov = JSON.parse(text()); } catch (e) { root.ov = ({}); } }
        onLoadFailed: root.ov = ({})
    }
    function pick(key, fallback) { return ov[key] !== undefined ? ov[key] : fallback; }

    readonly property color accent: pick("accent",
        Config.o.accentMode === "custom" ? Config.o.customAccent
        : (Config.o.wallpaperAccent || (st ? st.accent : "#7aa2f7")))
    readonly property color onAccent: luminance(accent) > 0.5 ? "#111111" : "#ffffff"
    readonly property color accentDim: Qt.rgba(accent.r, accent.g, accent.b, 0.18)
    readonly property color accentSoft: Qt.rgba(accent.r, accent.g, accent.b, 0.32)

    readonly property color bg:       pick("bg",       st ? st.bg       : (dark ? "#121214" : "#f4f4f6"))
    readonly property color surface:  pick("surface",  st ? st.surface  : (dark ? "#1c1c20" : "#ffffff"))
    readonly property color surface2: pick("surface2", st ? st.surface2 : (dark ? "#28282e" : "#e8e8ec"))
    readonly property color surface3: Qt.lighter(surface2, dark ? 1.25 : 0.96)
    readonly property color text:     pick("text",     st ? st.text     : (dark ? "#ececf0" : "#1b1b1f"))
    readonly property color subtext:  pick("subtext",  st ? st.sub      : (dark ? "#9a9aa6" : "#62626c"))
    readonly property color border:   Qt.rgba(text.r, text.g, text.b, 0.10)
    readonly property color hover:    Qt.rgba(text.r, text.g, text.b, 0.08)
    readonly property color danger:   "#f2555a"
    readonly property color warn:     "#f0b04a"
    readonly property color ok:       "#58c27d"

    readonly property real opacity: Config.o.panelOpacity
    readonly property color panel:  Qt.rgba(bg.r, bg.g, bg.b, opacity)
    readonly property color card:   Qt.rgba(surface.r, surface.g, surface.b, Math.min(1, opacity + 0.05))

    readonly property int radius:   pick("radius", Config.o.radius)
    readonly property int radiusS:  Math.max(4, Math.round(radius * 0.6))
    readonly property int radiusL:  Math.round(radius * 1.4)
    readonly property string font:  pick("font", Config.o.fontFamily)
    readonly property string iconFont: "MesloLGS Nerd Font Propo"
    readonly property real fs:      Config.o.fontScale
    readonly property int fsS: Math.round(11 * fs)
    readonly property int fsM: Math.round(13 * fs)
    readonly property int fsL: Math.round(17 * fs)
    readonly property int fsXL: Math.round(28 * fs)
    readonly property int fsHuge: Math.round(72 * fs)

    // ---- motion: every component uses these ----
    readonly property real speed: Config.o.animSpeed
    readonly property int animFast:   Math.round(120 * speed)
    readonly property int anim:       Math.round(220 * speed)
    readonly property int animSlow:   Math.round(380 * speed)
    readonly property var easeOut:    [0.23, 1, 0.32, 1, 1, 1]
    readonly property var easeInOut:  [0.65, 0.05, 0.36, 1, 1, 1]

    function luminance(c) { return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b; }
    function withAlpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a); }
    function hex(c) {
        const h = v => ("0" + Math.round(v * 255).toString(16)).slice(-2);
        return "#" + h(c.r) + h(c.g) + h(c.b);
    }

    // Push the palette into GTK / Qt / KDE / Hyprland whenever it changes.
    property string sig: hex(accent) + hex(bg) + hex(surface) + hex(text) + dark + Config.o.iconTheme + Config.o.cursorTheme + Config.o.cursorSize
    onSigChanged: applyTimer.restart()
    Timer {
        id: applyTimer
        interval: 700
        onTriggered: {
            if (!Config.loaded) return;
            Quickshell.execDetached(["python3", Quickshell.shellDir + "/scripts/apply-theme.py",
                root.dark ? "dark" : "light", root.hex(root.accent), root.hex(root.bg), root.hex(root.surface),
                root.hex(root.text), Config.o.iconTheme, Config.o.cursorTheme, String(Config.o.cursorSize),
                Config.o.syncToolkits ? "1" : "0"]);
        }
    }
    Connections { target: Config; function onLoadedChanged() { applyTimer.restart(); } }
}
