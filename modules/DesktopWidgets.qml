import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

// Desktop widgets: clock, weather, system monitor, media, app links. Sits above the wallpaper.
Variants {
    model: Config.o.widgetsEnabled ? Quickshell.screens.slice(0, 1) : []

    PanelWindow {
        id: win
        required property var modelData
        screen: modelData
        readonly property string pos: Config.o.widgetsPosition
        anchors {
            top: pos.startsWith("top")
            bottom: pos.startsWith("bottom")
            left: pos.startsWith("left") || pos.endsWith("-left")
            right: pos.startsWith("right") || pos.endsWith("-right")
        }
        margins {
            top: anchors.top ? 60 : 0
            bottom: anchors.bottom ? 90 : 0
            left: anchors.left ? 40 : 0
            right: anchors.right ? 40 : 0
        }
        implicitWidth: col.implicitWidth + 4
        implicitHeight: col.implicitHeight + 4
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.namespace: "hyprshell-widgets"
        color: "transparent"

        Component.onCompleted: { SysInfo.users++; Weather.users++; Panels.registry["widgets"] = { holder: col }; }
        Component.onDestruction: { SysInfo.users--; Weather.users--; }
        SystemClock { id: clock; precision: SystemClock.Minutes }
        readonly property bool alignRight: pos.startsWith("right") || pos.endsWith("-right")

        component Widget: Rectangle {
            default property alias body: inner.data
            implicitWidth: 300
            radius: Theme.radiusL
            color: Theme.widgetsPanel
            border.width: 1; border.color: Theme.border
            opacity: 0; scale: 0.96
            Component.onCompleted: { opacity = 1; scale = 1; }
            Behavior on opacity { NumberAnimation { duration: Theme.animSlow } }
            Behavior on scale { NumberAnimation { duration: Theme.animSlow; easing.type: Easing.OutQuint } }
            Item { id: inner; anchors.fill: parent }
        }

        ColumnLayout {
            id: col
            spacing: 12
            anchors.margins: 2
            x: 2; y: 2

            // clock
            Widget {
                visible: Config.o.widgetClock
                Layout.fillWidth: true; implicitHeight: 150
                Column {
                    anchors.centerIn: parent; spacing: 0
                    Label { anchors.horizontalCenter: parent.horizontalCenter; text: Qt.formatDateTime(clock.date, Config.o.barClock24h ? "HH:mm" : "h:mm"); font.pixelSize: Theme.fsHuge; font.weight: Font.Light }
                    Label { anchors.horizontalCenter: parent.horizontalCenter; text: Qt.formatDateTime(clock.date, "dddd, d MMMM"); color: Theme.accent; font.pixelSize: Theme.fsM + 1 }
                }
            }
            // weather
            Widget {
                visible: Config.o.widgetWeather
                Layout.fillWidth: true; implicitHeight: 120
                Icon { x: 20; y: 18; text: Weather.icon(Weather.code); font.pixelSize: 40; tint: Theme.accent }
                Column {
                    x: 84; y: 16
                    Label { text: Weather.ok ? Weather.t(Weather.tempC) + Weather.unit : "—"; font.pixelSize: Theme.fsXL; font.weight: Font.DemiBold }
                    Label { text: Weather.ok ? Weather.desc : "Weather unavailable"; color: Theme.subtext; font.pixelSize: Theme.fsS + 1; width: 190 }
                    Label { text: Weather.place; color: Theme.subtext; font.pixelSize: Theme.fsS; width: 190 }
                }
                Row {
                    anchors { bottom: parent.bottom; bottomMargin: 10; horizontalCenter: parent.horizontalCenter }
                    spacing: 18
                    Repeater {
                        model: Weather.days
                        delegate: Row { required property var modelData; spacing: 5
                            Icon { text: Weather.icon(modelData.code); font.pixelSize: 11; tint: Theme.subtext }
                            Label { text: Qt.formatDate(new Date(modelData.date), "ddd") + " " + Weather.t(modelData.max) + "°"; font.pixelSize: Theme.fsS; color: Theme.subtext } }
                    }
                }
            }
            // system
            Widget {
                visible: Config.o.widgetSystem
                Layout.fillWidth: true; implicitHeight: 136
                Column {
                    x: 18; y: 14; width: parent.width - 36; spacing: 10
                    Repeater {
                        model: [
                            { n: "CPU", v: SysInfo.cpu, t: Math.round(SysInfo.cpu * 100) + "%" },
                            { n: "RAM", v: SysInfo.mem, t: SysInfo.memUsedGb.toFixed(1) + " / " + SysInfo.memTotalGb.toFixed(1) + " GB" },
                            { n: "Disk", v: SysInfo.disk, t: Math.round(SysInfo.disk * 100) + "%" },
                        ]
                        delegate: Item { required property var modelData; width: parent.width; height: 26
                            Label { text: modelData.n; width: 40; font.pixelSize: Theme.fsS + 1; color: Theme.subtext }
                            Rectangle { x: 46; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 46 - 100; height: 8; radius: 4; color: Theme.surface3
                                Rectangle { width: parent.width * Math.max(0.02, modelData.v); height: parent.height; radius: 4; color: Theme.accent
                                    Behavior on width { NumberAnimation { duration: Theme.anim * 2; easing.type: Easing.OutCubic } } } }
                            Label { anchors.right: parent.right; text: modelData.t; font.pixelSize: Theme.fsS; color: Theme.subtext } }
                    }
                }
            }
            // media
            Widget {
                id: dwMedia
                readonly property int pagerOffset: Media.count > 1 ? 28 : 0
                visible: Config.o.widgetMedia && Media.player !== null
                Layout.fillWidth: true; implicitHeight: 152 + pagerOffset
                RowLayout {
                    visible: Media.count > 1
                    x: 12; y: 8; width: parent.width - 24; height: 22
                    spacing: 4
                    IconButton { glyph: "\uf053"; size: 20; iconSize: 9; onClicked: Media.prevPlayer() }
                    Row {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 4
                        Repeater {
                            model: Media.players
                            delegate: Rectangle {
                                required property var modelData
                                required property int index
                                readonly property bool active: index === Media.currentIndex
                                height: 20
                                width: Math.min(100, dwPRow.implicitWidth + 12)
                                radius: 10
                                color: active ? Theme.accent : (dwPMa.containsMouse ? Theme.surface3 : Theme.surface2)
                                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                Row {
                                    id: dwPRow
                                    anchors.centerIn: parent
                                    spacing: 4
                                    Icon {
                                        text: modelData.isPlaying ? "\uf04b" : "\uf001"
                                        font.pixelSize: 8
                                        tint: active ? Theme.onAccent : Theme.subtext
                                    }
                                    Label {
                                        width: Math.min(implicitWidth, 70)
                                        text: Media.playerName(modelData)
                                        font.pixelSize: Theme.fsS
                                        font.weight: active ? Font.DemiBold : Font.Normal
                                        color: active ? Theme.onAccent : Theme.text
                                    }
                                }
                                MouseArea {
                                    id: dwPMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Media.selectIndex(index)
                                }
                            }
                        }
                    }
                    IconButton { glyph: "\uf054"; size: 20; iconSize: 9; onClicked: Media.nextPlayer() }
                }
                Rectangle { id: art; x: 12; y: 12 + dwMedia.pagerOffset; width: 68; height: 68; radius: Theme.radiusS + 2; color: Theme.surface3; clip: true
                    Image { anchors.fill: parent; source: Media.art; fillMode: Image.PreserveAspectCrop; visible: status === Image.Ready; sourceSize: Qt.size(136, 136) }
                    Icon { anchors.centerIn: parent; text: "\uf001"; tint: Theme.subtext; visible: !Media.art } }
                Column { anchors { left: art.right; leftMargin: 12; right: parent.right; rightMargin: 12; top: art.top } spacing: 2
                    Label { width: parent.width; text: Media.title || "Unknown track"; font.weight: Font.DemiBold }
                    Label { width: parent.width; text: Media.artist || (Media.player?.identity ?? ""); color: Theme.subtext; font.pixelSize: Theme.fsS + 1 } }
                Row { anchors { left: art.right; leftMargin: 10; top: art.bottom; topMargin: -28 } spacing: 4
                    IconButton { glyph: "\uf048"; size: 28; iconSize: 11; onClicked: Media.previous() }
                    IconButton { glyph: Media.playing ? "\uf04c" : "\uf04b"; size: 28; iconSize: 11; active: true; onClicked: Media.playPause() }
                    IconButton { glyph: "\uf051"; size: 28; iconSize: 11; onClicked: Media.next() } }
                ColumnLayout {
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 12; bottomMargin: 10 }
                    spacing: 4
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        Label { text: Media.formatTime(Media.position); font.pixelSize: Theme.fsS; color: Theme.subtext; Layout.preferredWidth: 30 }
                        Slider {
                            Layout.fillWidth: true
                            implicitHeight: 18
                            opacity: Media.length > 0 ? 1 : 0.45
                            value: Media.length > 0 ? Media.position / Media.length : 0
                            onMoved: v => Media.seekRatio(v)
                        }
                        Label { text: Media.formatTime(Media.length); font.pixelSize: Theme.fsS; color: Theme.subtext; horizontalAlignment: Text.AlignRight; Layout.preferredWidth: 30 }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        IconButton {
                            glyph: Audio.icon(Media.volume, Media.muted)
                            size: 22
                            iconSize: 11
                            onClicked: Media.toggleMute()
                        }
                        Slider {
                            Layout.fillWidth: true
                            implicitHeight: 18
                            value: Media.muted ? 0 : Media.volume
                            onMoved: v => Media.setVolume(v)
                        }
                        Label { text: Math.round((Media.muted ? 0 : Media.volume) * 100) + "%"; font.pixelSize: Theme.fsS; color: Theme.subtext; horizontalAlignment: Text.AlignRight; Layout.preferredWidth: 30 }
                    }
                }
            }
            // app links
            Widget {
                visible: Config.o.widgetLinks && Config.o.appLinks.length > 0
                Layout.fillWidth: true; implicitHeight: 84
                Row {
                    anchors.centerIn: parent; spacing: 10
                    Repeater {
                        model: Config.o.appLinks
                        delegate: Rectangle {
                            required property var modelData
                            readonly property var entry: Apps.lookup(modelData)
                            width: 52; height: 52; radius: Theme.radius
                            color: lm.containsMouse ? Theme.surface3 : Theme.surface2
                            scale: lm.pressed ? 0.92 : (lm.containsMouse ? 1.06 : 1)
                            Behavior on color { ColorAnimation { duration: Theme.animFast } }
                            Behavior on scale { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutBack } }
                            Image { anchors.centerIn: parent; width: 32; height: 32; sourceSize: Qt.size(64, 64); source: Apps.iconFor(entry?.icon ?? modelData) }
                            MouseArea { id: lm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: { if (entry) entry.execute(); else Apps.run(modelData); } }
                        }
                    }
                }
            }
        }
    }
}
