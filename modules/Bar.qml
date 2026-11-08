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
        readonly property int activeWsId: Hyprland.monitorFor(win.screen)?.activeWorkspace?.id ?? 1
        readonly property bool wsEmpty: (autoHide && Config.o.barKeepOnEmpty) && (ToplevelManager.toplevels.values.length === 0
            || !Hyprland.toplevels.values.some(t => t.workspace && t.workspace.id === win.activeWsId))
        property bool pointerInside: false
        property bool kbMenuOpen: false
        property bool calendarOpen: false
        property bool mediaPopupOpen: false
        property int openTrayMenus: 0
        readonly property bool trayMenuOpen: openTrayMenus > 0
        readonly property bool anyPopupOpen: kbMenuOpen || calendarOpen || mediaPopupOpen || trayMenuOpen
        readonly property int barZoneHeight: Config.o.barHeight + gap * 2
        readonly property int popupMaxSpace: 324
        readonly property bool hidden: autoHide && !(Config.o.barKeepOnEmpty && wsEmpty) && !pointerInside && !anyPopupOpen && !Panels.active
        anchors { left: true; right: true; top: atTop; bottom: !atTop }
        implicitHeight: barZoneHeight + popupMaxSpace
        exclusiveZone: autoHide ? 0 : barZoneHeight
        exclusionMode: autoHide ? ExclusionMode.Ignore : ExclusionMode.Normal
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "hyprshell-bar"
        color: "transparent"
        mask: Region { item: win.hidden ? trigger : maskArea }

        property int calYear: new Date().getFullYear()
        property int calMonth: new Date().getMonth()
        readonly property int todayYear: clock.date.getFullYear()
        readonly property int todayMonth: clock.date.getMonth()
        readonly property int todayDay: clock.date.getDate()

        function calendarDays(year, month) {
            const first = new Date(year, month, 1);
            // Monday = 0 .. Sunday = 6
            const startDow = (first.getDay() + 6) % 7;
            const daysInMonth = new Date(year, month + 1, 0).getDate();
            const daysInPrev = new Date(year, month, 0).getDate();
            const tY = win.todayYear, tM = win.todayMonth, tD = win.todayDay;
            const cells = [];
            for (let i = 0; i < 42; i++) {
                const offset = i - startDow + 1;
                let d, m = month, y = year, inMonth = true;
                if (offset < 1) {
                    d = daysInPrev + offset;
                    m = month - 1;
                    if (m < 0) { m = 11; y--; }
                    inMonth = false;
                } else if (offset > daysInMonth) {
                    d = offset - daysInMonth;
                    m = month + 1;
                    if (m > 11) { m = 0; y++; }
                    inMonth = false;
                } else {
                    d = offset;
                }
                cells.push({
                    day: d,
                    inMonth: inMonth,
                    isToday: y === tY && m === tM && d === tD
                });
            }
            return cells;
        }

        function prevMonth() {
            if (calMonth === 0) { calMonth = 11; calYear--; }
            else calMonth--;
        }
        function nextMonth() {
            if (calMonth === 11) { calMonth = 0; calYear++; }
            else calMonth++;
        }

        SystemClock { id: clock; precision: Config.o.barSeconds ? SystemClock.Seconds : SystemClock.Minutes }
        Timer {
            id: hideDelay
            interval: 450
            onTriggered: {
                if (win.trayMenuOpen) {
                    hideDelay.restart();
                    return;
                }
                win.pointerInside = false;
                win.kbMenuOpen = false;
                win.calendarOpen = false;
                win.mediaPopupOpen = false;
            }
        }
        HoverHandler {
            id: barHover
            onHoveredChanged: { if (hovered) { hideDelay.stop(); win.pointerInside = true; } else hideDelay.restart(); }
        }
        Connections {
            target: Panels
            function onActiveChanged() {
                if (Panels.active !== "") {
                    win.kbMenuOpen = false;
                    win.calendarOpen = false;
                    win.mediaPopupOpen = false;
                }
            }
        }
        Item {
            id: trigger
            width: parent.width
            height: Math.max(4, win.gap + 2)
            anchors.top: win.atTop ? parent.top : undefined
            anchors.bottom: win.atTop ? undefined : parent.bottom
        }
        Item {
            id: maskArea
            x: 0
            y: win.atTop ? 0 : (win.anyPopupOpen ? 0 : win.height - win.barZoneHeight)
            width: win.width
            height: win.anyPopupOpen ? win.height : win.barZoneHeight
        }

        // Click outside popups in popupSpace closes popups
        MouseArea {
            anchors.fill: parent
            enabled: win.kbMenuOpen || win.calendarOpen || win.mediaPopupOpen
            visible: enabled
            onClicked: {
                win.kbMenuOpen = false;
                win.calendarOpen = false;
                win.mediaPopupOpen = false;
            }
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
            color: Theme.barPanel
            border.width: Config.o.barFloating ? 1 : 0
            border.color: Theme.border

            // Scroll on empty bar space changes volume; right-click opens Control Center at cursor
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: m => {
                    win.kbMenuOpen = false;
                    win.calendarOpen = false;
                    win.mediaPopupOpen = false;
                    if (m.button === Qt.RightButton && Config.o.barRightClickCc) {
                        Panels.openAt("controlcenter", "", win.screen.name, bar.x + m.x);
                    }
                }
                onWheel: w => {
                    if (!Config.o.barScrollVolume) return;
                    const step = (Config.o.barScrollStep || 5) / 100;
                    Audio.step(w.angleDelta.y > 0 ? step : -step);
                }
            }

            // ---------- left ----------
            RowLayout {
                id: leftRow
                anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
                spacing: 6
                IconButton { glyph: "\uf00a"; size: 30; iconSize: 14; onClicked: Panels.toggle("launcher") }
                Label {
                    visible: Config.o.barShowTitle
                    Layout.maximumWidth: 260
                    Layout.leftMargin: 4
                    text: ToplevelManager.activeToplevel?.title ?? ""
                    color: Theme.subtext
                    font.pixelSize: Theme.fsS + 1
                }
            }

            // ---------- center (media at left of clock, clock, workspaces at right of clock) ----------
            Row {
                id: centerRow
                anchors.centerIn: parent
                spacing: 10

                // Media player pill (left of clock)
                Rectangle {
                    id: mediaPill
                    visible: Config.o.barShowMedia && Media.player !== null
                    anchors.verticalCenter: parent.verticalCenter
                    height: 28
                    width: visible ? mediaRow.implicitWidth + 20 : 0
                    radius: Theme.radiusS + 2
                    color: win.mediaPopupOpen ? Theme.accent : (mediaMa.containsMouse ? Theme.hover : "transparent")
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                    Row {
                        id: mediaRow
                        anchors.centerIn: parent
                        spacing: 6
                        Icon {
                            text: Media.playing ? "\uf001" : "\uf04c"
                            tint: win.mediaPopupOpen ? Theme.onAccent : Theme.accent
                            font.pixelSize: 12
                        }
                        Label {
                            width: Math.min(implicitWidth, 190)
                            text: Media.player ? (Media.artist ? Media.artist + " — " : "") + (Media.title || Media.player.identity || "Media") : ""
                            color: win.mediaPopupOpen ? Theme.onAccent : Theme.subtext
                            font.pixelSize: Theme.fsS + 1
                        }
                    }
                    MouseArea {
                        id: mediaMa
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: m => {
                            if (m.button === Qt.RightButton) {
                                Media.playPause();
                            } else {
                                win.kbMenuOpen = false;
                                win.calendarOpen = false;
                                win.mediaPopupOpen = !win.mediaPopupOpen;
                            }
                        }
                    }
                }

                // Clock & Date pill (center)
                Rectangle {
                    id: clockPill
                    anchors.verticalCenter: parent.verticalCenter
                    height: 28; width: clockRow.implicitWidth + 24; radius: Theme.radiusS + 2
                    color: win.calendarOpen ? Theme.accent : (clockMa.containsMouse ? Theme.hover : "transparent")
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                    Row {
                        id: clockRow
                        anchors.centerIn: parent
                        spacing: 8
                        Label {
                            text: Qt.formatDateTime(clock.date, "ddd d MMM")
                            color: win.calendarOpen ? Theme.onAccent : Theme.subtext
                        }
                        Label {
                            text: Qt.formatDateTime(clock.date, (Config.o.barClock24h ? "HH:mm" : "h:mm ap") + (Config.o.barSeconds ? ":ss" : ""))
                            font.weight: Font.DemiBold
                            color: win.calendarOpen ? Theme.onAccent : Theme.text
                        }
                    }
                    MouseArea {
                        id: clockMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            win.kbMenuOpen = false;
                            win.mediaPopupOpen = false;
                            if (!win.calendarOpen) {
                                win.calYear = clock.date.getFullYear();
                                win.calMonth = clock.date.getMonth();
                            }
                            win.calendarOpen = !win.calendarOpen;
                        }
                    }
                }

                // Workspaces (right of clock)
                Workspaces {
                    id: wsBar
                    anchors.verticalCenter: parent.verticalCenter
                    screenObj: win.screen
                }
            }

            // ---------- right ----------
            RowLayout {
                id: rightRow
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
                            property bool trackedOpen: false
                            onVisibleChanged: {
                                if (visible && !trackedOpen) {
                                    trackedOpen = true;
                                    win.openTrayMenus++;
                                    hideDelay.stop();
                                } else if (!visible && trackedOpen) {
                                    trackedOpen = false;
                                    win.openTrayMenus = Math.max(0, win.openTrayMenus - 1);
                                    hideDelay.restart();
                                }
                            }
                            onOpened: {
                                if (!trackedOpen) {
                                    trackedOpen = true;
                                    win.openTrayMenus++;
                                }
                                hideDelay.stop();
                            }
                            onClosed: {
                                if (trackedOpen) {
                                    trackedOpen = false;
                                    win.openTrayMenus = Math.max(0, win.openTrayMenus - 1);
                                }
                                hideDelay.restart();
                            }
                            Component.onDestruction: if (trackedOpen) win.openTrayMenus = Math.max(0, win.openTrayMenus - 1)
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

                // Keyboard layout dropdown button
                Rectangle {
                    id: kbBtn
                    visible: Config.o.barShowLayout && Keyboard.short !== ""
                    Layout.preferredHeight: 28
                    Layout.preferredWidth: kbRow.implicitWidth + 18
                    radius: Theme.radiusS + 2
                    color: win.kbMenuOpen ? Theme.accent : (kbMa.containsMouse ? Theme.hover : "transparent")
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                    Row {
                        id: kbRow
                        anchors.centerIn: parent
                        spacing: 5
                        Icon { text: "\uf11c"; font.pixelSize: 12; tint: win.kbMenuOpen ? Theme.onAccent : Theme.subtext }
                        Label {
                            text: Keyboard.short
                            font.weight: Font.DemiBold
                            font.pixelSize: Theme.fsS + 1
                            color: win.kbMenuOpen ? Theme.onAccent : Theme.text
                        }
                        Icon { text: win.kbMenuOpen ? "\uf077" : "\uf078"; font.pixelSize: 9; tint: win.kbMenuOpen ? Theme.onAccent : Theme.subtext }
                    }
                    MouseArea {
                        id: kbMa
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: m => {
                            if (m.button === Qt.RightButton) Keyboard.nextLayout();
                            else {
                                Keyboard.refresh();
                                win.calendarOpen = false;
                                win.mediaPopupOpen = false;
                                win.kbMenuOpen = !win.kbMenuOpen;
                            }
                        }
                    }
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

                // Notification button: left click opens Notification Center, right click toggles Do Not Disturb
                Rectangle {
                    Layout.preferredWidth: 30; Layout.preferredHeight: 30
                    radius: 15
                    color: Panels.active === "notifications" ? Theme.accent : (notifMa.containsMouse ? Theme.hover : "transparent")
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                    Icon {
                        anchors.centerIn: parent
                        text: Notifs.dnd ? "\uf1f6" : "\uf0f3"
                        font.pixelSize: 14
                        tint: Panels.active === "notifications" ? Theme.onAccent : (Notifs.dnd ? Theme.warn : Theme.text)
                    }
                    Rectangle {
                        visible: Notifs.count > 0
                        x: 17; y: 3; width: 9; height: 9; radius: 5; color: Theme.accent
                        border.width: 2; border.color: Theme.barPanel
                    }
                    MouseArea {
                        id: notifMa
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: m => {
                            if (m.button === Qt.RightButton) {
                                const next = !Notifs.dnd;
                                Notifs.setDnd(next);
                                Osd.show("dnd", next ? "\uf1f6" : "\uf0f3", "Do Not Disturb", -1, next ? "On" : "Off", next);
                            } else {
                                Panels.toggle("notifications");
                            }
                        }
                    }
                }
                IconButton { glyph: "\uf011"; size: 30; iconSize: 14; onClicked: Panels.toggle("session") }
            }
        }

        // Expanded Media Player popup
        Rectangle {
            id: mediaPopup
            readonly property int pagerOffset: Media.count > 1 ? 30 : 0
            visible: opacity > 0.01 && Media.player !== null
            opacity: win.mediaPopupOpen && Media.player !== null ? 1 : 0
            scale: win.mediaPopupOpen ? 1 : 0.94
            Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
            Behavior on scale { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }
            width: 340
            height: 174 + pagerOffset
            x: Math.min(win.width - width - 10, Math.max(10, bar.x + centerRow.x + mediaPill.x + mediaPill.width / 2 - width / 2))
            y: win.atTop ? (bar.y + bar.height + 6) : (bar.y - height - 6)
            radius: Theme.radiusL
            color: Theme.card
            border.width: 1
            border.color: Theme.border

            MouseArea { anchors.fill: parent }

            RowLayout {
                visible: Media.count > 1
                x: 14; y: 10; width: parent.width - 28; height: 24
                spacing: 6
                IconButton { glyph: "\uf053"; size: 22; iconSize: 10; onClicked: Media.prevPlayer() }
                Row {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 6
                    Repeater {
                        model: mediaPopup.visible ? Media.players : []
                        delegate: Rectangle {
                            required property var modelData
                            required property int index
                            readonly property bool active: index === Media.currentIndex
                            height: 22
                            width: Math.min(115, mpRow.implicitWidth + 14)
                            radius: 11
                            color: active ? Theme.accent : (mpMa.containsMouse ? Theme.surface3 : Theme.surface2)
                            Behavior on color { ColorAnimation { duration: Theme.animFast } }
                            Row {
                                id: mpRow
                                anchors.centerIn: parent
                                spacing: 5
                                Icon {
                                    text: modelData.isPlaying ? "\uf04b" : "\uf001"
                                    font.pixelSize: 9
                                    tint: active ? Theme.onAccent : Theme.subtext
                                }
                                Label {
                                    width: Math.min(implicitWidth, 82)
                                    text: Media.playerName(modelData)
                                    font.pixelSize: Theme.fsS
                                    font.weight: active ? Font.DemiBold : Font.Normal
                                    color: active ? Theme.onAccent : Theme.text
                                }
                            }
                            MouseArea {
                                id: mpMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Media.selectIndex(index)
                            }
                        }
                    }
                }
                IconButton { glyph: "\uf054"; size: 22; iconSize: 10; onClicked: Media.nextPlayer() }
            }

            Rectangle {
                id: mArt
                x: 14; y: 14 + mediaPopup.pagerOffset; width: 78; height: 78
                radius: Theme.radius
                color: Theme.surface3
                clip: true
                Image {
                    anchors.fill: parent
                    source: mediaPopup.visible ? Media.art : ""
                    fillMode: Image.PreserveAspectCrop
                    visible: status === Image.Ready
                    sourceSize: Qt.size(168, 168)
                }
                Icon {
                    anchors.centerIn: parent
                    text: "\uf001"
                    font.pixelSize: 26
                    tint: Theme.subtext
                    visible: !Media.art
                }
            }

            Column {
                anchors { left: mArt.right; leftMargin: 14; right: parent.right; rightMargin: 14; top: mArt.top; topMargin: -2 }
                spacing: 2
                Label {
                    width: parent.width
                    text: Media.title || "Unknown track"
                    font.weight: Font.DemiBold
                    font.pixelSize: Theme.fsM
                }
                Label {
                    width: parent.width
                    text: Media.artist || (Media.player?.identity ?? "")
                    color: Theme.subtext
                    font.pixelSize: Theme.fsS + 1
                }
            }

            Row {
                anchors { left: mArt.right; leftMargin: 14; top: mArt.bottom; topMargin: -32 }
                spacing: 8
                IconButton { glyph: "\uf048"; size: 30; iconSize: 11; onClicked: Media.previous() }
                IconButton { glyph: Media.playing ? "\uf04c" : "\uf04b"; size: 30; iconSize: 11; active: true; onClicked: Media.playPause() }
                IconButton { glyph: "\uf051"; size: 30; iconSize: 11; onClicked: Media.next() }
            }

            ColumnLayout {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 14; bottomMargin: 12 }
                spacing: 6

                // Duration / Seek slider
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Label {
                        text: mediaPopup.visible ? Media.formatTime(Media.position) : "0:00"
                        font.pixelSize: Theme.fsS
                        color: Theme.subtext
                        Layout.preferredWidth: 32
                    }
                    Slider {
                        Layout.fillWidth: true
                        implicitHeight: 20
                        opacity: Media.length > 0 ? 1 : 0.45
                        value: mediaPopup.visible && Media.length > 0 ? Media.position / Media.length : 0
                        onMoved: v => Media.seekRatio(v)
                    }
                    Label {
                        text: mediaPopup.visible ? Media.formatTime(Media.length) : "0:00"
                        font.pixelSize: Theme.fsS
                        color: Theme.subtext
                        horizontalAlignment: Text.AlignRight
                        Layout.preferredWidth: 32
                    }
                }

                // Volume slider
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    IconButton {
                        glyph: Audio.icon(Media.volume, Media.muted)
                        size: 24
                        iconSize: 12
                        onClicked: Media.toggleMute()
                    }
                    Slider {
                        Layout.fillWidth: true
                        implicitHeight: 20
                        value: Media.muted ? 0 : Media.volume
                        onMoved: v => Media.setVolume(v)
                    }
                    Label {
                        text: Math.round((Media.muted ? 0 : Media.volume) * 100) + "%"
                        font.pixelSize: Theme.fsS
                        color: Theme.subtext
                        horizontalAlignment: Text.AlignRight
                        Layout.preferredWidth: 32
                    }
                }
            }
        }

        // Calendar popup
        Rectangle {
            id: calPopup
            visible: opacity > 0.01
            opacity: win.calendarOpen ? 1 : 0
            scale: win.calendarOpen ? 1 : 0.94
            Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
            Behavior on scale { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }
            width: 296
            height: 306
            x: Math.min(win.width - width - 10, Math.max(10, bar.x + centerRow.x + clockPill.x + clockPill.width / 2 - width / 2))
            y: win.atTop ? (bar.y + bar.height + 6) : (bar.y - height - 6)
            radius: Theme.radiusL
            color: Theme.card
            border.width: 1
            border.color: Theme.border

            MouseArea { anchors.fill: parent }

            Item {
                anchors { fill: parent; margins: 14 }

                // Month / Year header
                RowLayout {
                    id: calHeader
                    width: parent.width
                    height: 32
                    IconButton { glyph: "\uf053"; size: 28; iconSize: 11; onClicked: win.prevMonth() }
                    Label {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: Qt.formatDate(new Date(win.calYear, win.calMonth, 1), "MMMM yyyy")
                        font.weight: Font.DemiBold
                        font.pixelSize: Theme.fsM
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                win.calYear = clock.date.getFullYear();
                                win.calMonth = clock.date.getMonth();
                            }
                        }
                    }
                    IconButton { glyph: "\uf054"; size: 28; iconSize: 11; onClicked: win.nextMonth() }
                }

                // Weekday names
                Row {
                    id: dowRow
                    y: 38
                    width: parent.width
                    Repeater {
                        model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
                        delegate: Label {
                            required property var modelData
                            width: dowRow.width / 7
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData
                            font.pixelSize: Theme.fsS
                            font.weight: Font.DemiBold
                            color: Theme.subtext
                        }
                    }
                }

                // 6x7 days grid
                Grid {
                    id: calGrid
                    y: 62
                    width: parent.width
                    columns: 7
                    Repeater {
                        model: calPopup.visible ? win.calendarDays(win.calYear, win.calMonth) : []
                        delegate: Rectangle {
                            required property var modelData
                            width: calGrid.width / 7
                            height: 34
                            radius: 17
                            color: modelData.isToday ? Theme.accent : "transparent"
                            Label {
                                anchors.centerIn: parent
                                text: modelData.day
                                font.pixelSize: Theme.fsS + 1
                                font.weight: modelData.isToday ? Font.Bold : Font.Normal
                                color: modelData.isToday ? Theme.onAccent : (modelData.inMonth ? Theme.text : Theme.subtext)
                                opacity: modelData.inMonth || modelData.isToday ? 1.0 : 0.4
                            }
                        }
                    }
                }
            }
        }

        // Keyboard layout dropdown menu
        Rectangle {
            id: kbMenu
            visible: opacity > 0.01
            opacity: win.kbMenuOpen ? 1 : 0
            scale: win.kbMenuOpen ? 1 : 0.94
            Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
            Behavior on scale { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }
            width: 190
            height: kbCol.implicitHeight + 12
            x: Math.min(win.width - width - 10, Math.max(10, bar.x + rightRow.x + kbBtn.x - width / 2 + kbBtn.width / 2))
            y: win.atTop ? (bar.y + bar.height + 6) : (bar.y - height - 6)
            radius: Theme.radius
            color: Theme.card
            border.width: 1
            border.color: Theme.border

            Column {
                id: kbCol
                anchors { fill: parent; margins: 6 }
                spacing: 2
                Repeater {
                    model: kbMenu.visible ? Keyboard.layouts : []
                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool active: modelData.index === Keyboard.activeIndex
                        width: kbCol.width
                        height: 34
                        radius: Theme.radiusS
                        color: active ? Theme.accent : (kbm.containsMouse ? Theme.hover : "transparent")
                        Behavior on color { ColorAnimation { duration: Theme.animFast } }
                        Row {
                            x: 10
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 10
                            Label {
                                text: modelData.code
                                font.weight: Font.Bold
                                font.pixelSize: Theme.fsS + 1
                                color: active ? Theme.onAccent : Theme.accent
                                width: 26
                            }
                            Label {
                                text: modelData.name
                                font.pixelSize: Theme.fsS + 1
                                font.weight: active ? Font.DemiBold : Font.Normal
                                color: active ? Theme.onAccent : Theme.text
                            }
                        }
                        Icon {
                            visible: active
                            anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                            text: "\uf00c"
                            font.pixelSize: 11
                            tint: Theme.onAccent
                        }
                        MouseArea {
                            id: kbm
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Keyboard.setLayout(modelData.index);
                                win.kbMenuOpen = false;
                            }
                        }
                    }
                }
            }
        }
    }
}
