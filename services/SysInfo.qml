pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs.config

Singleton {
    id: root
    property real cpu: 0
    property real mem: 0
    property real memUsedGb: 0
    property real memTotalGb: 0
    property real disk: 0
    property real temp: -1
    property int users: 0           // consumers bump this to enable polling
    property var _prev: null

    FileView { id: stat; path: "/proc/stat"; onLoaded: {
        const p = text().split("\n")[0].trim().split(/\s+/).slice(1).map(Number);
        const idle = p[3] + p[4], total = p.reduce((a, b) => a + b, 0);
        if (root._prev) {
            const dt = total - root._prev.total, di = idle - root._prev.idle;
            root.cpu = dt > 0 ? 1 - di / dt : 0;
        }
        root._prev = { idle: idle, total: total };
    } }
    FileView { id: meminfo; path: "/proc/meminfo"; onLoaded: {
        const t = text();
        const tot = parseInt(t.match(/MemTotal:\s+(\d+)/)[1]), av = parseInt(t.match(/MemAvailable:\s+(\d+)/)[1]);
        root.mem = 1 - av / tot; root.memTotalGb = tot / 1048576; root.memUsedGb = (tot - av) / 1048576;
    } }
    FileView { id: therm; path: "/sys/class/thermal/thermal_zone0/temp"; printErrors: false; onLoaded: root.temp = parseInt(text()) / 1000 }
    Process {
        id: df
        command: ["sh", "-c", "df -B1 --output=used,size / | tail -n1"]
        stdout: StdioCollector { onStreamFinished: { const p = text.trim().split(/\s+/).map(Number); if (p[1]) root.disk = p[0] / p[1]; } }
    }
    Timer { interval: 2000; repeat: true; running: root.users > 0; triggeredOnStart: true
        onTriggered: { stat.reload(); meminfo.reload(); therm.reload(); } }
    Timer { interval: 60000; repeat: true; running: root.users > 0; triggeredOnStart: true; onTriggered: df.running = true }
}
