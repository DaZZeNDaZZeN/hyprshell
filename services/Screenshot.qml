pragma Singleton

import Quickshell
import QtQuick
import qs.config

// State machine for the screenshot tool; the capture UI lives in modules/ScreenshotOverlay.qml.
Singleton {
    id: root
    property bool active: false
    property string mode: "region"     // region | screen
    property string screenName: ""

    function start(mode) {
        root.mode = mode ?? "region";
        root.screenName = Panels.focusedScreen();
        if (mode !== "debug") Panels.close();
        delay.restart();     // let panel close animations finish so they are not captured
    }
    function cancel() { active = false; }
    Timer { id: delay; interval: 380; onTriggered: root.active = true }
}
