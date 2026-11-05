pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs.config

// Backlight via sysfs (read) + brightnessctl / logind (write).
Singleton {
    id: root
    property string device: ""
    property int max: 100
    property int raw: 100
    property bool initialized: false
    readonly property bool available: device !== "" && max > 0
    property real virtualValue: 1.0
    readonly property real value: available ? (max > 0 ? raw / max : 0) : virtualValue

    Process {
        running: true
        command: ["sh", "-c", "ls /sys/class/backlight 2>/dev/null | head -n1"]
        stdout: StdioCollector { onStreamFinished: root.device = text.trim() }
    }
    FileView {
        id: maxFile
        path: root.device ? "/sys/class/backlight/" + root.device + "/max_brightness" : ""
        onLoaded: {
            const m = parseInt(text());
            if (!isNaN(m) && m > 0) root.max = m;
        }
    }
    FileView {
        id: curFile
        path: root.device ? "/sys/class/backlight/" + root.device + "/brightness" : ""
        onLoaded: {
            const v = parseInt(text());
            if (isNaN(v)) return;
            if (!root.initialized) {
                root.raw = v;
                root.initialized = true;
                return;
            }
            if (v !== root.raw) {
                root.raw = v;
                Osd.show("brightness", "\uf185", Math.round(root.value * 100) + "%", root.value, "Brightness");
            }
        }
    }
    Timer { interval: 1500; running: root.available; repeat: true; onTriggered: curFile.reload() }

    Process { id: setter }
    function set(v) {
        const clamped = Math.max(0.02, Math.min(1, v));
        if (available) {
            const val = Math.round(clamped * max);
            raw = val;
            setter.command = ["brightnessctl", "-q", "set", String(val)];
            setter.running = true;
        } else {
            virtualValue = clamped;
        }
        Osd.show("brightness", "\uf185", Math.round(value * 100) + "%", value, "Brightness");
    }
    function step(d) { set(value + d); }
}
