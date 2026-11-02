import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import qs.config
import qs.components
import qs.services

// Overview of all ten workspaces with their windows. Arrows / 1-0 / Enter to pick.
Variants {
    model: Quickshell.screens

    PanelOverlay {
        id: win
        required property var modelData
        screen: modelData
        name: "workspaces"
        property int sel: 0
        readonly property int current: Hyprland.monitorFor(modelData)?.activeWorkspace?.id ?? 1
        function go(i) { Panels.close(); Hyprland.dispatch("hl.dsp.focus({ workspace = " + (i + 1) + " })"); }
        onOpenChanged: if (open) sel = current - 1

        PopupCard {
            id: card
            shown: win.open
            width: 5 * 224 + 4 * 12 + 40
            height: 2 * 172 + 12 + 40 + 36
            anchors.centerIn: parent
            slideY: 10
            focus: win.open
            Keys.onLeftPressed: win.sel = Math.max(0, win.sel - 1)
            Keys.onRightPressed: win.sel = Math.min(9, win.sel + 1)
            Keys.onUpPressed: win.sel = Math.max(0, win.sel - 5)
            Keys.onDownPressed: win.sel = Math.min(9, win.sel + 5)
            Keys.onReturnPressed: win.go(win.sel)
            Keys.onPressed: e => {
                if (e.key >= Qt.Key_1 && e.key <= Qt.Key_9) win.go(e.key - Qt.Key_1);
                else if (e.key === Qt.Key_0) win.go(9);
            }

            Label { x: 20; y: 14; text: "Workspaces"; font.pixelSize: Theme.fsL; font.weight: Font.DemiBold }
            Grid {
                x: 20; y: 56
                columns: 5; spacing: 12
                Repeater {
                    model: 10
                    delegate: Rectangle {
                        id: ws
                        required property int index
                        readonly property int wsId: index + 1
                        readonly property bool hot: win.sel === index
                        readonly property var wins: Hyprland.toplevels.values.filter(t => t.workspace && t.workspace.id === wsId)
                        width: 224; height: 172
                        radius: Theme.radius
                        color: hot ? Theme.accentDim : Theme.surface2
                        border.width: win.current === wsId ? 2 : 1
                        border.color: win.current === wsId ? Theme.accent : (hot ? Theme.accentSoft : Theme.border)
                        scale: ma.pressed ? 0.97 : 1
                        Behavior on color { ColorAnimation { duration: Theme.animFast } }
                        Behavior on scale { NumberAnimation { duration: Theme.animFast } }
                        opacity: win.open ? 1 : 0
                        Behavior on opacity { SequentialAnimation { PauseAnimation { duration: win.open ? ws.index * 25 : 0 } NumberAnimation { duration: Theme.anim } } }

                        Label { x: 14; y: 10; text: ws.wsId; font.pixelSize: Theme.fsXL; font.weight: Font.Bold; color: win.current === ws.wsId ? Theme.accent : Theme.text }
                        Label { anchors { right: parent.right; rightMargin: 14; top: parent.top; topMargin: 18 } text: ws.wins.length + (ws.wins.length === 1 ? " window" : " windows"); color: Theme.subtext; font.pixelSize: Theme.fsS }
                        Column {
                            x: 14; y: 58; width: parent.width - 28; spacing: 5
                            Repeater {
                                model: ws.wins.slice(0, 4)
                                delegate: Row {
                                    required property var modelData
                                    spacing: 8; width: parent.width
                                    Image {
                                        width: 18; height: 18; sourceSize: Qt.size(36, 36)
                                        source: Apps.iconFor(Apps.lookup(modelData.lastIpcObject?.class ?? "")?.icon ?? modelData.lastIpcObject?.class ?? "")
                                    }
                                    Label { width: parent.width - 26; text: modelData.title || modelData.lastIpcObject?.class || ""; font.pixelSize: Theme.fsS + 1; color: Theme.subtext }
                                }
                            }
                            Label { visible: ws.wins.length === 0; text: "Empty"; color: Theme.subtext; opacity: 0.6; font.pixelSize: Theme.fsS + 1 }
                        }
                        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onEntered: win.sel = ws.index; onClicked: win.go(ws.index) }
                    }
                }
            }
            Label { anchors { bottom: parent.bottom; bottomMargin: 10; horizontalCenter: parent.horizontalCenter } text: "Arrows or 1–0 to choose · Enter to switch · Esc to close"; color: Theme.subtext; font.pixelSize: Theme.fsS }
        }
    }
}
