import QtQuick
import qs.config
import qs.services

// Accent-coloured slider. value is 0..1 (or 0..max).
Item {
    id: root
    property real value: 0
    property real max: 1
    property int trackHeight: 8
    property real step: (Config.o.sliderScrollStep || 3) / 100
    property bool customScroll: false
    property bool volumeSlider: false
    property bool scaleVolumeSound: false
    signal moved(real value)
    signal released()
    signal scrolled(int dir)
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
        property bool dragging: false
        property real lastVal: root.value
        function upd(m) {
            lastVal = Math.max(0, Math.min(1, m.x / Math.max(1, width))) * root.max;
            root.moved(lastVal);
        }
        onPressed: m => {
            if (root.volumeSlider && !dragging) {
                dragging = true;
                Audio.beginSliderDrag();
            }
            upd(m);
        }
        onPositionChanged: m => { if (pressed) upd(m); }
        onReleased: {
            if (dragging) {
                dragging = false;
                Audio.endSliderDrag(true, root.scaleVolumeSound ? lastVal : 1.0);
            }
            root.released();
        }
        onCanceled: {
            if (dragging) {
                dragging = false;
                Audio.endSliderDrag(false);
            }
        }
        Component.onDestruction: {
            if (dragging) {
                dragging = false;
                Audio.endSliderDrag(false);
            }
        }
        onWheel: w => {
            const dir = w.angleDelta.y > 0 ? 1 : (w.angleDelta.y < 0 ? -1 : 0);
            if (dir === 0) return;
            if (root.customScroll) {
                root.scrolled(dir);
                return;
            }
            const stepFrac = root.step > 0 ? root.step : ((Config.o.sliderScrollStep || 3) / 100);
            const nextVal = Math.max(0, Math.min(root.max, root.value + dir * stepFrac * root.max));
            root.moved(nextVal);
            if (root.volumeSlider) Audio.playVolumeSound(root.scaleVolumeSound ? nextVal : 1.0);
        }
    }
}
