import Quickshell
import Quickshell.Hyprland
import QtQuick
import qs.config
import qs.components
import qs.services

// Persistent workspaces 1-10, plus any existing workspace > 10. Active one is stretched and tinted with the accent.
Item {
    id: root
    property var screenObj
    readonly property var mon: Hyprland.monitorFor(screenObj)
    readonly property int activeId: mon?.activeWorkspace?.id ?? 1
    readonly property var occupiedMap: {
        const map = {};
        for (const t of Hyprland.toplevels.values) {
            if (t && t.workspace && typeof t.workspace.id === "number") {
                map[t.workspace.id] = true;
            }
        }
        return map;
    }
    readonly property var wsList: {
        const ids = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
        const add = id => {
            if (typeof id === "number" && id > 10 && !ids.includes(id)) ids.push(id);
        };
        add(root.activeId);
        for (const w of Hyprland.workspaces.values) if (w) add(w.id);
        for (const k in root.occupiedMap) add( Number(k) );
        ids.sort((a, b) => a - b);
        return ids;
    }
    implicitWidth: row.implicitWidth
    implicitHeight: 22

    // Catch wheel events in the spaces between workspace buttons (within the 22px button band)
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: w => Panels.switchWorkspace(w.angleDelta.y > 0 ? "e-1" : "e+1")
    }

    Row {
        id: row
        height: parent.height
        spacing: 4

        Repeater {
            model: root.wsList
            delegate: Rectangle {
                id: cell
                required property var modelData
                readonly property int wsId: modelData
                readonly property bool active: root.activeId === wsId
                readonly property bool occupied: !!root.occupiedMap[wsId]
                height: 22
                width: active ? 34 : (wsId >= 10 ? 24 : 22)
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
                    onClicked: Panels.switchWorkspace(cell.wsId)
                    onWheel: w => Panels.switchWorkspace(w.angleDelta.y > 0 ? "e-1" : "e+1")
                }
            }
        }
    }
}
