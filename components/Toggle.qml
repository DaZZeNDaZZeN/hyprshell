import QtQuick
import qs.config

// iOS-style switch.
Rectangle {
    id: root
    property bool checked: false
    signal toggled(bool value)
    implicitWidth: 44
    implicitHeight: 24
    radius: height / 2
    color: checked ? Theme.accent : Theme.surface3
    Behavior on color { ColorAnimation { duration: Theme.anim } }
    Rectangle {
        width: 18; height: 18; radius: 9
        y: 3
        x: root.checked ? parent.width - width - 3 : 3
        color: root.checked ? Theme.onAccent : Theme.text
        Behavior on x { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
        Behavior on color { ColorAnimation { duration: Theme.anim } }
    }
    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.toggled(!root.checked) }
}
