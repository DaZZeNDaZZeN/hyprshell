import Quickshell
import Quickshell.Hyprland
import QtQuick
import qs.config
import qs.components
import qs.services

// Ten persistent workspaces, 1-10. Active one is stretched and tinted with the accent.
Row {
    id: root
    property var screenObj
    readonly property var mon: Hyprland.monitorFor(screenObj)
    readonly property int activeId: mon?.activeWorkspace?.id ?? 1
    spacing: 4

    Repeater {
        model: 10
        delegate: Rectangle {
            id: cell
            required property int index
            readonly property int wsId: index + 1
            readonly property bool active: root.activeId === wsId
            readonly property bool occupied: Hyprland.toplevels.values.some(t => t.workspace && t.workspace.id === wsId)
            height: 22
            width: active ? 34 : 22
            radius: height / 2
            anchors.verticalCenter: parent.verticalCenter
            color: active ? Theme.accent : (ma.containsMouse ? Theme.surface3 : (occupied ? Theme.surface2 : "transparent"))
            border.width: active || occupied ? 0 : 1
            border.color: Theme.border
            Behavior on width { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
            Behavior on color { ColorAnimation { duration: Theme.anim } }
            Label {
                anchors.centerIn: parent
                text: cell.wsId
                font.pixelSize: Theme.fsS
                font.weight: cell.active ? Font.Bold : Font.Normal
                color: cell.active ? Theme.onAccent : (cell.occupied ? Theme.text : Theme.subtext)
            }
            MouseArea {
                id: ma
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Hyprland.dispatch("hl.dsp.focus({ workspace = " + cell.wsId + " })")
                onWheel: w => Hyprland.dispatch("hl.dsp.focus({ workspace = \"e" + (w.angleDelta.y > 0 ? "-1" : "+1") + "\" })")
            }
        }
    }
}
