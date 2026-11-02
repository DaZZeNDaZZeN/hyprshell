import QtQuick
import qs.config

Rectangle {
    id: root
    property string text: ""
    property string glyph: ""
    property bool primary: false
    property bool danger: false
    signal clicked()
    implicitHeight: 34
    implicitWidth: row.implicitWidth + 28
    radius: Theme.radiusS + 2
    color: primary ? (ma.containsMouse ? Qt.lighter(Theme.accent, 1.1) : Theme.accent)
         : danger ? (ma.containsMouse ? Qt.lighter(Theme.danger, 1.1) : Theme.danger)
         : (ma.containsMouse ? Theme.surface3 : Theme.surface2)
    scale: ma.pressed ? 0.96 : 1
    Behavior on color { ColorAnimation { duration: Theme.animFast } }
    Behavior on scale { NumberAnimation { duration: Theme.animFast } }
    Row {
        id: row
        anchors.centerIn: parent
        spacing: 8
        Icon { visible: root.glyph !== ""; text: root.glyph; font.pixelSize: 14; tint: root.primary ? Theme.onAccent : (root.danger ? "#fff" : Theme.text) }
        Label { visible: root.text !== ""; text: root.text; color: root.primary ? Theme.onAccent : (root.danger ? "#fff" : Theme.text); font.weight: Font.Medium }
    }
    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.clicked() }
}
