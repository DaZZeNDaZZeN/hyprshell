import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pam
import QtQuick
import QtQuick.Effects
import qs.config
import qs.components
import qs.services

// Lock screen: blurred wallpaper, clock, password prompt (PAM), caps lock indicator, keyboard layout switcher, and logout button.
Scope {
    id: root
    property string buffer: ""
    property string status: ""
    property bool busy: false
    property int shakeCount: 0

    function submit() {
        if (busy || buffer === "") return;
        busy = true;
        status = "";
        pam.start();
    }

    PamContext {
        id: pam
        configDirectory: Quickshell.shellDir + "/pam"
        config: "password.conf"
        onPamMessage: {
            if (responseRequired) respond(root.buffer);
        }
        onCompleted: result => {
            root.busy = false;
            if (result === PamResult.Success) {
                root.buffer = "";
                root.status = "";
                Panels.locked = false;
            } else {
                root.status = "Incorrect password";
                root.buffer = "";
                root.shakeCount++;
            }
        }
        onError: err => {
            root.busy = false;
            root.status = "Authentication error";
            root.buffer = "";
            root.shakeCount++;
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
            property bool kbMenuOpen: false

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
                    sourceSize: Qt.size(Math.max(1, surf.width), Math.max(1, surf.height))
                    cache: false
                    visible: false
                }
                MultiEffect { anchors.fill: parent; source: bgImg; blurEnabled: true; blurMax: 64; blur: 1.0; brightness: -0.12; saturation: -0.1 }
                Rectangle { anchors.fill: parent; color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.35) }

                SystemClock { id: clk; precision: SystemClock.Seconds }
                Column {
                    anchors { horizontalCenter: parent.horizontalCenter; verticalCenter: parent.verticalCenter; verticalCenterOffset: -90 }
                    spacing: 4
                    Label { anchors.horizontalCenter: parent.horizontalCenter; text: Qt.formatDateTime(clk.date, Config.o.barClock24h ? "HH:mm" : "h:mm"); font.pixelSize: 120; font.weight: Font.Light; color: "white" }
                    Label { anchors.horizontalCenter: parent.horizontalCenter; text: Qt.formatDateTime(clk.date, "dddd, d MMMM"); font.pixelSize: Theme.fsL + 2; color: "white"; opacity: 0.85 }
                }

                Rectangle {
                    id: box
                    anchors { horizontalCenter: parent.horizontalCenter; verticalCenter: parent.verticalCenter; verticalCenterOffset: 105 }
                    width: 340; height: 54; radius: height / 2
                    color: Theme.card
                    border.width: 2; border.color: root.status ? Theme.danger : (field.activeFocus ? Theme.accent : Theme.border)
                    Behavior on border.color { ColorAnimation { duration: Theme.anim } }
                    SequentialAnimation on anchors.horizontalCenterOffset {
                        id: shake
                        running: false
                        NumberAnimation { to: -14; duration: 50 } NumberAnimation { to: 14; duration: 80 }
                        NumberAnimation { to: -9; duration: 70 } NumberAnimation { to: 9; duration: 70 } NumberAnimation { to: 0; duration: 50 }
                    }
                    Connections { target: root; function onShakeCountChanged() { shake.restart(); field.forceActiveFocus(); } }
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
                        onTextEdited: { root.buffer = text; if (root.status) root.status = ""; }
                        onAccepted: root.submit()
                        Component.onCompleted: forceActiveFocus()
                        Text { visible: !field.text; text: "Password"; color: Theme.subtext; font: field.font; anchors.verticalCenter: parent.verticalCenter }
                    }
                    IconButton { anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter } glyph: "\uf061"; size: 38; iconSize: 14; active: root.buffer !== ""; onClicked: root.submit() }
                }

                // Status & Caps Lock indicator below password box
                Column {
                    anchors { horizontalCenter: parent.horizontalCenter; top: box.bottom; topMargin: 12 }
                    spacing: 8
                    Rectangle {
                        visible: Keyboard.caps
                        anchors.horizontalCenter: parent.horizontalCenter
                        height: 30; width: capsRow.implicitWidth + 24; radius: 15
                        color: Qt.rgba(Theme.warn.r, Theme.warn.g, Theme.warn.b, 0.22)
                        border.width: 1; border.color: Theme.warn
                        Row {
                            id: capsRow
                            anchors.centerIn: parent
                            spacing: 8
                            Icon { text: "\uf071"; font.pixelSize: 13; tint: Theme.warn }
                            Label { text: "Caps Lock is ON"; color: Theme.warn; font.pixelSize: Theme.fsS + 1; font.weight: Font.DemiBold }
                        }
                    }
                    Label {
                        visible: root.status !== ""
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.status
                        color: Theme.danger
                        font.pixelSize: Theme.fsM
                        font.weight: Font.Medium
                    }
                }

                // Bottom action bar: Keyboard layout selector & Logout button
                Row {
                    id: bottomBar
                    anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 36 }
                    spacing: 12

                    Rectangle {
                        id: lockKbBtn
                        height: 38
                        width: lockKbRow.implicitWidth + 28
                        radius: 19
                        color: surf.kbMenuOpen ? Theme.accent : (lockKbMa.containsMouse ? Theme.surface3 : Theme.card)
                        border.width: 1; border.color: Theme.border
                        Behavior on color { ColorAnimation { duration: Theme.animFast } }
                        Row {
                            id: lockKbRow
                            anchors.centerIn: parent
                            spacing: 8
                            Icon { text: "\uf11c"; font.pixelSize: 14; tint: surf.kbMenuOpen ? Theme.onAccent : Theme.accent }
                            Label {
                                text: Keyboard.layout || Keyboard.short || "US"
                                font.pixelSize: Theme.fsS + 1
                                font.weight: Font.Medium
                                color: surf.kbMenuOpen ? Theme.onAccent : Theme.text
                            }
                            Icon { text: surf.kbMenuOpen ? "\uf078" : "\uf077"; font.pixelSize: 10; tint: surf.kbMenuOpen ? Theme.onAccent : Theme.subtext }
                        }
                        MouseArea {
                            id: lockKbMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { Keyboard.refresh(); surf.kbMenuOpen = !surf.kbMenuOpen; field.forceActiveFocus(); }
                        }
                    }

                    Rectangle {
                        id: logoutBtn
                        height: 38
                        width: logoutRow.implicitWidth + 28
                        radius: 19
                        color: logoutMa.containsMouse ? Theme.danger : Theme.card
                        border.width: 1; border.color: logoutMa.containsMouse ? Theme.danger : Theme.border
                        Behavior on color { ColorAnimation { duration: Theme.animFast } }
                        Row {
                            id: logoutRow
                            anchors.centerIn: parent
                            spacing: 8
                            Icon { text: "\uf2f5"; font.pixelSize: 14; tint: logoutMa.containsMouse ? "#ffffff" : Theme.danger }
                            Label {
                                text: "Log out"
                                font.pixelSize: Theme.fsS + 1
                                font.weight: Font.Medium
                                color: logoutMa.containsMouse ? "#ffffff" : Theme.text
                            }
                        }
                        MouseArea {
                            id: logoutMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Actions.logout()
                        }
                    }
                }

                // Keyboard layout popup above bottomBar
                Rectangle {
                    visible: opacity > 0.01
                    opacity: surf.kbMenuOpen ? 1 : 0
                    scale: surf.kbMenuOpen ? 1 : 0.94
                    Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
                    Behavior on scale { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }
                    width: 200
                    height: lockKbCol.implicitHeight + 12
                    anchors { bottom: bottomBar.top; bottomMargin: 10; horizontalCenter: parent.horizontalCenter; horizontalCenterOffset: -55 }
                    radius: Theme.radius
                    color: Theme.card
                    border.width: 1; border.color: Theme.border

                    Column {
                        id: lockKbCol
                        anchors { fill: parent; margins: 6 }
                        spacing: 2
                        Repeater {
                            model: Keyboard.layouts
                            delegate: Rectangle {
                                required property var modelData
                                readonly property bool active: modelData.index === Keyboard.activeIndex
                                width: lockKbCol.width; height: 34; radius: Theme.radiusS
                                color: active ? Theme.accent : (lkbm.containsMouse ? Theme.hover : "transparent")
                                Row {
                                    x: 10; anchors.verticalCenter: parent.verticalCenter; spacing: 10
                                    Label { text: modelData.code; font.weight: Font.Bold; font.pixelSize: Theme.fsS + 1; color: active ? Theme.onAccent : Theme.accent; width: 26 }
                                    Label { text: modelData.name; font.pixelSize: Theme.fsS + 1; color: active ? Theme.onAccent : Theme.text }
                                }
                                MouseArea {
                                    id: lkbm
                                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: { Keyboard.setLayout(modelData.index); surf.kbMenuOpen = false; field.forceActiveFocus(); }
                                }
                            }
                        }
                    }
                }

                MouseArea { anchors.fill: parent; z: -1; onClicked: { surf.kbMenuOpen = false; field.forceActiveFocus(); } }
            }
        }
    }
}
