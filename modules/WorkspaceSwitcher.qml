import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import qs.config
import qs.components
import qs.services

// Overview of workspaces with live window miniatures. Arrows / 1-0 / Enter or click to switch.
Variants {
    model: Quickshell.screens

    PanelOverlay {
        id: win
        required property var modelData
        screen: modelData
        name: "workspaces"
        property int sel: 0
        readonly property var mon: Hyprland.monitorFor(modelData)
        readonly property int current: mon?.activeWorkspace?.id ?? 1
        readonly property real monW: modelData?.width || 1920
        readonly property real monH: modelData?.height || 1080
        readonly property real monX: mon?.x ?? 0
        readonly property real monY: mon?.y ?? 0
        readonly property var winsByWs: {
            if (!win.visible) return ({});
            const map = {};
            for (const t of Hyprland.toplevels.values) {
                const id = t?.workspace?.id;
                if (id) {
                    if (!map[id]) map[id] = [];
                    map[id].push(t);
                }
            }
            return map;
        }

        function go(i) {
            Panels.switchWorkspace(i + 1);
        }

        onOpenChanged: {
            if (open) {
                Panels.refreshHypr();
                sel = Math.max(0, Math.min(9, current - 1));
                Qt.callLater(() => card.forceActiveFocus());
            }
        }

        PopupCard {
            id: card
            shown: win.open
            width: 5 * 236 + 4 * 12 + 40
            height: 2 * 184 + 12 + 56 + 38
            anchors.centerIn: parent
            slideY: 10
            focus: true
            Keys.onLeftPressed: win.sel = Math.max(0, win.sel - 1)
            Keys.onRightPressed: win.sel = Math.min(9, win.sel + 1)
            Keys.onUpPressed: win.sel = Math.max(0, win.sel - 5)
            Keys.onDownPressed: win.sel = Math.min(9, win.sel + 5)
            Keys.onReturnPressed: win.go(win.sel)
            Keys.onEnterPressed: win.go(win.sel)
            Keys.onEscapePressed: Panels.close()
            Keys.onPressed: e => {
                if (e.key >= Qt.Key_1 && e.key <= Qt.Key_9) { win.go(e.key - Qt.Key_1); e.accepted = true; }
                else if (e.key === Qt.Key_0) { win.go(9); e.accepted = true; }
            }

            Label { x: 20; y: 14; text: "Workspaces"; font.pixelSize: Theme.fsL; font.weight: Font.DemiBold }
            Grid {
                x: 20; y: 52
                columns: 5; spacing: 12
                Repeater {
                    model: 10
                    delegate: Rectangle {
                        id: ws
                        required property int index
                        readonly property int wsId: index + 1
                        readonly property bool hot: win.sel === index
                        readonly property var wins: win.winsByWs[wsId] ?? []
                        width: 236; height: 184
                        radius: Theme.radius
                        color: hot ? Theme.accentDim : Theme.surface2
                        border.width: win.current === wsId ? 2 : 1
                        border.color: win.current === wsId ? Theme.accent : (hot ? Theme.accentSoft : Theme.border)
                        scale: ma.pressed ? 0.97 : 1
                        Behavior on color { ColorAnimation { duration: Theme.animFast } }
                        Behavior on scale { NumberAnimation { duration: Theme.animFast } }
                        opacity: win.open ? 1 : 0
                        Behavior on opacity { SequentialAnimation { PauseAnimation { duration: win.open ? ws.index * 20 : 0 } NumberAnimation { duration: Theme.anim } } }

                        // Header: workspace number + window count
                        Label {
                            x: 12; y: 7
                            text: ws.wsId
                            font.pixelSize: Theme.fsM + 2
                            font.weight: Font.Bold
                            color: win.current === ws.wsId ? Theme.accent : Theme.text
                        }
                        Label {
                            anchors { right: parent.right; rightMargin: 12; top: parent.top; topMargin: 10 }
                            text: ws.wins.length + (ws.wins.length === 1 ? " window" : " windows")
                            color: Theme.subtext
                            font.pixelSize: Theme.fsS
                        }

                        // Workspace miniature screen
                        Rectangle {
                            id: previewBox
                            x: 10; y: 34
                            width: parent.width - 20
                            height: parent.height - 44
                            radius: Theme.radiusS
                            color: Theme.bg
                            border.width: 1
                            border.color: Theme.border
                            clip: true

                            // Wallpaper miniature backdrop
                            Image {
                                anchors.fill: parent
                                source: win.visible && Wallpaper.current ? "file://" + Wallpaper.current : ""
                                fillMode: Image.PreserveAspectCrop
                                sourceSize: Qt.size(240, 135)
                                asynchronous: true
                                cache: false
                                opacity: ws.wins.length > 0 ? 0.45 : 0.7
                            }

                            // Static window miniatures positioned proportionally (only active while switcher is open)
                            Repeater {
                                model: win.open ? ws.wins : []
                                delegate: Rectangle {
                                    id: miniWin
                                    required property var modelData
                                    required property int index
                                    readonly property var ipc: modelData.lastIpcObject
                                    readonly property bool hasGeom: ipc && ipc.at && ipc.size && ipc.size[0] > 0 && ipc.size[1] > 0
                                    readonly property int totalWins: Math.max(1, ws.wins.length)
                                    x: hasGeom
                                        ? Math.max(0, Math.min(previewBox.width - 24, ((ipc.at[0] - win.monX) / win.monW) * previewBox.width))
                                        : (index % 2) * (previewBox.width / Math.min(2, totalWins)) + 2
                                    y: hasGeom
                                        ? Math.max(0, Math.min(previewBox.height - 20, ((ipc.at[1] - win.monY) / win.monH) * previewBox.height))
                                        : Math.floor(index / 2) * (previewBox.height / Math.ceil(totalWins / 2)) + 2
                                    width: hasGeom
                                        ? Math.max(32, Math.min(previewBox.width - x, (ipc.size[0] / win.monW) * previewBox.width))
                                        : (previewBox.width / Math.min(2, totalWins)) - 4
                                    height: hasGeom
                                        ? Math.max(24, Math.min(previewBox.height - y, (ipc.size[1] / win.monH) * previewBox.height))
                                        : (previewBox.height / Math.ceil(totalWins / 2)) - 4
                                    radius: 4
                                    color: Theme.surface
                                    border.width: 1
                                    border.color: modelData.activated ? Theme.accent : Theme.border
                                    clip: true

                                    ScreencopyView {
                                        id: wsScv
                                        anchors.fill: parent
                                        anchors.margins: 1
                                        captureSource: win.open ? miniWin.modelData.wayland : null
                                        live: false
                                        constraintSize: Qt.size(220, 140)
                                    }

                                    // App icon + title pill at bottom of window miniature
                                    Rectangle {
                                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 2 }
                                        height: 16
                                        radius: 3
                                        color: "#aa000000"
                                        Row {
                                            anchors { fill: parent; leftMargin: 3; rightMargin: 3 }
                                            spacing: 3
                                            Image {
                                                width: 12; height: 12
                                                anchors.verticalCenter: parent.verticalCenter
                                                sourceSize: Qt.size(24, 24)
                                                source: Apps.iconFor(Apps.lookup(miniWin.ipc?.class ?? "")?.icon ?? miniWin.ipc?.class ?? "")
                                            }
                                            Label {
                                                width: parent.width - 18
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: miniWin.modelData.title || miniWin.ipc?.class || ""
                                                font.pixelSize: 9
                                                color: "white"
                                            }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                visible: ws.wins.length === 0
                                anchors.centerIn: parent
                                width: emptyLbl.implicitWidth + 16
                                height: 22
                                radius: 11
                                color: "#88000000"
                                Label {
                                    id: emptyLbl
                                    anchors.centerIn: parent
                                    text: "Empty"
                                    color: "white"
                                    opacity: 0.8
                                    font.pixelSize: Theme.fsS
                                }
                            }
                        }

                        MouseArea {
                            id: ma
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            property real lastX: -1
                            property real lastY: -1
                            onPositionChanged: m => {
                                if (lastX >= 0 && (Math.abs(m.x - lastX) > 1 || Math.abs(m.y - lastY) > 1))
                                    win.sel = ws.index;
                                lastX = m.x;
                                lastY = m.y;
                            }
                            onExited: { lastX = -1; lastY = -1; }
                            onClicked: {
                                win.sel = ws.index;
                                win.go(ws.index);
                            }
                        }
                    }
                }
            }
            Label { anchors { bottom: parent.bottom; bottomMargin: 10; horizontalCenter: parent.horizontalCenter } text: "Arrows or 1–0 to choose · Enter or Click to switch · Esc to close"; color: Theme.subtext; font.pixelSize: Theme.fsS }
        }
    }
}
