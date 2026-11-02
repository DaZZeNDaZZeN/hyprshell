import QtQuick
import qs.config

// Animated surface used by every panel (fade + scale + slide).
Rectangle {
    id: root
    property bool shown: false
    property real slideY: 16
    property real slideX: 0
    property point origin: Qt.point(width / 2, 0)
    color: Theme.card
    radius: Theme.radiusL
    border.width: 1
    border.color: Theme.border
    opacity: shown ? 1 : 0
    scale: shown ? 1 : 0.94
    transformOrigin: Item.Center
    transform: Translate {
        y: root.shown ? 0 : root.slideY
        x: root.shown ? 0 : root.slideX
        Behavior on y { NumberAnimation { duration: Theme.animSlow; easing.type: Easing.OutQuint } }
        Behavior on x { NumberAnimation { duration: Theme.animSlow; easing.type: Easing.OutQuint } }
    }
    Behavior on opacity { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: Theme.animSlow; easing.type: Easing.OutQuint } }
    // swallow clicks so the scrim doesn't close the panel
    MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onWheel: w => w.accepted = true }
}
