import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pam
import QtQuick
import QtQuick.Effects
import qs.config
import qs.components
import qs.services

// Lock screen: blurred wallpaper, clock, password prompt (PAM). Matches the desktop theme.
Scope {
    id: root
    property string buffer: ""
    property string status: ""
    property bool failed: false
    property bool busy: false
    property int shakeCount: 0

    function submit() {
        if (busy || buffer === "") return;
        busy = true; status = "";
        pam.start();
    }
    PamContext {
        id: pam
        configDirectory: Quickshell.shellDir + "/pam"
        config: "password.conf"
        onPamMessage: { if (responseRequired) respond(root.buffer); }
        onCompleted: result => {
            root.busy = false;
            if (result === PamResult.Success) { root.buffer = ""; root.status = ""; Panels.locked = false; }
            else { root.status = "Incorrect password"; root.buffer = ""; root.shakeCount++; }
        }
    }

    // Developer safety net: HYPRSHELL_LOCKTEST=1 auto-unlocks after 6 s.
    Timer { running: Panels.locked && Quickshell.env("HYPRSHELL_LOCKTEST") === "1"; interval: 6000; onTriggered: Panels.locked = false }

    WlSessionLock {
        id: lock
        locked: Panels.locked

        WlSessionLockSurface {
            id: surf
            color: "black"

            Item {
                id: content
                anchors.fill: parent
                opacity: 0
                Component.onCompleted: { opacity = 1; Panels.registry["lock"] = { holder: content }; }
                Behavior on opacity { NumberAnimation { duration: Theme.animSlow * 1.5; easing.type: Easing.OutCubic } }

                Image {
                    id: bgImg
                    anchors.fill: parent
                    source: Wallpaper.current ? "file://" + Wallpaper.current : ""
                    fillMode: Image.PreserveAspectCrop
                    sourceSize: Qt.size(surf.width, surf.height)
                    visible: false
                }
                MultiEffect { anchors.fill: parent; source: bgImg; blurEnabled: true; blurMax: 64; blur: 1.0; brightness: -0.12; saturation: -0.1 }
                Rectangle { anchors.fill: parent; color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.35) }

                SystemClock { id: clk; precision: SystemClock.Seconds }
                Column {
                    anchors { horizontalCenter: parent.horizontalCenter; verticalCenter: parent.verticalCenter; verticalCenterOffset: -80 }
                    spacing: 4
                    Label { anchors.horizontalCenter: parent.horizontalCenter; text: Qt.formatDateTime(clk.date, Config.o.barClock24h ? "HH:mm" : "h:mm"); font.pixelSize: 120; font.weight: Font.Light; color: "white" }
                    Label { anchors.horizontalCenter: parent.horizontalCenter; text: Qt.formatDateTime(clk.date, "dddd, d MMMM"); font.pixelSize: Theme.fsL + 2; color: "white"; opacity: 0.85 }
                }

                Rectangle {
                    id: box
                    anchors { horizontalCenter: parent.horizontalCenter; verticalCenter: parent.verticalCenter; verticalCenterOffset: 120 }
                    width: 330; height: 54; radius: height / 2
                    color: Theme.card
                    border.width: 2; border.color: root.status ? Theme.danger : (field.activeFocus ? Theme.accent : Theme.border)
                    Behavior on border.color { ColorAnimation { duration: Theme.anim } }
                    SequentialAnimation on anchors.horizontalCenterOffset {
                        id: shake
                        running: false
                        NumberAnimation { to: -14; duration: 50 } NumberAnimation { to: 14; duration: 80 }
                        NumberAnimation { to: -9; duration: 70 } NumberAnimation { to: 9; duration: 70 } NumberAnimation { to: 0; duration: 50 }
                    }
                    Connections { target: root; function onShakeCountChanged() { shake.restart(); } }
                    Icon { x: 20; anchors.verticalCenter: parent.verticalCenter; text: root.busy ? "\uf110" : "\uf023"; tint: Theme.accent; font.pixelSize: 16 }
                    TextInput {
                        id: field
                        anchors { left: parent.left; leftMargin: 52; right: parent.right; rightMargin: 52; verticalCenter: parent.verticalCenter }
                        echoMode: TextInput.Password
                        passwordCharacter: "•"
                        color: Theme.text
                        font.family: Theme.font; font.pixelSize: Theme.fsL
                        focus: true
                        enabled: !root.busy
                        text: root.buffer
                        onTextEdited: root.buffer = text
                        onAccepted: root.submit()
                        Component.onCompleted: forceActiveFocus()
                        Text { visible: !field.text; text: "Password"; color: Theme.subtext; font: field.font; anchors.verticalCenter: parent.verticalCenter }
                    }
                    IconButton { anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter } glyph: "\uf061"; size: 38; iconSize: 14; active: root.buffer !== ""; onClicked: root.submit() }
                }
                Label { anchors { horizontalCenter: parent.horizontalCenter; top: box.bottom; topMargin: 14 } text: root.status; color: Theme.danger; font.pixelSize: Theme.fsM }
                MouseArea { anchors.fill: parent; z: -1; onClicked: field.forceActiveFocus() }
            }
        }
    }
}
