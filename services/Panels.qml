pragma Singleton

import Quickshell
import Quickshell.Hyprland
import QtQuick
import qs.config

// Which overlay panel is open, and on which screen. Only one at a time.
Singleton {
    id: root
    property string active: ""
    property string screenName: ""
    property string page: ""
    property bool locked: false
    property var registry: ({})     // name -> window, used by the debug `grab` IPC
    function grab(name, file) {
        const w = registry[name];
        if (!w) return "no such window";
        (w.holder ?? w.grabItem).grabToImage(r => r.saveToFile(file));
        return "ok";
    }

    function focusedScreen() {
        const m = Hyprland.focusedMonitor;
        if (m) return m.name;
        return Quickshell.screens.length ? Quickshell.screens[0].name : "";
    }
    property real anchorX: -1
    function open(name, page) {
        anchorX = -1;
        screenName = focusedScreen();
        root.page = page ?? "";
        active = name;
    }
    function openAt(name, page, screen, x) {
        const targetScreen = screen || focusedScreen();
        if (active === name && screenName === targetScreen && anchorX >= 0 && Math.abs(anchorX - x) < 28) {
            close();
            return;
        }
        anchorX = x ?? -1;
        screenName = targetScreen;
        root.page = page ?? "";
        active = name;
    }
    property bool instantClose: false
    property var pendingWs: null

    function close() { instantClose = false; active = ""; }
    function closeImmediate() { instantClose = true; active = ""; instantClose = false; }
    function toggle(name, page) {
        if (active === name && screenName === focusedScreen()) close();
        else open(name, page);
    }
    function isOpen(name, screen) { return active === name && screenName === screen; }

    function dispatchWs(ws) {
        const arg = typeof ws === "number" ? String(ws) : ("\"" + String(ws) + "\"");
        Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({ workspace = " + arg + " })"]);
    }

    function switchWorkspace(ws) {
        if (root.active !== "") {
            root.pendingWs = ws;
            root.closeImmediate();
            wsSwitchTimer.restart();
        } else {
            root.dispatchWs(ws);
        }
    }

    Timer {
        id: wsSwitchTimer
        interval: 60
        onTriggered: {
            if (root.pendingWs !== null) {
                const target = root.pendingWs;
                root.pendingWs = null;
                root.dispatchWs(target);
            }
        }
    }

    function refreshHypr() {
        Hyprland.refreshMonitors();
        Hyprland.refreshWorkspaces();
        Hyprland.refreshToplevels();
    }

    Component.onCompleted: refreshHypr()

    Timer {
        id: refreshTimer
        interval: 80
        onTriggered: root.refreshHypr()
    }

    Connections {
        target: Hyprland
        function onRawEvent(ev) {
            const n = ev.name;
            if (n === "openwindow" || n === "closewindow" || n === "movewindow" || n === "movewindowv2"
                || n === "workspace" || n === "workspacev2" || n === "createworkspace" || n === "createworkspacev2"
                || n === "destroyworkspace" || n === "destroyworkspacev2" || n === "focusedmon") {
                refreshTimer.restart();
            }
        }
    }
}
