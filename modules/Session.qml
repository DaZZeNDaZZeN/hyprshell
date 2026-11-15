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
            { label: "Lock", pre: "", hk: "L", post: "ock", glyph: "\uf023", key: Qt.Key_L, scan: 46, run: () => Actions.lock() },
            { label: "Logout", pre: "L", hk: "o", post: "gout", glyph: "\uf2f5", key: Qt.Key_O, scan: 32, run: () => Actions.logout() },
            { label: "Suspend", pre: "", hk: "S", post: "uspend", glyph: "\uf186", key: Qt.Key_S, scan: 39, run: () => Actions.suspend() },
            { label: "Reboot", pre: "", hk: "R", post: "eboot", glyph: "\uf021", key: Qt.Key_R, scan: 27, run: () => Actions.reboot() },
            { label: "Power off", pre: "", hk: "P", post: "ower off", glyph: "\uf011", key: Qt.Key_P, scan: 33, run: () => Actions.poweroff(), danger: true },
        ]
        function go(i) {
            if (i < 0 || i >= items.length) return;
            Panels.close();
            items[i].run();
        }
        onOpenChanged: {
            if (open) {
                sel = 0;
                Qt.callLater(() => card.forceActiveFocus());
            }
        }

        PopupCard {
            id: card
            shown: win.open
            width: row.implicitWidth + 40
            height: 190
            anchors.centerIn: parent
            slideY: 0
            focus: true
            Keys.onLeftPressed: win.sel = Math.max(0, win.sel - 1)
            Keys.onRightPressed: win.sel = Math.min(win.items.length - 1, win.sel + 1)
            Keys.onReturnPressed: win.go(win.sel)
            Keys.onEnterPressed: win.go(win.sel)
            Keys.onEscapePressed: Panels.close()
            Keys.onPressed: e => {
                if (e.key >= Qt.Key_1 && e.key <= Qt.Key_5) {
                    win.go(e.key - Qt.Key_1);
                    e.accepted = true;
                    return;
                }
                for (let i = 0; i < win.items.length; i++) {
                    if (e.key === win.items[i].key || e.nativeScanCode === win.items[i].scan) {
                        win.go(i);
                        e.accepted = true;
                        return;
                    }
                }
            }

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
                        readonly property color keyColor: modelData.danger ? Theme.danger : Theme.accent
                        width: 112; height: 130
                        radius: Theme.radius
                        color: hot
                            ? (modelData.danger ? Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.22) : Theme.accentDim)
                            : Theme.surface2
                        border.width: hot ? 2 : 1
                        border.color: hot ? tile.keyColor : Theme.border
                        scale: ma.pressed ? 0.95 : (hot ? 1.04 : 1)
                        Behavior on color { ColorAnimation { duration: Theme.anim } }
                        Behavior on border.color { ColorAnimation { duration: Theme.animFast } }
                        Behavior on scale { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutBack } }
                        // staggered entrance
                        opacity: win.open ? 1 : 0
                        Behavior on opacity { SequentialAnimation { PauseAnimation { duration: win.open ? tile.index * 40 : 0 } NumberAnimation { duration: Theme.anim } } }

                        Label {
                            anchors { left: parent.left; top: parent.top; leftMargin: 10; topMargin: 7 }
                            text: String(tile.index + 1)
                            font.pixelSize: Theme.fsS
                            font.weight: Font.DemiBold
                            color: tile.hot ? tile.keyColor : Theme.subtext
                            opacity: tile.hot ? 0.75 : 0.4
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: 14
                            Icon {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: tile.modelData.glyph
                                font.pixelSize: 34
                                tint: tile.hot ? tile.keyColor : Theme.text
                            }
                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 0
                                Label {
                                    visible: tile.modelData.pre !== ""
                                    text: tile.modelData.pre
                                    font.weight: Font.Medium
                                    color: Theme.text
                                }
                                Label {
                                    text: tile.modelData.hk
                                    font.weight: Font.Bold
                                    color: tile.keyColor
                                }
                                Label {
                                    visible: tile.modelData.post !== ""
                                    text: tile.modelData.post
                                    font.weight: Font.Medium
                                    color: Theme.text
                                }
                            }
                        }
                        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onEntered: win.sel = tile.index; onClicked: win.go(tile.index) }
                    }
                }
            }
        }
    }
}
