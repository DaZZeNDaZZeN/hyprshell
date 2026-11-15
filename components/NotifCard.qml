import QtQuick
import qs.config
import qs.services

// One notification (used for popups and in the history list).
Rectangle {
    id: root
    required property var notif
    property bool popupMode: false
    readonly property var visibleActions: root.notif ? root.notif.actions.filter(a => a.id !== "default") : []
    implicitHeight: col.implicitHeight + 24
    height: implicitHeight
    radius: Theme.radius
    color: popupMode ? Theme.card : Theme.surface2
    border.width: 1
    border.color: (notif && notif.critical) ? Theme.danger : Theme.border
    clip: true

    function ago() {
        if (!notif || !notif.time) return "now";
        const s = Math.floor((Date.now() - notif.time.getTime()) / 1000);
        if (s < 60) return "now";
        if (s < 3600) return Math.floor(s / 60) + "m";
        if (s < 86400) return Math.floor(s / 3600) + "h";
        return Math.floor(s / 86400) + "d";
    }

    HoverHandler {
        enabled: root.popupMode
        onHoveredChanged: if (root.notif) root.notif.hovered = hovered
    }
    Column {
        id: col
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
        spacing: 8
        Item {
            width: parent.width
            implicitHeight: Math.max(40, textCol.implicitHeight)
            height: implicitHeight

            Item {
                id: iconBox
                x: 0; y: 0
                width: 40; height: 40
                Image {
                    id: iconImg
                    anchors.fill: parent
                    source: root.notif ? (root.notif.image ? root.notif.image : (root.notif.appIcon ? Apps.iconFor(root.notif.appIcon) : "")) : ""
                    sourceSize: Qt.size(80, 80); fillMode: Image.PreserveAspectFit; smooth: true
                    visible: status === Image.Ready
                }
                Icon { anchors.centerIn: parent; visible: !iconImg.visible; text: "\uf0f3"; font.pixelSize: 22; tint: Theme.accent }
            }

            Column {
                id: textCol
                anchors { left: iconBox.right; leftMargin: 10; right: closeBtn.left; rightMargin: 10; top: parent.top }
                spacing: 2

                Item {
                    width: parent.width
                    implicitHeight: Math.max(appLbl.implicitHeight, agoLbl.implicitHeight)
                    height: implicitHeight
                    Label {
                        id: appLbl
                        anchors { left: parent.left; right: agoLbl.left; rightMargin: 6; verticalCenter: parent.verticalCenter }
                        text: root.notif ? (root.notif.appName || "Notification") : ""
                        color: Theme.subtext
                        font.pixelSize: Theme.fsS
                        elide: Text.ElideRight
                    }
                    Label {
                        id: agoLbl
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        text: root.ago()
                        color: Theme.subtext
                        font.pixelSize: Theme.fsS
                    }
                }

                Label {
                    width: parent.width
                    visible: text !== ""
                    text: root.notif ? root.notif.summary : ""
                    font.weight: Font.DemiBold
                    wrapMode: Text.Wrap
                    elide: Text.ElideRight
                    maximumLineCount: 2
                }

                Text {
                    width: parent.width
                    visible: text !== ""
                    text: root.notif ? root.notif.body : ""
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
                id: closeBtn
                anchors { right: parent.right; top: parent.top }
                glyph: "\uf00d"; size: 24; iconSize: 11
                onClicked: if (root.notif) { root.popupMode ? Notifs.hidePopup(root.notif) : Notifs.dismiss(root.notif); }
            }
        }
        Flow {
            visible: root.notif !== null && root.notif.alive && root.visibleActions.length > 0
            width: parent.width; spacing: 6
            Repeater {
                model: root.visibleActions
                delegate: Rectangle {
                    required property var modelData
                    height: 28; width: Math.min(col.width, t.implicitWidth + 24); radius: Theme.radiusS
                    color: am.containsMouse ? Theme.accent : Theme.accentDim
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                    Label { id: t; width: Math.min(implicitWidth, parent.width - 16); anchors.centerIn: parent; text: parent.modelData.text; font.pixelSize: Theme.fsS + 1; color: am.containsMouse ? Theme.onAccent : Theme.text }
                    MouseArea { id: am; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (root.notif) root.notif.invoke(parent.modelData.id) }
                }
            }
        }
    }
    MouseArea {
        anchors.fill: parent; z: -1
        onClicked: if (root.notif) { root.notif.invoke("default"); if (root.popupMode) Notifs.hidePopup(root.notif); }
    }
}
