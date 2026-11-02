pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import qs.config

// Keyboard layout (from Hyprland events + hyprctl devices) and lock-key LEDs (from sysfs).
Singleton {
    id: root
    property string layout: ""
    property int activeIndex: 0
    property var layouts: [] // [{ index: 0, code: "US", name: "English (US)" }, ...]

    readonly property var codeNames: ({
        "us": "English (US)",
        "gb": "English (UK)",
        "ru": "Russian",
        "kz": "Kazakh",
        "de": "German",
        "fr": "French",
        "es": "Spanish",
        "it": "Italian",
        "ua": "Ukrainian",
        "pl": "Polish",
        "tr": "Turkish",
        "jp": "Japanese",
        "kr": "Korean",
        "cn": "Chinese"
    })

    readonly property string short: {
        if (layouts.length > activeIndex && layouts[activeIndex]) {
            return layouts[activeIndex].code;
        }
        const known = { "english": "EN", "russian": "RU", "kazakh": "KZ" };
        const l = layout.toLowerCase();
        for (const k in known) if (l.startsWith(k)) return known[k];
        return layout ? layout.substring(0, 2).toUpperCase() : "";
    }
    property bool caps: false
    property bool num: false
    property bool scroll: false
    property bool ready: false

    function refresh() {
        kbProc.running = true;
    }

    function setLayout(idx) {
        Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", String(idx)]);
    }

    function nextLayout() {
        Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", "next"]);
    }

    Process {
        id: kbProc
        running: true
        command: ["sh", "-c", "hyprctl devices -j | jq -c '[.keyboards[] | select(.main)][0] // .keyboards[0]'"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const kb = JSON.parse(text.trim());
                    if (!kb) return;
                    const codes = (kb.layout || "us").split(",").map(s => s.trim()).filter(Boolean);
                    const idx = kb.active_layout_index ?? 0;
                    const activeName = kb.active_keymap || "";
                    root.activeIndex = idx;
                    root.layout = activeName;
                    root.layouts = codes.map((c, i) => ({
                        index: i,
                        code: c.toUpperCase(),
                        name: i === idx && activeName ? activeName : (root.codeNames[c.toLowerCase()] || c.toUpperCase())
                    }));
                } catch (e) {}
            }
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(ev) {
            if (ev.name !== "activelayout") return;
            const p = ev.data.split(",");
            const name = p.slice(1).join(",");
            const changed = name !== root.layout;
            root.layout = name;
            root.refresh();
            if (changed) Osd.show("layout", "\uf11c", root.short, -1, name);
        }
    }

    Process {
        id: leds
        command: ["sh", "-c", "for k in capslock numlock scrolllock; do cat /sys/class/leds/*::$k/brightness 2>/dev/null | sort -rn | head -n1; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = text.trim().split("\n").map(x => parseInt(x) > 0);
                const c = !!v[0], n = !!v[1], s = !!v[2];
                if (root.ready) {
                    if (c !== root.caps) Osd.show("caps", "\uf15b", "Caps Lock", -1, c ? "On" : "Off", c);
                    if (n !== root.num) Osd.show("num", "\uf292", "Num Lock", -1, n ? "On" : "Off", n);
                    if (s !== root.scroll) Osd.show("scroll", "\uf0ab", "Scroll Lock", -1, s ? "On" : "Off", s);
                }
                root.caps = c; root.num = n; root.scroll = s; root.ready = true;
            }
        }
    }
    Timer { interval: 300; repeat: true; running: true; triggeredOnStart: true; onTriggered: if (!leds.running) leds.running = true }
}
