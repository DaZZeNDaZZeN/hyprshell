import QtQuick
import qs.config

// Toggle chip / segmented option.
Rectangle {
    id: root
    property string text: ""
    property string glyph: ""
    property bool active: false
    signal clicked()
    implicitHeight: 32
    implicitWidth: row.implicitWidth + 24
    radius: height / 2
    color: active ? Theme.accent : (ma.containsMouse ? Theme.surface3 : Theme.surface2)
    scale: ma.pressed ? 0.95 : 1
    Behavior on color { ColorAnimation { duration: Theme.anim } }
    Behavior on scale { NumberAnimation { duration: Theme.animFast } }
    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6
        Icon { visible: root.glyph !== ""; text: root.glyph; font.pixelSize: 12; tint: root.active ? Theme.onAccent : Theme.text }
        Label { text: root.text; font.pixelSize: Theme.fsS + 1; color: root.active ? Theme.onAccent : Theme.text }
    }
    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.clicked() }
}
