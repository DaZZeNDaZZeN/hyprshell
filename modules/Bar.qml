import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

Variants {
    model: Config.o.barEnabled ? Quickshell.screens.filter(s => Config.o.barMonitors === "all" || s === Quickshell.screens[0]) : []

    PanelWindow {
        id: win
        required property var modelData
        screen: modelData
        readonly property bool atTop: Config.o.barPosition !== "bottom"
        readonly property int gap: Config.o.barFloating ? 6 : 0
        readonly property bool autoHide: Config.o.barAutoHide
        property bool pointerInside: false
        readonly property bool hidden: autoHide && !pointerInside && !Panels.active
        anchors { left: true; right: true; top: atTop; bottom: !atTop }
        implicitHeight: Config.o.barHeight + gap * 2
        exclusionMode: autoHide ? ExclusionMode.Ignore : ExclusionMode.Auto
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "hyprshell-bar"
        color: "transparent"
        mask: Region { item: win.hidden ? trigger : bar }

        SystemClock { id: clock; precision: Config.o.barSeconds ? SystemClock.Seconds : SystemClock.Minutes }
        Timer { id: hideDelay; interval: 450; onTriggered: win.pointerInside = false }
        HoverHandler {
            onHoveredChanged: { if (hovered) { hideDelay.stop(); win.pointerInside = true; } else hideDelay.restart(); }
        }
        Item {
            id: trigger
            width: parent.width; height: 3
            anchors.top: win.atTop ? parent.top : undefined
            anchors.bottom: win.atTop ? undefined : parent.bottom
        }

        Component.onCompleted: if (modelData === Quickshell.screens[0]) Panels.registry["bar"] = { holder: bar }
        Rectangle {
            id: bar
            x: win.gap; width: parent.width - win.gap * 2
            height: Config.o.barHeight
            y: win.hidden ? (win.atTop ? -height - win.gap - 2 : win.height + 2) : (win.atTop ? win.gap : win.height - win.gap - height)
            Behavior on y { NumberAnimation { duration: Theme.animSlow; easing.type: Easing.OutQuint } }
            opacity: win.hidden ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: Theme.anim } }
            radius: Config.o.barFloating ? Theme.radius : 0
            color: Theme.panel
            border.width: Config.o.barFloating ? 1 : 0
            border.color: Theme.border

            // ---------- left ----------
            RowLayout {
                anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
                spacing: 6
                IconButton { glyph: "\uf00a"; size: 30; iconSize: 14; onClicked: Panels.toggle("launcher") }
                Workspaces { screenObj: win.screen }
                Label {
                    visible: Config.o.barShowTitle
                    Layout.maximumWidth: 280
                    Layout.leftMargin: 6
                    text: ToplevelManager.activeToplevel?.title ?? ""
                    color: Theme.subtext
                    font.pixelSize: Theme.fsS + 1
                }
            }

            // ---------- center ----------
            Row {
                anchors.centerIn: parent
                spacing: 12
                Rectangle {
                    height: 28; width: clockRow.implicitWidth + 24; radius: Theme.radiusS + 2
                    color: clockMa.containsMouse ? Theme.hover : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                    Row {
                        id: clockRow
                        anchors.centerIn: parent
                        spacing: 8
                        Label { text: Qt.formatDateTime(clock.date, "ddd d MMM"); color: Theme.subtext }
                        Label {
                            text: Qt.formatDateTime(clock.date, (Config.o.barClock24h ? "HH:mm" : "h:mm ap") + (Config.o.barSeconds ? ":ss" : ""))
                            font.weight: Font.DemiBold
                        }
                    }
                    MouseArea { id: clockMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Panels.toggle("notifications") }
                }
                Row {
                    visible: Config.o.barShowMedia && player !== null
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    readonly property var player: Mpris.players.values.find(p => p.isPlaying) ?? Mpris.players.values[0] ?? null
                    Icon { text: parent.player && parent.player.isPlaying ? "\uf001" : "\uf04c"; tint: Theme.accent; font.pixelSize: 12 }
                    Label {
                        width: Math.min(implicitWidth, 220)
                        text: parent.player ? (parent.player.trackArtist ? parent.player.trackArtist + " — " : "") + parent.player.trackTitle : ""
                        color: Theme.subtext
                        font.pixelSize: Theme.fsS + 1
                    }
                    TapHandler { onTapped: { const p = parent.player; if (p) p.togglePlaying(); } }
                }
            }

            // ---------- right ----------
            RowLayout {
                anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                spacing: 4

                Repeater {
                    model: Config.o.barShowTray ? SystemTray.items : []
                    delegate: Item {
                        id: trayItem
                        required property var modelData
                        Layout.preferredWidth: 26; Layout.preferredHeight: 26
                        IconImage { anchors.centerIn: parent; implicitSize: 18; source: trayItem.modelData.icon }
                        QsMenuAnchor {
                            id: menu
                            menu: trayItem.modelData.menu
                            anchor.item: trayItem
                            anchor.edges: win.atTop ? Edges.Bottom : Edges.Top
                            anchor.gravity: win.atTop ? Edges.Bottom : Edges.Top
                        }
                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: m => {
                                if (m.button === Qt.RightButton || trayItem.modelData.onlyMenu) { if (trayItem.modelData.hasMenu) menu.open(); }
                                else if (m.button === Qt.MiddleButton) trayItem.modelData.secondaryActivate();
                                else trayItem.modelData.activate();
                            }
                        }
                    }
                }

                Label {
                    visible: Config.o.barShowLayout && Keyboard.short !== ""
                    text: Keyboard.short
                    font.weight: Font.DemiBold
                    color: Theme.subtext
                    Layout.rightMargin: 4
                }

                // status cluster -> control center
                Rectangle {
                    Layout.preferredHeight: 28
                    Layout.preferredWidth: statusRow.implicitWidth + 20
                    radius: Theme.radiusS + 2
                    color: ccMa.containsMouse || Panels.active === "controlcenter" ? Theme.hover : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                    Row {
                        id: statusRow
                        anchors.centerIn: parent
                        spacing: 10
                        Icon { text: Network.ethernetUp && !Network.activeSsid ? "\uf0e8" : "\uf1eb"; font.pixelSize: 14; tint: Network.online ? Theme.text : Theme.subtext }
                        Icon { visible: Bt.on; text: "\uf293"; font.pixelSize: 14; tint: Bt.connected ? Theme.accent : Theme.text }
                        Icon { text: Audio.icon(Audio.volume, Audio.muted); font.pixelSize: 14; tint: Audio.muted ? Theme.subtext : Theme.text }
                        Row {
                            visible: UPower.displayDevice.isPresent
                            spacing: 5
                            Icon { text: UPower.displayDevice.state === UPowerDeviceState.Charging ? "\uf0e7" : "\uf240"; font.pixelSize: 14
                                tint: UPower.displayDevice.percentage < 0.2 && UPower.displayDevice.state !== UPowerDeviceState.Charging ? Theme.danger : Theme.text }
                            Label { text: Math.round(UPower.displayDevice.percentage * 100) + "%"; font.pixelSize: Theme.fsS + 1 }
                        }
                    }
                    MouseArea { id: ccMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Panels.toggle("controlcenter") }
                }

                Item {
                    Layout.preferredWidth: 30; Layout.preferredHeight: 30
                    IconButton { anchors.fill: parent; glyph: Notifs.dnd ? "\uf1f6" : "\uf0f3"; size: 30; iconSize: 14; onClicked: Panels.toggle("notifications") }
                    Rectangle {
                        visible: Notifs.count > 0
                        x: 17; y: 3; width: 9; height: 9; radius: 5; color: Theme.accent
                        border.width: 2; border.color: Theme.panel
                    }
                }
                IconButton { glyph: "\uf011"; size: 30; iconSize: 14; onClicked: Panels.toggle("session") }
            }
        }
    }

}
