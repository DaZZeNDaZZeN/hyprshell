pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs.config

// Screen recording through wf-recorder / gpu-screen-recorder / wl-screenrec (whichever is installed).
Singleton {
    id: root
    property bool recording: false
    property string tool: ""
    property string file: ""

    Process {
        running: true
        command: ["sh", "-c", "for t in wf-recorder wl-screenrec gpu-screen-recorder; do command -v $t >/dev/null && echo $t && break; done"]
        stdout: StdioCollector { onStreamFinished: root.tool = text.trim() }
    }
    Process {
        id: rec
        onRunningChanged: if (!running && root.recording) { root.recording = false; Quickshell.execDetached(["notify-send", "-a", "Screen Recorder", "Recording saved", root.file]); }
    }
    function toggle() {
        if (recording) { rec.signal(2); return; }
        if (!tool) {
            Quickshell.execDetached(["notify-send", "-a", "Screen Recorder", "No recorder installed",
                "Install one: sudo pacman -S wf-recorder"]);
            return;
        }
        const d = new Date(), pad = n => ("0" + n).slice(-2);
        const name = "recording-" + d.getFullYear() + pad(d.getMonth() + 1) + pad(d.getDate()) + "-" + pad(d.getHours()) + pad(d.getMinutes()) + pad(d.getSeconds()) + ".mp4";
        file = Config.home + "/Videos/Recordings/" + name;
        let cmd = "mkdir -p ~/Videos/Recordings && ";
        if (tool === "wf-recorder") cmd += "exec wf-recorder -f '" + file + "'";
        else if (tool === "wl-screenrec") cmd += "exec wl-screenrec -f '" + file + "'";
        else cmd += "exec gpu-screen-recorder -w screen -f 60 -o '" + file + "'";
        rec.command = ["sh", "-c", cmd];
        rec.running = true;
        recording = true;
    }
}
