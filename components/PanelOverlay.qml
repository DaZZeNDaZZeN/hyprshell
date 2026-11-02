import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.config
import qs.services

// Full-screen transparent layer that hosts one animated popup panel.
// Clicking the scrim or pressing Escape closes it.
PanelWindow {
    id: win
    required property string name
    readonly property string targetScreenName: modelData ? modelData.name : (screen ? screen.name : "")
    property bool open: Panels.active === name && Panels.screenName === targetScreenName
    property real scrimOpacity: 0.28
    property bool grabKeyboard: true
    default property alias content: holder.data
    readonly property alias holder: holder

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: open || closing.running
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "hyprshell-" + name
    WlrLayershell.keyboardFocus: open && grabKeyboard ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Component.onCompleted: { if (screen && screen.name === Quickshell.screens[0].name) Panels.registry[name] = win; }
    Timer { id: closing; interval: Theme.animSlow + 80 }
    onOpenChanged: if (!open) { if (Panels.instantClose) closing.stop(); else closing.restart(); }

    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: win.open ? win.scrimOpacity : 0
        Behavior on opacity { NumberAnimation { duration: Theme.anim } }
        MouseArea { anchors.fill: parent; onClicked: Panels.close() }
    }
    FocusScope {
        id: holder
        anchors.fill: parent
        focus: win.open
        Keys.onEscapePressed: Panels.close()
    }
}
