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

    function show(kind, icon, label, value, sub, on) {
        if (!armed || !Config.o.osdEnabled) return;
        root.kind = kind; root.icon = icon; root.label = label;
        root.value = value ?? -1; root.sub = sub ?? ""; root.on = on ?? true;
        root.shown = true;
        hide.restart();
    }
}
