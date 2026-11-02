import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import qs.config
import qs.components
import qs.services

// Toast notifications. Each card slides/fades in and collapses away.
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win
        required property var modelData
        screen: modelData
        readonly property bool mine: Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name === modelData.name : modelData === Quickshell.screens[0]
        readonly property bool right: Config.o.notifPosition.endsWith("right")
        readonly property bool top: Config.o.notifPosition.startsWith("top")
        anchors { top: win.top; bottom: !win.top; right: win.right; left: !win.right }
        implicitWidth: 392
        implicitHeight: Math.max(1, stack.height + 12)
        margins { top: Config.o.barEnabled && Config.o.barPosition === "top" && win.top ? 52 : 8; bottom: 8; right: 8; left: 8 }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        visible: stack.height > 1
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "hyprshell-notifications"
        mask: Region { item: stack }

        Column {
            id: stack
            width: 376
            x: win.right ? parent.width - width - 4 : 4
            y: win.top ? 0 : undefined
            anchors.bottom: win.top ? undefined : parent.bottom
            spacing: 0
            Repeater {
                model: win.mine ? Notifs.items.slice(0, 8) : []
                delegate: Item {
                    id: slot
                    required property var modelData
                    readonly property bool show: modelData.popup && sawMe
                    property bool sawMe: false
                    width: stack.width
                    height: show ? card.height + 10 : 0
                    clip: true
                    opacity: show ? 1 : 0
                    visible: height > 0.5
                    Component.onCompleted: sawMe = true
                    Behavior on height { NumberAnimation { duration: Theme.animSlow; easing.type: Easing.OutQuint } }
                    Behavior on opacity { NumberAnimation { duration: Theme.anim } }
                    NotifCard {
                        id: card
                        notif: slot.modelData
                        popupMode: true
                        width: parent.width
                        height: implicitHeight
                        x: slot.show ? 0 : (win.right ? 60 : -60)
                        Behavior on x { NumberAnimation { duration: Theme.animSlow; easing.type: Easing.OutQuint } }
                    }
                }
            }
        }
    }
}
