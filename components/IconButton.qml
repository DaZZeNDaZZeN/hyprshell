import QtQuick
import qs.config

// Round/rounded icon button with hover + press animation.
Rectangle {
    id: root
    property string glyph: ""
    property bool active: false
    property int size: 36
    property int iconSize: 16
    property string tooltip: ""
    property color baseColor: "transparent"
    signal clicked(var mouse)
    signal rightClicked()

    implicitWidth: size
    implicitHeight: size
    radius: Math.min(Theme.radius, size / 2)
    color: active ? Theme.accent : (ma.containsMouse ? Theme.hover : baseColor)
    scale: ma.pressed ? 0.92 : 1
    Behavior on color { ColorAnimation { duration: Theme.animFast } }
    Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }

    Icon {
        anchors.centerIn: parent
        text: root.glyph
        font.pixelSize: root.iconSize
        tint: root.active ? Theme.onAccent : Theme.text
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: m => m.button === Qt.RightButton ? root.rightClicked() : root.clicked(m)
    }
}
