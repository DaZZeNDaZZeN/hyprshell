pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs.config

// Wi-Fi / Ethernet through NetworkManager's nmcli.
Singleton {
    id: root
    property bool wifiEnabled: false
    property var networks: []           // {ssid, signal, secure, active}
    property string activeSsid: ""
    property int activeSignal: 0
    property string wifiDevice: ""
    property bool ethernetUp: false
    property string ethernetName: ""
    property bool scanning: false
    property string error: ""
    property bool wanted: false         // set by UI when Wi-Fi page is visible
    readonly property bool online: ethernetUp || activeSsid !== ""

    function icon() {
        if (ethernetUp && activeSsid === "") return "\uf0e8";
        if (!wifiEnabled) return "\uf1eb";
        return "\uf1eb";
    }

    function refresh() { devs.running = true; radio.running = true; if (wanted && wifiEnabled) scan(false); }
    function scan(rescan) {
        if (scanning) return;
        scanning = true;
        list.command = ["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "dev", "wifi", "list", "--rescan", rescan ? "yes" : "auto"];
        list.running = true;
    }
    function setWifi(on) { runner.command = ["nmcli", "radio", "wifi", on ? "on" : "off"]; runner.running = true; wifiEnabled = on; }
    function connect(ssid, password) {
        error = "";
        const c = ["nmcli", "dev", "wifi", "connect", ssid];
        if (password) c.push("password", password);
        connector.command = c; connector.running = true;
    }
    function disconnectActive() {
        if (root.wifiDevice) {
            runner.command = ["nmcli", "dev", "disconnect", root.wifiDevice];
            runner.running = true;
        }
    }

    Process { id: runner; onExited: refreshTimer.restart() }
    Process {
        id: connector
        stderr: StdioCollector { onStreamFinished: if (text.trim()) root.error = text.trim() }
        onExited: code => { if (code === 0) root.error = ""; refreshTimer.restart(); }
    }
    Process {
        id: radio
        command: ["nmcli", "radio", "wifi"]
        stdout: StdioCollector { onStreamFinished: root.wifiEnabled = text.trim() === "enabled" }
    }
    Process {
        id: devs
        command: ["nmcli", "-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "dev"]
        stdout: StdioCollector {
            onStreamFinished: {
                let eth = false, name = "", wifiSsid = "", wifiDev = "";
                for (const l of text.trim().split("\n")) {
                    const p = l.split(":");
                    if (p[1] === "ethernet" && p[2] === "connected") { eth = true; name = p[3] || ""; }
                    else if (p[1] === "wifi") {
                        if (!wifiDev) wifiDev = p[0] || "";
                        if (p[2] === "connected") wifiSsid = p[3] || "";
                    }
                }
                root.wifiDevice = wifiDev;
                root.ethernetUp = eth; root.ethernetName = name;
                if (!root.wanted) root.activeSsid = wifiSsid;
            }
        }
    }
    Process {
        id: list
        stdout: StdioCollector {
            onStreamFinished: {
                const seen = {}, out = [];
                let act = "", sig = 0;
                for (const l of text.trim().split("\n")) {
                    if (!l) continue;
                    const m = l.match(/^([* ]):((?:\\:|[^:])*):(\d*):(.*)$/);
                    if (!m) continue;
                    const ssid = m[2].replace(/\\:/g, ":");
                    if (!ssid) continue;
                    const n = { ssid: ssid, signal: parseInt(m[3]) || 0, secure: m[4] !== "" && m[4] !== "--", active: m[1] === "*" };
                    if (n.active) { act = ssid; sig = n.signal; }
                    if (seen[ssid] === undefined) { seen[ssid] = out.length; out.push(n); }
                    else if (out[seen[ssid]].signal < n.signal || n.active) out[seen[ssid]] = n;
                }
                out.sort((a, b) => (b.active - a.active) || (b.signal - a.signal));
                root.networks = out; root.activeSsid = act; root.activeSignal = sig;
                root.scanning = false;
            }
        }
        onExited: root.scanning = false
    }
    Process {
        id: monitor
        running: true
        command: ["nmcli", "monitor"]
        stdout: SplitParser {
            onRead: line => {
                if (line && !line.includes("Networkmanager is now")) refreshTimer.restart();
            }
        }
    }
    Component.onCompleted: refresh()
    Timer { id: refreshTimer; interval: 400; onTriggered: root.refresh() }
    Timer { interval: 15000; running: root.wanted; repeat: true; onTriggered: root.refresh() }
}
