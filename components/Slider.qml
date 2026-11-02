import QtQuick
import qs.config

// Accent-coloured slider. value is 0..1 (or 0..max).
Item {
    id: root
    property real value: 0
    property real max: 1
    property int trackHeight: 8
    signal moved(real value)
    implicitHeight: 24
    implicitWidth: 160

    readonly property real frac: Math.max(0, Math.min(1, value / max))
    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: root.trackHeight
        radius: height / 2
        color: Theme.surface3
        Rectangle {
            width: Math.max(height, parent.width * root.frac)
            height: parent.height
            radius: height / 2
            color: Theme.accent
            Behavior on width { enabled: !ma.pressed; NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
        }
    }
    Rectangle {
        x: (root.width - width) * root.frac
        anchors.verticalCenter: parent.verticalCenter
        width: ma.pressed ? 20 : (ma.containsMouse ? 18 : 14)
        height: width
        radius: width / 2
        color: Theme.text
        Behavior on width { NumberAnimation { duration: Theme.animFast } }
        Behavior on x { enabled: !ma.pressed; NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        function upd(m) { root.moved(Math.max(0, Math.min(1, m.x / width)) * root.max); }
        onPressed: m => upd(m)
        onPositionChanged: m => { if (pressed) upd(m); }
        onWheel: w => root.moved(Math.max(0, Math.min(root.max, root.value + (w.angleDelta.y > 0 ? 0.03 : -0.03) * root.max)))
    }
}
