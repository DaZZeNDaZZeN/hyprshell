import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services

// One notification (used for popups and in the history list).
Rectangle {
    id: root
    required property var notif
    property bool popupMode: false
    implicitHeight: col.implicitHeight + 24
    radius: Theme.radius
    color: popupMode ? Theme.card : Theme.surface2
    border.width: 1
    border.color: notif.critical ? Theme.danger : Theme.border

    function ago() {
        const s = Math.floor((Date.now() - notif.time.getTime()) / 1000);
        if (s < 60) return "now";
        if (s < 3600) return Math.floor(s / 60) + "m";
        if (s < 86400) return Math.floor(s / 3600) + "h";
        return Math.floor(s / 86400) + "d";
    }

    HoverHandler { onHoveredChanged: root.notif.hovered = hovered }
    Column {
        id: col
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
        spacing: 8
        RowLayout {
            width: parent.width
            spacing: 10
            Item {
                Layout.preferredWidth: 40; Layout.preferredHeight: 40; Layout.alignment: Qt.AlignTop
                Image {
                    anchors.fill: parent
                    source: root.notif.image ? root.notif.image : (root.notif.appIcon ? Apps.iconFor(root.notif.appIcon) : "")
                    sourceSize: Qt.size(80, 80); fillMode: Image.PreserveAspectFit; smooth: true
                    visible: status === Image.Ready
                }
                Icon { anchors.centerIn: parent; visible: !root.notif.image && !root.notif.appIcon; text: "\uf0f3"; font.pixelSize: 22; tint: Theme.accent }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                RowLayout {
                    Layout.fillWidth: true
                    Label { text: root.notif.appName; color: Theme.subtext; font.pixelSize: Theme.fsS; Layout.fillWidth: true }
                    Label { text: root.ago(); color: Theme.subtext; font.pixelSize: Theme.fsS }
                }
                Label { Layout.fillWidth: true; text: root.notif.summary; font.weight: Font.DemiBold; wrapMode: Text.Wrap; elide: Text.ElideNone; maximumLineCount: 2 }
                Text {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: root.notif.body
                    textFormat: Text.StyledText
                    wrapMode: Text.Wrap
                    maximumLineCount: root.popupMode ? 4 : 6
                    elide: Text.ElideRight
                    color: Theme.subtext
                    font.family: Theme.font
                    font.pixelSize: Theme.fsM - 1
                }
            }
            IconButton {
                Layout.alignment: Qt.AlignTop
                glyph: "\uf00d"; size: 24; iconSize: 11
                onClicked: root.popupMode ? Notifs.hidePopup(root.notif) : Notifs.dismiss(root.notif)
            }
        }
        Flow {
            visible: root.notif.alive && root.notif.actions.filter(a => a.id !== "default").length > 0
            width: parent.width; spacing: 6
            Repeater {
                model: root.notif.actions.filter(a => a.id !== "default")
                delegate: Rectangle {
                    required property var modelData
                    height: 28; width: t.implicitWidth + 24; radius: Theme.radiusS
                    color: am.containsMouse ? Theme.accent : Theme.accentDim
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                    Label { id: t; anchors.centerIn: parent; text: parent.modelData.text; font.pixelSize: Theme.fsS + 1; color: am.containsMouse ? Theme.onAccent : Theme.text }
                    MouseArea { id: am; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.notif.invoke(parent.modelData.id) }
                }
            }
        }
    }
    MouseArea {
        anchors.fill: parent; z: -1
        onClicked: { root.notif.invoke("default"); if (root.popupMode) Notifs.hidePopup(root.notif); }
    }
}
