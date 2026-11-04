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

    function codeForName(name) {
        if (!name) return "";
        const low = name.toLowerCase();
        // Check if any entry in layouts matches the full name
        for (const item of layouts) {
            if (item && item.name && item.name.toLowerCase() === low) return item.code;
        }
        // Check against codeNames values
        for (const k in codeNames) {
            if (low === codeNames[k].toLowerCase() || low.startsWith(codeNames[k].toLowerCase()))
                return k.toUpperCase();
        }
        const known = {
            "english (uk)": "GB",
            "english (us)": "US",
            "english": "US",
            "russian": "RU",
            "kazakh": "KZ",
            "german": "DE",
            "french": "FR",
            "spanish": "ES",
            "italian": "IT",
            "ukrainian": "UA",
            "polish": "PL",
            "turkish": "TR",
            "japanese": "JP",
            "korean": "KR",
            "chinese": "CN"
        };
        for (const k in known) if (low.startsWith(k)) return known[k];
        return name.substring(0, 2).toUpperCase();
    }

    readonly property string short: {
        if (layout) {
            const c = codeForName(layout);
            if (c) return c;
        }
        if (layouts.length > activeIndex && layouts[activeIndex]) {
            return layouts[activeIndex].code;
        }
        return "";
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
            const name = p.slice(1).join(",").trim();
            if (!name) return;
            const changed = name !== root.layout;
            root.layout = name;
            const code = root.codeForName(name);
            const matchIdx = root.layouts.findIndex(l => l.code === code || l.name.toLowerCase() === name.toLowerCase());
            if (matchIdx >= 0) root.activeIndex = matchIdx;
            root.refresh();
            if (changed) Osd.show("layout", "\uf11c", code || root.short, -1, name);
        }
    }

    property string capsPath: ""
    property string numPath: ""
    property string scrollPath: ""
    property bool capsInit: false
    property bool numInit: false
    property bool scrollInit: false

    Process {
        id: ledFinder
        running: true
        command: ["sh", "-c", "for k in capslock numlock scrolllock; do p=$(ls /sys/class/leds/*::$k/brightness 2>/dev/null | head -n1); echo \"${p:-}\"; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n");
                root.capsPath = (lines[0] || "").trim();
                root.numPath = (lines[1] || "").trim();
                root.scrollPath = (lines[2] || "").trim();
            }
        }
    }

    FileView {
        id: capsFile
        path: root.capsPath
        printErrors: false
        onLoaded: {
            const c = parseInt(text().trim()) > 0;
            if (root.capsInit && c !== root.caps) Osd.show("caps", "\uf15b", "Caps Lock", -1, c ? "On" : "Off", c);
            root.caps = c;
            root.capsInit = true;
        }
    }
    FileView {
        id: numFile
        path: root.numPath
        printErrors: false
        onLoaded: {
            const n = parseInt(text().trim()) > 0;
            if (root.numInit && n !== root.num) Osd.show("num", "\uf292", "Num Lock", -1, n ? "On" : "Off", n);
            root.num = n;
            root.numInit = true;
        }
    }
    FileView {
        id: scrollFile
        path: root.scrollPath
        printErrors: false
        onLoaded: {
            const s = parseInt(text().trim()) > 0;
            if (root.scrollInit && s !== root.scroll) Osd.show("scroll", "\uf0ab", "Scroll Lock", -1, s ? "On" : "Off", s);
            root.scroll = s;
            root.scrollInit = true;
        }
    }

    Timer {
        interval: 300
        repeat: true
        running: root.capsPath !== "" || root.numPath !== "" || root.scrollPath !== ""
        onTriggered: {
            if (root.capsPath) capsFile.reload();
            if (root.numPath) numFile.reload();
            if (root.scrollPath) scrollFile.reload();
        }
    }
}
