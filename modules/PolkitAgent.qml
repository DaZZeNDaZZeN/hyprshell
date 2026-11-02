import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Polkit
import QtQuick
import qs.config
import qs.components
import qs.services

// Polkit authentication agent with a themed password dialog.
Scope {
    id: root
    PolkitAgent { id: agent }
    readonly property var flow: agent.flow

    Variants {
        model: Quickshell.screens.slice(0, 1)
        PanelWindow {
            id: win
            required property var modelData
            screen: modelData
            readonly property bool open: agent.isActive
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            visible: open || closing.running
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "hyprshell-polkit"
            WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            Timer { id: closing; interval: Theme.animSlow + 80 }
            onOpenChanged: { if (!open) closing.restart(); else { pw.text = ""; pw.forceActiveFocus(); } }

            Rectangle { anchors.fill: parent; color: "black"; opacity: win.open ? 0.5 : 0; Behavior on opacity { NumberAnimation { duration: Theme.anim } } }
            PopupCard {
                shown: win.open
                width: 440; height: col.implicitHeight + 40
                anchors.centerIn: parent
                slideY: 0
                Column {
                    id: col
                    x: 20; y: 20; width: parent.width - 40; spacing: 14
                    Row {
                        spacing: 12
                        Rectangle { width: 44; height: 44; radius: Theme.radius; color: Theme.accent
                            Icon { anchors.centerIn: parent; text: "\uf023"; font.pixelSize: 20; tint: Theme.onAccent } }
                        Column { anchors.verticalCenter: parent.verticalCenter
                            Label { text: "Authentication required"; font.pixelSize: Theme.fsL; font.weight: Font.DemiBold }
                            Label { text: root.flow?.identities?.length ? "as " + (root.flow.selectedIdentity?.displayName ?? "administrator") : ""; color: Theme.subtext; font.pixelSize: Theme.fsS } }
                    }
                    Label { width: parent.width; text: root.flow?.message ?? ""; wrapMode: Text.Wrap; elide: Text.ElideNone; color: Theme.subtext }
                    TextField {
                        id: pw
                        width: parent.width
                        echoMode: (root.flow?.responseVisible ?? false) ? TextInput.Normal : TextInput.Password
                        placeholder: (root.flow?.inputPrompt ?? "Password").replace(/:\s*$/, "")
                        onAccepted: { if (root.flow) root.flow.submit(text); text = ""; }
                        input.Keys.onEscapePressed: if (root.flow) root.flow.cancelAuthenticationRequest()
                    }
                    Label { visible: text !== ""; width: parent.width; text: root.flow?.supplementaryMessage ?? ""; color: (root.flow?.supplementaryIsError ?? false) ? Theme.danger : Theme.subtext; font.pixelSize: Theme.fsS + 1; wrapMode: Text.Wrap }
                    Label { visible: root.flow?.failed ?? false; text: "Authentication failed. Try again."; color: Theme.danger; font.pixelSize: Theme.fsS + 1 }
                    Row {
                        anchors.right: parent.right; spacing: 8
                        Button { text: "Cancel"; onClicked: if (root.flow) root.flow.cancelAuthenticationRequest() }
                        Button { text: "Authenticate"; primary: true; onClicked: { if (root.flow) root.flow.submit(pw.text); pw.text = ""; } }
                    }
                }
            }
        }
    }
}
