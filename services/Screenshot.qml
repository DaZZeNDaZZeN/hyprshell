pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs.config

// State machine for the screenshot tool; captures fresh screen frame via grim before showing region selector.
Singleton {
    id: root
    property bool active: false
    property string mode: "region"     // region | screen
    property string screenName: ""
    property int freezeId: 0
    readonly property string freezeFile: "/tmp/hyprshell-freeze.png"

    function stamp() {
        const d = new Date(), p = n => ("0" + n).slice(-2);
        return d.getFullYear() + p(d.getMonth() + 1) + p(d.getDate()) + "-" + p(d.getHours()) + p(d.getMinutes()) + p(d.getSeconds());
    }

    function start(mode) {
        root.mode = mode ?? "region";
        root.screenName = Panels.focusedScreen();
        const hadPanel = Panels.active !== "" && mode !== "debug";
        if (hadPanel) Panels.close();
        delay.interval = hadPanel ? 320 : 20;
        delay.restart();
    }

    function cancel() { active = false; }

    Timer {
        id: delay
        interval: 20
        onTriggered: {
            if (!freezeProc.running) freezeProc.running = true;
        }
    }

    Process {
        id: freezeProc
        command: root.screenName
            ? ["grim", "-o", root.screenName, root.freezeFile]
            : ["grim", root.freezeFile]
        onExited: (code) => {
            if (code !== 0) return;
            root.freezeId++;
            if (root.mode === "region") {
                root.active = true;
            } else {
                const dir = Config.home + "/Pictures/Screenshots";
                const outFile = root.mode === "debug" ? "/tmp/hs-debug.png" : (dir + "/screenshot-" + root.stamp() + ".png");
                let cmd = "mkdir -p '" + dir + "' && cp '" + root.freezeFile + "' '" + outFile + "'";
                if (root.mode !== "debug") {
                    cmd += " && wl-copy --type image/png < '" + outFile + "' && notify-send -a Screenshot -i '" + outFile + "' 'Screenshot saved' '" + outFile + "'";
                }
                Quickshell.execDetached(["sh", "-c", cmd]);
            }
        }
    }
}
