import QtQuick
import QtQuick.Layouts
import qs.config

// Title + description on the left, control on the right.
Item {
    id: root
    property string title: ""
    property string desc: ""
    default property alias control: slot.data
    Layout.fillWidth: true
    implicitHeight: Math.max(52, textCol.implicitHeight + 20)
    Column {
        id: textCol
        anchors { left: parent.left; right: slot.left; rightMargin: 16; verticalCenter: parent.verticalCenter }
        spacing: 2
        Label { width: parent.width; text: root.title; font.weight: Font.Medium }
        Label { width: parent.width; visible: root.desc !== ""; text: root.desc; color: Theme.subtext; font.pixelSize: Theme.fsS + 1; wrapMode: Text.Wrap; elide: Text.ElideNone }
    }
    Row {
        id: slot
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        spacing: 8
    }
    Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 1; color: Theme.border }
}
