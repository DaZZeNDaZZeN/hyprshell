import Quickshell
import QtQuick
import qs.config
import qs.components
import qs.services

// Power / session manager: Lock, Logout, Suspend, Reboot, Power off.
Variants {
    model: Quickshell.screens

    PanelOverlay {
        id: win
        required property var modelData
        screen: modelData
        name: "session"
        scrimOpacity: 0.5
        property int sel: 0
        readonly property var items: [
            { label: "Lock", glyph: "\uf023", key: Qt.Key_L, run: () => Actions.lock() },
            { label: "Logout", glyph: "\uf2f5", key: Qt.Key_O, run: () => Actions.logout() },
            { label: "Suspend", glyph: "\uf186", key: Qt.Key_S, run: () => Actions.suspend() },
            { label: "Reboot", glyph: "\uf021", key: Qt.Key_R, run: () => Actions.reboot() },
            { label: "Power off", glyph: "\uf011", key: Qt.Key_P, run: () => Actions.poweroff(), danger: true },
        ]
        function go(i) { Panels.close(); items[i].run(); }
        onOpenChanged: if (open) sel = 0

        PopupCard {
            shown: win.open
            width: row.implicitWidth + 40
            height: 190
            anchors.centerIn: parent
            slideY: 0
            focus: win.open
            Keys.onLeftPressed: win.sel = Math.max(0, win.sel - 1)
            Keys.onRightPressed: win.sel = Math.min(win.items.length - 1, win.sel + 1)
            Keys.onReturnPressed: win.go(win.sel)
            Keys.onPressed: e => { for (let i = 0; i < win.items.length; i++) if (e.key === win.items[i].key) win.go(i); }

            Row {
                id: row
                anchors.centerIn: parent
                spacing: 14
                Repeater {
                    model: win.items
                    delegate: Rectangle {
                        id: tile
                        required property var modelData
                        required property int index
                        readonly property bool hot: win.sel === index
                        width: 112; height: 130
                        radius: Theme.radius
                        color: hot ? (modelData.danger ? Theme.danger : Theme.accent) : Theme.surface2
                        scale: ma.pressed ? 0.95 : (hot ? 1.04 : 1)
                        Behavior on color { ColorAnimation { duration: Theme.anim } }
                        Behavior on scale { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutBack } }
                        // staggered entrance
                        opacity: win.open ? 1 : 0
                        Behavior on opacity { SequentialAnimation { PauseAnimation { duration: win.open ? tile.index * 40 : 0 } NumberAnimation { duration: Theme.anim } } }
                        Column {
                            anchors.centerIn: parent
                            spacing: 14
                            Icon { anchors.horizontalCenter: parent.horizontalCenter; text: tile.modelData.glyph; font.pixelSize: 34; tint: tile.hot ? (tile.modelData.danger ? "#fff" : Theme.onAccent) : Theme.text }
                            Label { anchors.horizontalCenter: parent.horizontalCenter; text: tile.modelData.label; font.weight: Font.Medium; color: tile.hot ? (tile.modelData.danger ? "#fff" : Theme.onAccent) : Theme.text }
                        }
                        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onEntered: win.sel = tile.index; onClicked: win.go(tile.index) }
                    }
                }
            }
        }
    }
}
