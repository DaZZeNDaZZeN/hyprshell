import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import qs.config
import qs.components
import qs.services

// Frozen-frame screenshot tool: drag to select a region, Enter/release to capture, Esc to cancel.
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win
        required property var modelData
        screen: modelData
        visible: Screenshot.active && Screenshot.screenName === modelData.name
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "hyprshell-screenshot"
        WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        property real sx: 0
        property real sy: 0
        property real ex: 0
        property real ey: 0
        property bool selecting: false
        readonly property real rx: Math.min(sx, ex)
        readonly property real ry: Math.min(sy, ey)
        readonly property real rw: Math.abs(ex - sx)
        readonly property real rh: Math.abs(ey - sy)
        property string outFile: ""

        function stamp() {
            const d = new Date(), p = n => ("0" + n).slice(-2);
            return d.getFullYear() + p(d.getMonth() + 1) + p(d.getDate()) + "-" + p(d.getHours()) + p(d.getMinutes()) + p(d.getSeconds());
        }
        function capture(region) {
            const dir = Config.home + "/Pictures/Screenshots";
            outFile = Screenshot.mode === "debug" ? "/tmp/hs-debug.png" : dir + "/screenshot-" + stamp() + ".png";
            view.grabToImage(res => {
                const tmp = "/tmp/hyprshell-full.png";
                res.saveToFile(tmp);
                Screenshot.cancel();
                const k = res.image.width / view.width;
                let cmd = "mkdir -p '" + dir + "' && ";
                if (region) cmd += "magick '" + tmp + "' -crop " + Math.round(rw * k) + "x" + Math.round(rh * k) + "+" + Math.round(rx * k) + "+" + Math.round(ry * k) + " +repage '" + outFile + "'";
                else cmd += "cp '" + tmp + "' '" + outFile + "'";
                if (Screenshot.mode === "debug") cmd += " && true"; else cmd += " && wl-copy --type image/png < '" + outFile + "' && notify-send -a Screenshot -i '" + outFile + "' 'Screenshot saved' '" + outFile + "'";
                Quickshell.execDetached(["sh", "-c", cmd]);
            });
        }

        onVisibleChanged: {
            if (!visible) return;
            selecting = false; sx = sy = ex = ey = 0;
            if (Screenshot.mode !== "region") grabDelay.restart();
        }
        Timer { id: grabDelay; interval: 250; onTriggered: win.capture(false) }

        FocusScope {
            anchors.fill: parent
            focus: win.visible
            Keys.onEscapePressed: Screenshot.cancel()
            Keys.onReturnPressed: if (win.rw > 4) win.capture(true)

            ScreencopyView {
                id: view
                anchors.fill: parent
                captureSource: win.modelData
                live: false
            }
            // dim everything outside the selection
            Rectangle { x: 0; y: 0; width: parent.width; height: win.selecting ? win.ry : parent.height; color: "#99000000" }
            Rectangle { x: 0; y: win.ry + win.rh; width: parent.width; height: win.selecting ? parent.height - win.ry - win.rh : 0; color: "#99000000" }
            Rectangle { x: 0; y: win.ry; width: win.rx; height: win.rh; color: "#99000000" }
            Rectangle { x: win.rx + win.rw; y: win.ry; width: win.selecting ? parent.width - win.rx - win.rw : 0; height: win.rh; color: "#99000000" }
            Rectangle {
                visible: win.selecting
                x: win.rx; y: win.ry; width: win.rw; height: win.rh
                color: "transparent"; border.width: 2; border.color: Theme.accent
            }
            Label {
                visible: win.selecting && win.rw > 0
                x: win.rx; y: Math.max(0, win.ry - 24)
                text: Math.round(win.rw) + " × " + Math.round(win.rh)
                color: "white"
            }
            Label {
                visible: !win.selecting && Screenshot.mode === "region"
                anchors.centerIn: parent
                text: "Drag to select an area  ·  Esc to cancel"
                color: "white"
                font.pixelSize: Theme.fsL
            }
            MouseArea {
                anchors.fill: parent
                enabled: Screenshot.mode === "region"
                cursorShape: Qt.CrossCursor
                onPressed: m => { win.sx = win.ex = m.x; win.sy = win.ey = m.y; win.selecting = true; }
                onPositionChanged: m => { if (pressed) { win.ex = m.x; win.ey = m.y; } }
                onReleased: if (win.rw > 4 && win.rh > 4) win.capture(true); else win.selecting = false
            }
        }
    }
}
