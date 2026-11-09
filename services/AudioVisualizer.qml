pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs.config
import qs.services

// Real-time 32-band audio spectrum service for the Audio Visualizer desktop widget.
Singleton {
    id: root
    property int users: 0
    readonly property bool active: users > 0 && (Config.o.widgetsEnabled || Panels.active === "widgeteditor")
    property var bands: [
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    ]
    property real _lastRealUpdate: 0
    property real _phase: 0

    Process {
        id: visProc
        running: root.active
        command: ["python3", Quickshell.shellDir + "/scripts/visualizer.py"]
        stdout: SplitParser {
            onRead: line => {
                try {
                    const arr = JSON.parse(line);
                    if (Array.isArray(arr) && arr.length > 0) {
                        const maxV = Math.max(...arr);
                        if (maxV > 0.01) root._lastRealUpdate = Date.now();
                        root.bands = arr;
                    }
                } catch (e) {}
            }
        }
    }

    // Fallback synthesis when media is playing on a sink without PCM monitor output or when previewing in Widget Editor
    readonly property bool useSynth: root.active && (Date.now() - root._lastRealUpdate > 600)
        && ((Media.playing && !Audio.muted) || Panels.active === "widgeteditor")

    Timer {
        interval: 36
        repeat: true
        running: root.useSynth
        onTriggered: {
            root._phase += 0.16;
            const p = root._phase;
            const amp = (Media.playing && !Audio.muted) ? Math.max(0.25, Math.min(1.0, Media.volume)) : 0.45;
            const out = [];
            for (let i = 0; i < 32; i++) {
                const x = i / 31;
                const env = Math.sin(x * Math.PI) * 0.75 + 0.25;
                const w1 = Math.sin(p * 1.9 + i * 0.45) * 0.5 + 0.5;
                const w2 = Math.sin(p * 3.1 - i * 0.28) * 0.5 + 0.5;
                const w3 = Math.cos(p * 1.1 + i * 0.7) * 0.5 + 0.5;
                const v = Math.min(1.0, Math.max(0.04, (w1 * 0.45 + w2 * 0.35 + w3 * 0.2) * env * amp));
                out.push(Math.round(v * 1000) / 1000);
            }
            root.bands = out;
        }
        onRunningChanged: {
            if (!running && Date.now() - root._lastRealUpdate > 600) {
                root.bands = new Array(32).fill(0);
            }
        }
    }
}
