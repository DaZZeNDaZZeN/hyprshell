pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import qs.config

// Keyboard layout (from Hyprland events) and lock-key LEDs (from sysfs).
Singleton {
    id: root
    property string layout: ""
    readonly property string short: {
        const known = { "english": "EN", "russian": "RU", "kazakh": "KZ" };
        const l = layout.toLowerCase();
        for (const k in known) if (l.startsWith(k)) return known[k];
        return layout ? layout.substring(0, 2).toUpperCase() : "";
    }
    property bool caps: false
    property bool num: false
    property bool scroll: false
    property bool ready: false

    Process {
        running: true
        command: ["sh", "-c", "hyprctl devices -j | jq -r '[.keyboards[] | select(.main)][0].active_keymap // empty'"]
        stdout: StdioCollector { onStreamFinished: { root.layout = text.trim(); } }
    }
    Connections {
        target: Hyprland
        function onRawEvent(ev) {
            if (ev.name !== "activelayout") return;
            const p = ev.data.split(",");
            const name = p.slice(1).join(",");
            if (name === root.layout) return;
            root.layout = name;
            Osd.show("layout", "\uf11c", root.short, -1, name);
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
