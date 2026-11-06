import Quickshell
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

// Quick toggles, sliders, network / bluetooth / audio pages, power profile, media.
Variants {
    model: Quickshell.screens

    PanelOverlay {
        id: win
        required property var modelData
        screen: modelData
        name: "controlcenter"
        scrimOpacity: 0.12
        property string page: "main"
        onOpenChanged: if (open) { page = Panels.page || "main"; Network.wanted = true; Network.refresh(); } else Network.wanted = false

        component Tile: Rectangle {
            id: t
            property string glyph
            property string label
            property string sub: ""
            property bool on: false
            property bool expandable: false
            signal clicked()
            signal expand()
            height: 62
            radius: Theme.radius
            color: on ? Theme.accent : Theme.surface2
            scale: ma.pressed ? 0.97 : 1
            Behavior on color { ColorAnimation { duration: Theme.anim } }
            Behavior on scale { NumberAnimation { duration: Theme.animFast } }
            readonly property color fg: on ? Theme.onAccent : Theme.text
            Icon { x: 14; anchors.verticalCenter: parent.verticalCenter; text: t.glyph; font.pixelSize: 18; tint: t.fg }
            Column {
                anchors { left: parent.left; leftMargin: 48; right: parent.right; rightMargin: t.expandable ? 34 : 10; verticalCenter: parent.verticalCenter }
                Label { width: parent.width; text: t.label; color: t.fg; font.weight: Font.Medium }
                Label { width: parent.width; visible: text !== ""; text: t.sub; color: t.fg; opacity: 0.75; font.pixelSize: Theme.fsS }
            }
            MouseArea {
                id: ma; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: m => { if (m.button === Qt.RightButton) { if (t.expandable) t.expand(); } else t.clicked(); }
            }
            Icon {
                visible: t.expandable
                anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                text: "\uf054"; font.pixelSize: 12; tint: t.fg
                MouseArea { anchors { fill: parent; margins: -10 } cursorShape: Qt.PointingHandCursor; onClicked: t.expand() }
            }
        }
        component Page: Item {
            id: pg
            property string key
            anchors.fill: parent
            opacity: win.page === key ? 1 : 0
            visible: opacity > 0.01
            transform: Translate { x: win.page === pg.key ? 0 : (pg.key === "main" ? -40 : 40); Behavior on x { NumberAnimation { duration: Theme.animSlow; easing.type: Easing.OutQuint } } }
            Behavior on opacity { NumberAnimation { duration: Theme.anim } }
        }
        component PageHeader: RowLayout {
            property string title
            property bool hasSwitch: false
            property bool switchOn: false
            signal switched(bool v)
            width: parent.width
            IconButton { glyph: "\uf053"; size: 32; iconSize: 13; onClicked: win.page = "main" }
            Label { text: parent.title; font.pixelSize: Theme.fsL; font.weight: Font.DemiBold; Layout.fillWidth: true }
            Toggle { visible: parent.hasSwitch; checked: parent.switchOn; onToggled: v => parent.switched(v) }
        }
        component SliderRow: RowLayout {
            property string glyph
            property real value
            property real max: 1
            signal moved(real v)
            signal iconClicked()
            spacing: 10
            IconButton { glyph: parent.glyph; size: 34; iconSize: 16; onClicked: parent.iconClicked() }
            Slider { Layout.fillWidth: true; value: parent.value; max: parent.max; onMoved: v => parent.moved(v) }
            Label { text: Math.round(parent.value / parent.max * 100) + "%"; Layout.preferredWidth: 38; horizontalAlignment: Text.AlignRight; color: Theme.subtext; font.pixelSize: Theme.fsS + 1 }
        }

        PopupCard {
            id: card
            shown: win.open
            width: 396
            height: win.page === "main" ? mainCol.implicitHeight + 32 : 520
            Behavior on height { NumberAnimation { duration: Theme.animSlow; easing.type: Easing.OutQuint } }
            x: Panels.anchorX >= 0
                ? Math.max(10, Math.min(parent.width - width - 10, Math.round(Panels.anchorX - width / 2)))
                : parent.width - width - 10
            y: Config.o.barEnabled && Config.o.barPosition === "bottom"
                ? parent.height - height - (Config.o.barHeight + 16)
                : (Config.o.barEnabled && Config.o.barPosition === "top" ? Config.o.barHeight + 16 : 10)
            slideY: Config.o.barEnabled && Config.o.barPosition === "bottom" ? 16 : -16
            clip: true

            // ---------------- main ----------------
            Page {
                key: "main"
                ColumnLayout {
                    id: mainCol
                    x: 16; y: 16; width: parent.width - 32
                    spacing: 12
                    RowLayout {
                        Layout.fillWidth: true
                        Label { text: "Control Center"; font.pixelSize: Theme.fsL; font.weight: Font.DemiBold; Layout.fillWidth: true }
                        IconButton { glyph: "\uf030"; size: 32; iconSize: 14; baseColor: Theme.surface2; onClicked: Screenshot.start("region") }
                        IconButton { glyph: "\uf013"; size: 32; iconSize: 14; baseColor: Theme.surface2; onClicked: Panels.open("settings") }
                        IconButton { glyph: "\uf011"; size: 32; iconSize: 14; baseColor: Theme.surface2; onClicked: Panels.open("session") }
                    }
                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2; columnSpacing: 10; rowSpacing: 10
                        Tile { Layout.fillWidth: true; glyph: "\uf1eb"; label: "Wi-Fi"; expandable: true
                            sub: Network.ethernetUp && !Network.activeSsid ? "Ethernet" : (Network.wifiEnabled ? (Network.activeSsid || "Not connected") : "Off")
                            on: Network.wifiEnabled; onClicked: Network.setWifi(!Network.wifiEnabled); onExpand: win.page = "wifi" }
                        Tile { Layout.fillWidth: true; glyph: "\uf293"; label: "Bluetooth"; expandable: true; visible: Bt.available
                            sub: !Bt.on ? "Off" : (Bt.connected ? Bt.connectedDevices[0].name : "On")
                            on: Bt.on; onClicked: Bt.setOn(!Bt.on); onExpand: win.page = "bt" }
                        Tile { Layout.fillWidth: true; glyph: "\uf1f6"; label: "Do not disturb"; on: Notifs.dnd; sub: Notifs.dnd ? "On" : "Off"; onClicked: Notifs.setDnd(!Notifs.dnd) }
                        Tile { Layout.fillWidth: true; glyph: Theme.dark ? "\uf186" : "\uf185"; label: Theme.dark ? "Dark mode" : "Light mode"; on: Theme.dark
                            sub: Theme.activeTheme === "none" ? "Neutral" : Theme.activeTheme
                            onClicked: Config.o.themeMode = Theme.dark ? "light" : "dark" }
                        Tile { Layout.fillWidth: true; glyph: "\uf03d"; label: "Screen record"; on: Recorder.recording
                            sub: Recorder.recording ? "Recording…" : (Recorder.tool ? "Ready" : "Not installed"); onClicked: { Panels.close(); Recorder.toggle(); } }
                        Tile { Layout.fillWidth: true; glyph: "\uf028"; label: "Audio"; sub: Audio.sink ? (Audio.sink.description || Audio.sink.name) : ""; expandable: true
                            onClicked: win.page = "audio"; onExpand: win.page = "audio" }
                    }
                    Card {
                        Layout.fillWidth: true; Layout.preferredHeight: slCol.implicitHeight + 24
                        ColumnLayout {
                            id: slCol
                            x: 14; y: 12; width: parent.width - 28; spacing: 6
                            SliderRow { Layout.fillWidth: true; glyph: Audio.icon(Audio.volume, Audio.muted); value: Audio.volume; onMoved: v => Audio.setVolume(v); onIconClicked: Audio.toggleMute() }
                            SliderRow { Layout.fillWidth: true; glyph: "\uf185"; value: Brightness.value; onMoved: v => Brightness.set(v) }
                        }
                    }
                    // power profile
                    Card {
                        Layout.fillWidth: true; Layout.preferredHeight: 74
                        Label { x: 14; y: 8; text: "Power profile"; color: Theme.subtext; font.pixelSize: Theme.fsS }
                        Row {
                            x: 10; y: 30; spacing: 6
                            Repeater {
                                model: [
                                    { name: "Power saver", glyph: "\uf06c", p: PowerProfile.PowerSaver },
                                    { name: "Balanced", glyph: "\uf24e", p: PowerProfile.Balanced },
                                    { name: "Performance", glyph: "\uf0e7", p: PowerProfile.Performance },
                                ]
                                delegate: Rectangle {
                                    required property var modelData
                                    readonly property bool cur: PowerProfiles.profile === modelData.p
                                    readonly property bool avail: modelData.p !== PowerProfile.Performance || PowerProfiles.hasPerformanceProfile
                                    width: (card.width - 32 - 20 - 12) / 3; height: 34; radius: Theme.radiusS + 2
                                    opacity: avail ? 1 : 0.35
                                    color: cur ? Theme.accent : (pm.containsMouse ? Theme.surface3 : "transparent")
                                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                    Row { anchors.centerIn: parent; spacing: 6
                                        Icon { text: modelData.glyph; font.pixelSize: 12; tint: cur ? Theme.onAccent : Theme.text }
                                        Label { text: modelData.name; font.pixelSize: Theme.fsS + 1; color: cur ? Theme.onAccent : Theme.text } }
                                    MouseArea { id: pm; anchors.fill: parent; hoverEnabled: true; enabled: parent.avail; cursorShape: Qt.PointingHandCursor; onClicked: PowerProfiles.profile = modelData.p }
                                }
                            }
                        }
                    }
                    // media
                    Card {
                        id: mediaCard
                        Layout.fillWidth: true; Layout.preferredHeight: Media.player ? 96 : 0
                        visible: Media.player !== null
                        Rectangle {
                            id: art; x: 12; y: 12; width: 72; height: 72; radius: Theme.radiusS + 2; color: Theme.surface3; clip: true
                            Image { anchors.fill: parent; source: Media.art; fillMode: Image.PreserveAspectCrop; visible: status === Image.Ready; sourceSize: Qt.size(144, 144) }
                            Icon { anchors.centerIn: parent; text: "\uf001"; font.pixelSize: 24; tint: Theme.subtext; visible: !Media.art }
                        }
                        Column {
                            anchors { left: art.right; leftMargin: 12; right: parent.right; rightMargin: 12; top: parent.top; topMargin: 14 }
                            spacing: 2
                            Label { width: parent.width; text: Media.title || "Nothing playing"; font.weight: Font.DemiBold }
                            Label { width: parent.width; text: Media.artist; color: Theme.subtext; font.pixelSize: Theme.fsS + 1 }
                        }
                        Row {
                            anchors { left: art.right; leftMargin: 8; bottom: parent.bottom; bottomMargin: 10 }
                            spacing: 4
                            IconButton { glyph: "\uf048"; size: 32; iconSize: 12; onClicked: Media.previous() }
                            IconButton { glyph: Media.playing ? "\uf04c" : "\uf04b"; size: 32; iconSize: 13; active: true; onClicked: Media.playPause() }
                            IconButton { glyph: "\uf051"; size: 32; iconSize: 12; onClicked: Media.next() }
                        }
                    }
                    // battery
                    Label {
                        visible: UPower.displayDevice.isPresent
                        Layout.alignment: Qt.AlignHCenter
                        color: Theme.subtext; font.pixelSize: Theme.fsS + 1
                        text: "Battery " + Math.round(UPower.displayDevice.percentage * 100) + "%" + (UPower.displayDevice.state === UPowerDeviceState.Charging ? " · charging" : "")
                    }
                }
            }

            // ---------------- wifi ----------------
            Page {
                key: "wifi"
                property string pwFor: ""
                ColumnLayout {
                    x: 16; y: 16; width: parent.width - 32; height: parent.height - 32; spacing: 10
                    PageHeader { title: "Wi-Fi"; hasSwitch: true; switchOn: Network.wifiEnabled; onSwitched: v => Network.setWifi(v) }
                    Rectangle {
                        visible: Network.ethernetUp; Layout.fillWidth: true; height: 48; radius: Theme.radiusS + 2; color: Theme.surface2
                        Row { anchors.verticalCenter: parent.verticalCenter; x: 14; spacing: 12
                            Icon { text: "\uf0e8"; tint: Theme.accent }
                            Column { Label { text: "Ethernet" ; font.weight: Font.Medium } Label { text: "Connected · " + Network.ethernetName; color: Theme.subtext; font.pixelSize: Theme.fsS } } }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Label { text: Network.scanning ? "Scanning…" : "Available networks"; color: Theme.subtext; Layout.fillWidth: true }
                        IconButton { glyph: "\uf021"; size: 28; iconSize: 12; onClicked: Network.scan(true) }
                    }
                    ListView {
                        id: wl
                        Layout.fillWidth: true; Layout.fillHeight: true
                        clip: true; spacing: 4; model: Network.wifiEnabled ? Network.networks : []
                        boundsBehavior: Flickable.StopAtBounds
                        delegate: Rectangle {
                            id: wrow
                            required property var modelData
                            readonly property bool asking: wl.askSsid === modelData.ssid
                            width: wl.width; height: asking ? 100 : 46; radius: Theme.radiusS + 2
                            color: modelData.active ? Theme.accentDim : (wm.containsMouse ? Theme.surface2 : "transparent")
                            clip: true
                            Behavior on height { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }
                            Behavior on color { ColorAnimation { duration: Theme.animFast } }
                            Row { x: 12; y: 13; spacing: 12
                                Icon { text: "\uf1eb"; tint: modelData.active ? Theme.accent : Theme.text; opacity: 0.4 + modelData.signal / 170 }
                                Label { text: modelData.ssid; width: 220; font.weight: modelData.active ? Font.DemiBold : Font.Normal }
                            }
                            Row { anchors { right: parent.right; rightMargin: 12 } y: 13; spacing: 8
                                Icon { visible: modelData.secure; text: "\uf023"; font.pixelSize: 11; tint: Theme.subtext }
                                Label { text: modelData.active ? "Connected" : modelData.signal + "%"; color: Theme.subtext; font.pixelSize: Theme.fsS } }
                            MouseArea { id: wm; anchors { left: parent.left; right: parent.right; top: parent.top } height: 46; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (modelData.active) Network.disconnectActive();
                                    else if (modelData.secure) { wl.askSsid = wrow.asking ? "" : modelData.ssid; pw.text = ""; if (!wrow.asking) pw.forceActiveFocus(); }
                                    else Network.connect(modelData.ssid, "");
                                } }
                            TextField {
                                id: pw
                                x: 12; y: 52; width: parent.width - 120; height: 36
                                echoMode: TextInput.Password; placeholder: "Password (blank = saved)"
                                onAccepted: { Network.connect(wrow.modelData.ssid, text); wl.askSsid = ""; }
                            }
                            Button { x: parent.width - 100; y: 53; text: "Connect"; primary: true; implicitHeight: 34
                                onClicked: { Network.connect(wrow.modelData.ssid, pw.text); wl.askSsid = ""; } }
                        }
                        property string askSsid: ""
                    }
                    Label { visible: Network.error !== ""; Layout.fillWidth: true; text: Network.error; color: Theme.danger; font.pixelSize: Theme.fsS; wrapMode: Text.Wrap; maximumLineCount: 2 }
                }
            }

            // ---------------- bluetooth ----------------
            Page {
                key: "bt"
                ColumnLayout {
                    x: 16; y: 16; width: parent.width - 32; height: parent.height - 32; spacing: 10
                    PageHeader { title: "Bluetooth"; hasSwitch: true; switchOn: Bt.on; onSwitched: v => Bt.setOn(v) }
                    RowLayout {
                        Layout.fillWidth: true
                        Label { text: Bt.adapter?.discovering ? "Searching for devices…" : "Devices"; color: Theme.subtext; Layout.fillWidth: true }
                        IconButton { glyph: "\uf002"; size: 28; iconSize: 12; active: Bt.adapter?.discovering ?? false; onClicked: Bt.scan(!(Bt.adapter?.discovering ?? false)) }
                    }
                    ListView {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        clip: true; spacing: 4
                        model: Bt.on ? Bt.devices.slice().sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired)) : []
                        boundsBehavior: Flickable.StopAtBounds
                        delegate: Rectangle {
                            id: drow
                            required property var modelData
                            width: ListView.view.width; height: 52; radius: Theme.radiusS + 2
                            color: modelData.connected ? Theme.accentDim : (dm.containsMouse ? Theme.surface2 : "transparent")
                            Behavior on color { ColorAnimation { duration: Theme.animFast } }
                            Row { x: 12; anchors.verticalCenter: parent.verticalCenter; spacing: 12
                                Icon { text: Bt.deviceIcon(modelData); tint: modelData.connected ? Theme.accent : Theme.text }
                                Column {
                                    Label { text: modelData.name || modelData.address; width: 230; font.weight: modelData.connected ? Font.DemiBold : Font.Normal }
                                    Label { text: modelData.connected ? "Connected" + (modelData.batteryAvailable ? " · " + Math.round(modelData.battery * 100) + "%" : "") : (modelData.paired ? "Paired" : "Available"); color: Theme.subtext; font.pixelSize: Theme.fsS }
                                } }
                            IconButton { visible: modelData.paired; anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                                glyph: "\uf1f8"; size: 28; iconSize: 11; onClicked: modelData.forget() }
                            MouseArea { id: dm; anchors { fill: parent; rightMargin: 44 } hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: { if (modelData.connected) modelData.disconnect(); else if (modelData.paired) modelData.connect(); else modelData.pair(); } }
                        }
                    }
                }
            }

            // ---------------- audio ----------------
            Page {
                key: "audio"
                ColumnLayout {
                    x: 16; y: 16; width: parent.width - 32; height: parent.height - 32; spacing: 10
                    PageHeader { title: "Audio" }
                    SliderRow { Layout.fillWidth: true; glyph: Audio.icon(Audio.volume, Audio.muted); value: Audio.volume; onMoved: v => Audio.setVolume(v); onIconClicked: Audio.toggleMute() }
                    SliderRow { Layout.fillWidth: true; glyph: Audio.micMuted ? "\uf131" : "\uf130"; value: Audio.micVolume; onMoved: v => Audio.setMic(v); onIconClicked: Audio.toggleMic() }
                    Flickable {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        contentHeight: audioScrollCol.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        ColumnLayout {
                            id: audioScrollCol
                            width: parent.width
                            spacing: 6
                            Label { text: "Output device"; color: Theme.subtext; font.pixelSize: Theme.fsS }
                            Repeater {
                                model: Audio.sinks
                                delegate: Rectangle {
                                    required property var modelData
                                    readonly property bool cur: Audio.sink === modelData
                                    Layout.fillWidth: true; height: 38; radius: Theme.radiusS + 2
                                    color: cur ? Theme.accentDim : (om.containsMouse ? Theme.surface2 : "transparent")
                                    Row { x: 12; anchors.verticalCenter: parent.verticalCenter; spacing: 10
                                        Icon { text: cur ? "\uf00c" : "\uf028"; tint: cur ? Theme.accent : Theme.subtext; font.pixelSize: 13 }
                                        Label { text: modelData.description || modelData.name; width: 300 } }
                                    MouseArea { id: om; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Audio.setDefault(modelData) }
                                }
                            }
                            Label { Layout.topMargin: 4; text: "Input device"; color: Theme.subtext; font.pixelSize: Theme.fsS }
                            Repeater {
                                model: Audio.sources
                                delegate: Rectangle {
                                    required property var modelData
                                    readonly property bool cur: Audio.source === modelData
                                    Layout.fillWidth: true; height: 38; radius: Theme.radiusS + 2
                                    color: cur ? Theme.accentDim : (im.containsMouse ? Theme.surface2 : "transparent")
                                    Row { x: 12; anchors.verticalCenter: parent.verticalCenter; spacing: 10
                                        Icon { text: cur ? "\uf00c" : "\uf130"; tint: cur ? Theme.accent : Theme.subtext; font.pixelSize: 13 }
                                        Label { text: modelData.description || modelData.name; width: 300 } }
                                    MouseArea { id: im; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Audio.setDefaultSource(modelData) }
                                }
                            }
                            Label {
                                visible: Audio.sources.length === 0
                                text: "No input devices found"
                                color: Theme.subtext
                                font.pixelSize: Theme.fsS
                            }
                            Label { Layout.topMargin: 4; text: "Applications"; color: Theme.subtext; font.pixelSize: Theme.fsS }
                            Repeater {
                                model: Audio.streams
                                delegate: Item {
                                    required property var modelData
                                    Layout.fillWidth: true; height: 56
                                    Label { x: 4; y: 2; text: Audio.nodeName(modelData); font.pixelSize: Theme.fsS + 1; width: 300 }
                                    RowLayout {
                                        x: 0; y: 22; width: parent.width; spacing: 8
                                        IconButton { glyph: modelData.audio.muted ? "\ueee8" : "\uf028"; size: 28; iconSize: 12; onClicked: modelData.audio.muted = !modelData.audio.muted }
                                        Slider { Layout.fillWidth: true; value: modelData.audio.volume; onMoved: v => modelData.audio.volume = v }
                                    }
                                }
                            }
                            Label {
                                visible: Audio.streams.length === 0
                                Layout.alignment: Qt.AlignHCenter
                                Layout.topMargin: 8
                                text: "No apps are playing audio"
                                color: Theme.subtext
                            }
                        }
                    }
                }
            }
        }
    }
}
