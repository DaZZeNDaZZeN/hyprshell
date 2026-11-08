pragma Singleton

import Quickshell
import QtQuick
import qs.config

// State for the on-screen display popups.
Singleton {
    id: root
    property bool shown: false
    property string kind: ""     // volume | brightness | media | layout | caps | num | scroll
    property string icon: ""
    property string label: ""
    property string sub: ""
    property real value: -1      // 0..1, or -1 for no bar
    property bool on: true
    property bool armed: false

    Timer { interval: 2500; running: true; onTriggered: root.armed = true }
    Timer { id: hide; interval: Config.o.osdTimeout; onTriggered: root.shown = false }

    function kindAllowed(kind) {
        if (kind === "volume") return Config.o.osdVolume;
        if (kind === "mic") return Config.o.osdMic;
        if (kind === "brightness") return Config.o.osdBrightness;
        if (kind === "media") return Config.o.osdMedia;
        if (kind === "layout") return Config.o.osdLayout;
        if (kind === "caps" || kind === "num" || kind === "scroll") return Config.o.osdLockKeys;
        if (kind === "dnd") return Config.o.osdDnd;
        return true;
    }

    function show(kind, icon, label, value, sub, on) {
        if (!armed || !Config.o.osdEnabled || !kindAllowed(kind)) return;
        root.kind = kind; root.icon = icon; root.label = label;
        root.value = value ?? -1; root.sub = sub ?? ""; root.on = on ?? true;
        root.shown = true;
        hide.restart();
    }
}
