import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.config
import qs.components
import qs.services

// Desktop widgets layer: renders the active preset's widgets for the current wallpaper
// (automatically falling back to the "default" preset when a wallpaper has no preset assigned).
Variants {
    model: Config.o.widgetsEnabled ? Quickshell.screens.slice(0, 1) : []

    PanelWindow {
        id: win
        required property var modelData
        screen: modelData
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.namespace: "hyprshell-widgets"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        color: "transparent"

        Component.onCompleted: {
            Panels.registry["widgets"] = { holder: container };
        }

        Item {
            id: container
            anchors.fill: parent
            visible: Panels.active !== "widgeteditor"
            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.anim } }

            Repeater {
                model: win.visible && container.visible ? WidgetPresets.activeWidgets : []
                delegate: DesktopWidgetView {
                    required property var modelData
                    x: modelData.x ?? 40
                    y: modelData.y ?? 60
                    width: modelData.width ?? 300
                    height: modelData.height ?? 150
                    rotation: modelData.rotation ?? 0
                    widget: modelData
                    editMode: false
                }
            }
        }
    }
}
