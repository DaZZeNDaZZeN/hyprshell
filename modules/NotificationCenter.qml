import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

// Notification history / action center, slides in from the right.
Variants {
    model: Quickshell.screens

    PanelOverlay {
        id: win
        required property var modelData
        screen: modelData
        name: "notifications"
        scrimOpacity: 0.18

        PopupCard {
            id: card
            shown: win.open
            width: 410
            anchors { right: parent.right; top: parent.top; bottom: parent.bottom
                rightMargin: 10; bottomMargin: 10; topMargin: Config.o.barEnabled && Config.o.barPosition === "top" ? 54 : 10 }
            slideX: 60; slideY: 0

            ColumnLayout {
                anchors { fill: parent; margins: 14 }
                spacing: 10
                RowLayout {
                    Layout.fillWidth: true
                    Label { text: "Notifications"; font.pixelSize: Theme.fsL; font.weight: Font.DemiBold; Layout.fillWidth: true }
                    Row {
                        spacing: 6
                        Rectangle {
                            height: 32; width: dndRow.implicitWidth + 24; radius: 16
                            color: Notifs.dnd ? Theme.accent : Theme.surface2
                            Behavior on color { ColorAnimation { duration: Theme.anim } }
                            Row { id: dndRow; anchors.centerIn: parent; spacing: 6
                                Icon { text: "\uf1f6"; font.pixelSize: 12; tint: Notifs.dnd ? Theme.onAccent : Theme.text }
                                Label { text: "Do not disturb"; font.pixelSize: Theme.fsS + 1; color: Notifs.dnd ? Theme.onAccent : Theme.text } }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Notifs.setDnd(!Notifs.dnd) }
                        }
                        IconButton { glyph: "\uf1f8"; size: 32; iconSize: 13; baseColor: Theme.surface2; onClicked: Notifs.clearAll() }
                    }
                }
                ListView {
                    id: list
                    Layout.fillWidth: true; Layout.fillHeight: true
                    clip: true; spacing: 8
                    model: Notifs.items
                    boundsBehavior: Flickable.StopAtBounds
                    delegate: NotifCard { required property var modelData; notif: modelData; width: list.width }
                    add: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.anim } }
                    remove: Transition { NumberAnimation { property: "opacity"; to: 0; duration: Theme.animFast } }
                    displaced: Transition { NumberAnimation { properties: "y"; duration: Theme.anim; easing.type: Easing.OutCubic } }
                    Column {
                        anchors.centerIn: parent; spacing: 10; visible: Notifs.count === 0
                        Icon { anchors.horizontalCenter: parent.horizontalCenter; text: "\uf1f6"; font.pixelSize: 40; tint: Theme.subtext; opacity: 0.5 }
                        Label { text: "You're all caught up"; color: Theme.subtext }
                    }
                }
            }
        }
    }
}
