pragma Singleton

import Quickshell
import Quickshell.Bluetooth
import QtQuick
import qs.config

Singleton {
    id: root
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool available: adapter !== null
    readonly property bool on: adapter?.enabled ?? false
    readonly property var devices: adapter ? adapter.devices.values : []
    readonly property var connectedDevices: devices.filter(d => d.connected)
    readonly property bool connected: connectedDevices.length > 0
    function setOn(v) { if (adapter) adapter.enabled = v; }
    function scan(v) { if (adapter) adapter.discovering = v; }
    function deviceIcon(d) {
        const i = (d.icon || "").toLowerCase();
        if (i.includes("headset") || i.includes("headphone")) return "\uf025";
        if (i.includes("audio") || i.includes("speaker")) return "\uf028";
        if (i.includes("mouse")) return "\uf245";
        if (i.includes("keyboard")) return "\uf11c";
        if (i.includes("phone")) return "\uf10b";
        return "\uf293";
    }
}
