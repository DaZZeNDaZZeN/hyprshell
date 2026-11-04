import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import qs.config
import qs.components
import qs.services

// Volume / brightness / media / layout / lock-key popups.
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win
        required property var modelData
        screen: modelData
        readonly property bool mine: Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name === modelData.name : modelData === Quickshell.screens[0]
        readonly property bool shown: Osd.shown && mine
        anchors { bottom: true }
        margins.bottom: 110
        implicitWidth: 420
        implicitHeight: 84
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        visible: shown || fade.running
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "hyprshell-osd"
        mask: Region {}
        Timer { id: fade; interval: Theme.animSlow + 50 }
        onShownChanged: if (!shown) fade.restart()

        Rectangle {
            id: pill
            anchors.centerIn: parent
            width: Osd.value >= 0
                ? 320
                : Math.min(380, Math.max(180, Math.max(txt.implicitWidth, subLbl.visible ? subLbl.implicitWidth : 0) + 96))
            Behavior on width { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }
            height: 64
            radius: Theme.radiusL
            color: Theme.card
            border.width: 1
            border.color: Theme.border
            clip: true
            opacity: win.shown ? 1 : 0
            scale: win.shown ? 1 : 0.9
            transform: Translate { y: win.shown ? 0 : 14; Behavior on y { NumberAnimation { duration: Theme.animSlow; easing.type: Easing.OutQuint } } }
            Behavior on opacity { NumberAnimation { duration: Theme.anim } }
            Behavior on scale { NumberAnimation { duration: Theme.animSlow; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }

            Rectangle {
                id: badge
                x: 10; anchors.verticalCenter: parent.verticalCenter
                width: 44; height: 44; radius: Theme.radius
                color: Osd.on ? Theme.accent : Theme.surface3
                Behavior on color { ColorAnimation { duration: Theme.anim } }
                Icon { anchors.centerIn: parent; text: Osd.icon; font.pixelSize: 20; tint: Osd.on ? Theme.onAccent : Theme.text }
            }
            Column {
                anchors { left: badge.right; leftMargin: 14; right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                spacing: 4
                Row {
                    width: parent.width
                    spacing: 6
                    Label {
                        id: txt
                        text: Osd.sub !== "" && Osd.value >= 0 ? Osd.sub : Osd.label
                        font.weight: Font.DemiBold
                        width: Osd.value >= 0 ? parent.width - pct.implicitWidth - 6 : parent.width
                    }
                    Label { id: pct; visible: Osd.value >= 0; text: Osd.label; color: Theme.subtext }
                }
                Label {
                    id: subLbl
                    visible: Osd.value < 0 && Osd.sub !== ""
                    width: parent.width
                    text: Osd.sub
                    color: Theme.subtext
                    font.pixelSize: Theme.fsS + 1
                }
                Rectangle {
                    visible: Osd.value >= 0
                    width: parent.width; height: 6; radius: 3; color: Theme.surface3
                    Rectangle {
                        width: parent.width * Math.max(0, Math.min(1, Osd.value)); height: parent.height; radius: 3; color: Theme.accent
                        Behavior on width { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
                    }
                }
            }
        }
    }
}
