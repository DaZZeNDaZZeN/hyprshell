import Quickshell
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

// Renders a single desktop widget instance of any type (digital-clock, analog-clock,
// weather, system, media, button, visualizer, audio-mixer, calendar).
Item {
    id: root
    required property var widget
    property bool editMode: false

    readonly property string wType: widget?.type ?? "digital-clock"
    readonly property color wColor: (widget?.customColor && /^#[0-9a-fA-F]{6}$/.test(widget.customColor))
        ? widget.customColor
        : Theme.accent
    readonly property color wOnColor: Theme.luminance(wColor) > 0.5 ? "#111111" : "#ffffff"
    readonly property color wColorDim: Qt.rgba(wColor.r, wColor.g, wColor.b, 0.20)
    readonly property color wColorSoft: Qt.rgba(wColor.r, wColor.g, wColor.b, 0.38)
    readonly property bool showCardBg: widget?.showBg !== false
    readonly property real cardAlpha: (widget?.bgOpacity !== undefined && widget.bgOpacity >= 0)
        ? widget.bgOpacity
        : Config.o.widgetsOpacity

    // Hide media widget on desktop when hideWhenIdle is enabled and no player exists
    readonly property bool hiddenByIdle: !editMode && wType === "media" && (widget?.hideWhenIdle ?? false) && Media.player === null
    visible: !hiddenByIdle
    opacity: hiddenByIdle ? 0 : 1

    // Background Card
    Rectangle {
        id: bgRect
        anchors.fill: parent
        radius: Theme.radiusL
        color: root.showCardBg ? Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, root.cardAlpha) : "transparent"
        border.width: root.showCardBg ? 1 : 0
        border.color: Theme.border
    }

    // Accent-aware custom slider used inside widgets so widget customColor applies to sliders too
    component WidgetSlider: Item {
        id: sl
        property real value: 0
        property real max: 1
        property int trackHeight: 7
        signal moved(real value)
        implicitHeight: 20
        implicitWidth: 120
        readonly property real frac: Math.max(0, Math.min(1, max > 0 ? value / max : 0))
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: sl.trackHeight
            radius: height / 2
            color: Theme.surface3
            Rectangle {
                width: Math.max(height, parent.width * sl.frac)
                height: parent.height
                radius: height / 2
                color: root.wColor
                Behavior on width { enabled: !slMa.pressed; NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
            }
        }
        Rectangle {
            x: (sl.width - width) * sl.frac
            anchors.verticalCenter: parent.verticalCenter
            width: slMa.pressed ? 16 : (slMa.containsMouse ? 14 : 11)
            height: width
            radius: width / 2
            color: Theme.text
            Behavior on width { NumberAnimation { duration: Theme.animFast } }
        }
        MouseArea {
            id: slMa
            anchors.fill: parent
            hoverEnabled: true
            enabled: !root.editMode
            cursorShape: Qt.PointingHandCursor
            function upd(m) { sl.moved(Math.max(0, Math.min(1, m.x / Math.max(1, width))) * sl.max); }
            onPressed: m => upd(m)
            onPositionChanged: m => { if (pressed) upd(m); }
            onWheel: w => sl.moved(Math.max(0, Math.min(sl.max, sl.value + (w.angleDelta.y > 0 ? 0.04 : -0.04) * sl.max)))
        }
    }

    // =========================================================================
    // 1. DIGITAL CLOCK WIDGET
    // =========================================================================
    Loader {
        anchors.fill: parent
        active: root.wType === "digital-clock"
        sourceComponent: Item {
            readonly property string tFmt: root.widget?.timeFormat || (Config.o.barClock24h ? "HH:mm" : "h:mm ap")
            readonly property string dFmt: root.widget?.dateFormat || "dddd, d MMMM"
            readonly property bool needsSec: tFmt.includes("s") || dFmt.includes("s")
            readonly property string alignMode: root.widget?.align || "center"
            readonly property int hAlign: alignMode === "left" ? Text.AlignLeft : (alignMode === "right" ? Text.AlignRight : Text.AlignHCenter)

            SystemClock {
                id: digiClock
                precision: parent.needsSec ? SystemClock.Seconds : SystemClock.Minutes
            }

            Column {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 4
                topPadding: Math.max(0, (height - implicitHeight) / 2)

                Label {
                    width: parent.width
                    horizontalAlignment: parent.parent.hAlign
                    text: Qt.formatDateTime(digiClock.date, parent.parent.tFmt)
                    font.pixelSize: root.widget?.timeSize ?? 64
                    font.weight: Font.Light
                    color: Theme.text
                    elide: Text.ElideRight
                }
                Label {
                    visible: root.widget?.showDate !== false
                    width: parent.width
                    horizontalAlignment: parent.parent.hAlign
                    text: Qt.formatDateTime(digiClock.date, parent.parent.dFmt)
                    font.pixelSize: root.widget?.dateSize ?? 15
                    font.weight: Font.Medium
                    color: root.wColor
                    elide: Text.ElideRight
                }
            }
        }
    }

    // =========================================================================
    // 2. ANALOG CLOCK WIDGET
    // =========================================================================
    Loader {
        anchors.fill: parent
        active: root.wType === "analog-clock"
        sourceComponent: Item {
            id: analogRoot
            readonly property bool showSec: root.widget?.showSeconds !== false
            readonly property bool showNums: root.widget?.showNumbers !== false
            readonly property bool showTicks: root.widget?.showTicks !== false
            readonly property bool showDate: root.widget?.showDate !== false

            SystemClock {
                id: anaClock
                precision: analogRoot.showSec ? SystemClock.Seconds : SystemClock.Minutes
                onDateChanged: faceCanvas.requestPaint()
            }

            Connections {
                target: root
                function onWColorChanged() { faceCanvas.requestPaint(); }
                function onWidgetChanged() { faceCanvas.requestPaint(); }
            }
            Connections {
                target: Theme
                function onTextChanged() { faceCanvas.requestPaint(); }
                function onSubtextChanged() { faceCanvas.requestPaint(); }
                function onSurface2Changed() { faceCanvas.requestPaint(); }
            }

            Canvas {
                id: faceCanvas
                anchors.fill: parent
                anchors.margins: 10
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                Component.onCompleted: requestPaint()

                onPaint: {
                    const ctx = getContext("2d");
                    const w = width, h = height;
                    ctx.clearRect(0, 0, w, h);
                    const cx = w / 2, cy = h / 2;
                    const r = Math.max(20, Math.min(cx, cy) - 4);

                    const textCol = Theme.hex(Theme.text);
                    const subCol = Theme.hex(Theme.subtext);
                    const accentCol = Theme.hex(root.wColor);
                    const ringCol = Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.14);

                    // Outer dial circle
                    ctx.beginPath();
                    ctx.arc(cx, cy, r, 0, Math.PI * 2);
                    ctx.strokeStyle = ringCol;
                    ctx.lineWidth = 2;
                    ctx.stroke();

                    // Ticks
                    if (analogRoot.showTicks) {
                        for (let i = 0; i < 60; i++) {
                            const ang = (i * 6 - 90) * Math.PI / 180;
                            const isMajor = (i % 5) === 0;
                            const innerR = r - (isMajor ? r * 0.12 : r * 0.06);
                            const outerR = r - 3;
                            ctx.beginPath();
                            ctx.moveTo(cx + Math.cos(ang) * innerR, cy + Math.sin(ang) * innerR);
                            ctx.lineTo(cx + Math.cos(ang) * outerR, cy + Math.sin(ang) * outerR);
                            ctx.strokeStyle = isMajor ? accentCol : subCol;
                            ctx.lineWidth = isMajor ? 2.2 : 1;
                            ctx.lineCap = "round";
                            ctx.stroke();
                        }
                    }

                    // Numbers 1..12
                    if (analogRoot.showNums && r >= 55) {
                        const numR = r * (analogRoot.showTicks ? 0.74 : 0.82);
                        const fs = Math.max(9, Math.round(r * 0.13));
                        ctx.font = "600 " + fs + "px sans-serif";
                        ctx.fillStyle = textCol;
                        ctx.textAlign = "center";
                        ctx.textBaseline = "middle";
                        for (let n = 1; n <= 12; n++) {
                            const ang = (n * 30 - 90) * Math.PI / 180;
                            ctx.fillText(String(n), cx + Math.cos(ang) * numR, cy + Math.sin(ang) * numR);
                        }
                    }

                    const now = anaClock.date;
                    const sec = now.getSeconds();
                    const min = now.getMinutes() + sec / 60;
                    const hr = (now.getHours() % 12) + min / 60;

                    // Date pill text
                    if (analogRoot.showDate && r >= 65) {
                        const dStr = Qt.formatDate(now, "ddd d");
                        ctx.font = "600 " + Math.max(9, Math.round(r * 0.10)) + "px sans-serif";
                        ctx.fillStyle = subCol;
                        ctx.textAlign = "center";
                        ctx.textBaseline = "middle";
                        ctx.fillText(dStr, cx, cy + r * 0.36);
                    }

                    // Hour hand
                    const hrAng = (hr * 30 - 90) * Math.PI / 180;
                    ctx.beginPath();
                    ctx.moveTo(cx - Math.cos(hrAng) * (r * 0.12), cy - Math.sin(hrAng) * (r * 0.12));
                    ctx.lineTo(cx + Math.cos(hrAng) * (r * 0.50), cy + Math.sin(hrAng) * (r * 0.50));
                    ctx.strokeStyle = textCol;
                    ctx.lineWidth = Math.max(3, r * 0.048);
                    ctx.lineCap = "round";
                    ctx.stroke();

                    // Minute hand
                    const minAng = (min * 6 - 90) * Math.PI / 180;
                    ctx.beginPath();
                    ctx.moveTo(cx - Math.cos(minAng) * (r * 0.14), cy - Math.sin(minAng) * (r * 0.14));
                    ctx.lineTo(cx + Math.cos(minAng) * (r * 0.72), cy + Math.sin(minAng) * (r * 0.72));
                    ctx.strokeStyle = textCol;
                    ctx.lineWidth = Math.max(2, r * 0.032);
                    ctx.lineCap = "round";
                    ctx.stroke();

                    // Second hand
                    if (analogRoot.showSec) {
                        const secAng = (sec * 6 - 90) * Math.PI / 180;
                        ctx.beginPath();
                        ctx.moveTo(cx - Math.cos(secAng) * (r * 0.18), cy - Math.sin(secAng) * (r * 0.18));
                        ctx.lineTo(cx + Math.cos(secAng) * (r * 0.80), cy + Math.sin(secAng) * (r * 0.80));
                        ctx.strokeStyle = accentCol;
                        ctx.lineWidth = 1.6;
                        ctx.lineCap = "round";
                        ctx.stroke();
                    }

                    // Center cap
                    ctx.beginPath();
                    ctx.arc(cx, cy, Math.max(3.5, r * 0.045), 0, Math.PI * 2);
                    ctx.fillStyle = accentCol;
                    ctx.fill();
                }
            }
        }
    }

    // =========================================================================
    // 3. WEATHER WIDGET
    // =========================================================================
    Loader {
        anchors.fill: parent
        active: root.wType === "weather"
        sourceComponent: Item {
            Component.onCompleted: Weather.users++
            Component.onDestruction: Weather.users--

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 14
                    Icon {
                        text: Weather.icon(Weather.code)
                        font.pixelSize: 38
                        tint: root.wColor
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        RowLayout {
                            spacing: 8
                            Label {
                                text: Weather.ok ? Weather.t(Weather.tempC) + Weather.unit : "—"
                                font.pixelSize: Theme.fsXL - 2
                                font.weight: Font.DemiBold
                            }
                            Label {
                                visible: (root.widget?.showDetails !== false) && Weather.ok
                                text: "💧" + Weather.humidity + "% · " + Weather.wind + " km/h"
                                color: Theme.subtext
                                font.pixelSize: Theme.fsS
                            }
                        }
                        Label {
                            Layout.fillWidth: true
                            text: Weather.ok ? Weather.desc : "Weather unavailable"
                            color: Theme.subtext
                            font.pixelSize: Theme.fsS + 1
                        }
                        Label {
                            Layout.fillWidth: true
                            visible: Weather.place !== ""
                            text: Weather.place
                            color: root.wColor
                            font.pixelSize: Theme.fsS
                        }
                    }
                }

                Item { Layout.fillHeight: true }

                Row {
                    visible: (root.widget?.showForecast !== false) && Weather.days.length > 0
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 16
                    Repeater {
                        model: (root.widget?.showForecast !== false) ? Weather.days : []
                        delegate: Row {
                            required property var modelData
                            spacing: 5
                            Icon { text: Weather.icon(modelData.code); font.pixelSize: 11; tint: root.wColor }
                            Label {
                                text: Qt.formatDate(new Date(modelData.date), "ddd") + " " + Weather.t(modelData.max) + "°"
                                font.pixelSize: Theme.fsS
                                color: Theme.subtext
                            }
                        }
                    }
                }
            }
        }
    }

    // =========================================================================
    // 4. SYSTEM MONITOR WIDGET
    // =========================================================================
    Loader {
        anchors.fill: parent
        active: root.wType === "system"
        sourceComponent: Item {
            Component.onCompleted: SysInfo.users++
            Component.onDestruction: SysInfo.users--

            readonly property var rows: {
                const list = [];
                if (root.widget?.showCpu !== false) {
                    list.push({ n: "CPU", v: SysInfo.cpu, t: Math.round(SysInfo.cpu * 100) + "%" });
                }
                if (root.widget?.showRam !== false) {
                    list.push({ n: "RAM", v: SysInfo.mem, t: SysInfo.memUsedGb.toFixed(1) + " / " + SysInfo.memTotalGb.toFixed(1) + " GB" });
                }
                if (root.widget?.showDisk !== false) {
                    list.push({ n: "Disk", v: SysInfo.disk, t: Math.round(SysInfo.disk * 100) + "%" });
                }
                return list;
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 8

                Repeater {
                    model: parent.parent.rows
                    delegate: RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 8
                        Label {
                            text: modelData.n
                            Layout.preferredWidth: 38
                            font.pixelSize: Theme.fsS + 1
                            font.weight: Font.Medium
                            color: Theme.subtext
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            height: 8
                            radius: 4
                            color: Theme.surface3
                            Rectangle {
                                width: parent.width * Math.max(0.02, Math.min(1, modelData.v))
                                height: parent.height
                                radius: 4
                                color: root.wColor
                                Behavior on width { NumberAnimation { duration: Theme.anim * 2; easing.type: Easing.OutCubic } }
                            }
                        }
                        Label {
                            text: modelData.t
                            Layout.preferredWidth: modelData.n === "RAM" ? 86 : 42
                            horizontalAlignment: Text.AlignRight
                            font.pixelSize: Theme.fsS
                            color: Theme.subtext
                        }
                    }
                }
            }
        }
    }

    // =========================================================================
    // 5. MEDIA PLAYER WIDGET
    // =========================================================================
    Loader {
        anchors.fill: parent
        active: root.wType === "media"
        sourceComponent: Item {
            readonly property bool showArt: root.widget?.showArt !== false
            readonly property bool showSeek: root.widget?.showSeek !== false
            readonly property bool showVol: root.widget?.showVolume !== false
            readonly property bool showPager: (root.widget?.showPlayerSelector !== false) && Media.count > 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 6

                // Player switcher row
                RowLayout {
                    visible: parent.parent.showPager
                    Layout.fillWidth: true
                    height: 22
                    spacing: 4
                    IconButton { glyph: "\uf053"; size: 20; iconSize: 9; enabled: !root.editMode; onClicked: Media.prevPlayer() }
                    Row {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 4
                        Repeater {
                            model: parent.parent.parent.showPager ? Media.players : []
                            delegate: Rectangle {
                                required property var modelData
                                required property int index
                                readonly property bool active: index === Media.currentIndex
                                height: 20
                                width: Math.min(96, mpRow.implicitWidth + 12)
                                radius: 10
                                color: active ? root.wColor : Theme.surface2
                                Row {
                                    id: mpRow
                                    anchors.centerIn: parent
                                    spacing: 4
                                    Icon {
                                        text: modelData.isPlaying ? "\uf04b" : "\uf001"
                                        font.pixelSize: 8
                                        tint: active ? root.wOnColor : Theme.subtext
                                    }
                                    Label {
                                        width: Math.min(implicitWidth, 68)
                                        text: Media.playerName(modelData)
                                        font.pixelSize: Theme.fsS
                                        color: active ? root.wOnColor : Theme.text
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    enabled: !root.editMode
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Media.selectIndex(index)
                                }
                            }
                        }
                    }
                    IconButton { glyph: "\uf054"; size: 20; iconSize: 9; enabled: !root.editMode; onClicked: Media.nextPlayer() }
                }

                // Art + Track Info + Controls
                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 12

                    Rectangle {
                        visible: parent.parent.parent.showArt
                        Layout.preferredWidth: 66
                        Layout.preferredHeight: 66
                        radius: Theme.radiusS + 2
                        color: Theme.surface3
                        clip: true
                        Image {
                            anchors.fill: parent
                            source: Media.art
                            fillMode: Image.PreserveAspectCrop
                            visible: status === Image.Ready
                            sourceSize: Qt.size(132, 132)
                        }
                        Icon {
                            anchors.centerIn: parent
                            text: "\uf001"
                            tint: root.wColor
                            font.pixelSize: 22
                            visible: !Media.art
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Label {
                            Layout.fillWidth: true
                            text: Media.title || (Media.player ? "Unknown track" : "No media playing")
                            font.weight: Font.DemiBold
                        }
                        Label {
                            Layout.fillWidth: true
                            text: Media.artist || (Media.player?.identity ?? "Start playback in any app")
                            color: Theme.subtext
                            font.pixelSize: Theme.fsS + 1
                        }
                        Row {
                            Layout.topMargin: 2
                            spacing: 6
                            IconButton { glyph: "\uf048"; size: 28; iconSize: 11; enabled: !root.editMode; onClicked: Media.previous() }
                            Rectangle {
                                width: 28; height: 28; radius: 14
                                color: root.wColor
                                Icon { anchors.centerIn: parent; text: Media.playing ? "\uf04c" : "\uf04b"; font.pixelSize: 11; tint: root.wOnColor }
                                MouseArea { anchors.fill: parent; enabled: !root.editMode; cursorShape: Qt.PointingHandCursor; onClicked: Media.playPause() }
                            }
                            IconButton { glyph: "\uf051"; size: 28; iconSize: 11; enabled: !root.editMode; onClicked: Media.next() }
                        }
                    }
                }

                // Seek bar
                RowLayout {
                    visible: parent.parent.showSeek
                    Layout.fillWidth: true
                    spacing: 6
                    Label { text: Media.formatTime(Media.position); font.pixelSize: Theme.fsS; color: Theme.subtext; Layout.preferredWidth: 30 }
                    WidgetSlider {
                        Layout.fillWidth: true
                        opacity: Media.length > 0 ? 1 : 0.45
                        value: Media.length > 0 ? Media.position / Media.length : 0
                        onMoved: v => Media.seekRatio(v)
                    }
                    Label { text: Media.formatTime(Media.length); font.pixelSize: Theme.fsS; color: Theme.subtext; horizontalAlignment: Text.AlignRight; Layout.preferredWidth: 30 }
                }

                // Volume bar
                RowLayout {
                    visible: parent.parent.showVol
                    Layout.fillWidth: true
                    spacing: 6
                    IconButton {
                        glyph: Audio.icon(Media.volume, Media.muted)
                        size: 22; iconSize: 11
                        enabled: !root.editMode
                        onClicked: Media.toggleMute()
                    }
                    WidgetSlider {
                        Layout.fillWidth: true
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
    }

    // =========================================================================
    // 6. COMMAND BUTTON WIDGET
    // =========================================================================
    Loader {
        anchors.fill: parent
        active: root.wType === "button"
        sourceComponent: Item {
            readonly property string layoutMode: root.widget?.layout || "horizontal"
            readonly property bool showLbl: (root.widget?.showLabel !== false) && layoutMode !== "icon-only"

            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusL
                color: btnMa.pressed ? root.wColorSoft : (btnMa.containsMouse ? root.wColorDim : "transparent")
                scale: btnMa.pressed ? 0.96 : 1.0
                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }

                // Horizontal layout
                RowLayout {
                    visible: parent.parent.layoutMode === "horizontal"
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 12
                    Rectangle {
                        Layout.preferredWidth: Math.min(42, parent.height)
                        Layout.preferredHeight: Layout.preferredWidth
                        radius: Theme.radius
                        color: root.wColor
                        Icon {
                            anchors.centerIn: parent
                            text: root.widget?.glyph || "\uf120"
                            font.pixelSize: Math.round(parent.width * 0.46)
                            tint: root.wOnColor
                        }
                    }
                    ColumnLayout {
                        visible: parent.parent.parent.showLbl
                        Layout.fillWidth: true
                        spacing: 1
                        Label {
                            Layout.fillWidth: true
                            text: root.widget?.label || "Command"
                            font.weight: Font.DemiBold
                            font.pixelSize: Theme.fsM
                        }
                        Label {
                            visible: (root.widget?.sublabel || "") !== ""
                            Layout.fillWidth: true
                            text: root.widget?.sublabel || ""
                            color: Theme.subtext
                            font.pixelSize: Theme.fsS
                        }
                    }
                }

                // Vertical / Icon-only layout
                Column {
                    visible: parent.parent.layoutMode !== "horizontal"
                    anchors.centerIn: parent
                    spacing: 6
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.parent.parent.showLbl ? 44 : Math.min(root.width, root.height) * 0.56
                        height: width
                        radius: Theme.radius
                        color: root.wColor
                        Icon {
                            anchors.centerIn: parent
                            text: root.widget?.glyph || "\uf120"
                            font.pixelSize: Math.round(parent.width * 0.48)
                            tint: root.wOnColor
                        }
                    }
                    Label {
                        visible: parent.parent.parent.showLbl
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Math.max(40, root.width - 16)
                        horizontalAlignment: Text.AlignHCenter
                        text: root.widget?.label || "Command"
                        font.weight: Font.Medium
                        font.pixelSize: Theme.fsS + 1
                    }
                }

                MouseArea {
                    id: btnMa
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: !root.editMode
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        const cmd = (root.widget?.command || "").trim();
                        if (cmd) Quickshell.execDetached(["sh", "-c", cmd]);
                    }
                }
            }
        }
    }

    // =========================================================================
    // 7. AUDIO VISUALIZER WIDGET (Bars / Waves × Straight / Circular)
    // =========================================================================
    Loader {
        anchors.fill: parent
        active: root.wType === "visualizer"
        sourceComponent: Item {
            id: visItem
            Component.onCompleted: AudioVisualizer.users++
            Component.onDestruction: AudioVisualizer.users--

            readonly property string mode: root.widget?.mode || "bars"       // "bars" | "waves"
            readonly property string shape: root.widget?.shape || "straight" // "straight" | "circular"
            readonly property int barCount: Math.max(8, Math.min(64, root.widget?.barCount ?? 32))
            readonly property real sens: Math.max(0.2, Math.min(4.0, root.widget?.sensitivity ?? 1.0))
            readonly property bool mirror: root.widget?.mirror ?? false
            readonly property bool fillWave: root.widget?.fillWave !== false

            Connections {
                target: AudioVisualizer
                function onBandsChanged() { visCanvas.requestPaint(); }
            }
            Connections {
                target: root
                function onWColorChanged() { visCanvas.requestPaint(); }
                function onWidgetChanged() { visCanvas.requestPaint(); }
            }

            Canvas {
                id: visCanvas
                anchors.fill: parent
                anchors.margins: 12
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                Component.onCompleted: requestPaint()

                function samplePoints(count) {
                    const raw = AudioVisualizer.bands || [];
                    const n = raw.length;
                    if (n === 0) return new Array(count).fill(0.04);
                    const out = [];
                    for (let i = 0; i < count; i++) {
                        const pos = (i / Math.max(1, count - 1)) * (n - 1);
                        const lo = Math.floor(pos);
                        const hi = Math.min(n - 1, lo + 1);
                        const frac = pos - lo;
                        const v = (raw[lo] * (1 - frac) + raw[hi] * frac) * visItem.sens;
                        out.push(Math.max(0.04, Math.min(1.0, v)));
                    }
                    return out;
                }

                onPaint: {
                    const ctx = getContext("2d");
                    const w = width, h = height;
                    ctx.clearRect(0, 0, w, h);
                    if (w <= 4 || h <= 4) return;

                    const count = visItem.barCount;
                    const pts = samplePoints(count);
                    const strokeCol = Theme.hex(root.wColor);
                    const fillCol = Qt.rgba(root.wColor.r, root.wColor.g, root.wColor.b, 0.26);

                    if (visItem.shape === "straight") {
                        if (visItem.mode === "bars") {
                            const gap = Math.max(2, Math.floor(w / (count * 3.2)));
                            const barW = Math.max(2, (w - gap * (count - 1)) / count);
                            ctx.fillStyle = strokeCol;
                            for (let i = 0; i < count; i++) {
                                const v = pts[i];
                                const x = i * (barW + gap);
                                const bh = Math.max(4, v * (h - 4));
                                const y = visItem.mirror ? (h - bh) / 2 : (h - bh);
                                const r = Math.min(barW / 2, 4);
                                ctx.beginPath();
                                ctx.roundedRect(x, y, barW, bh, r, r);
                                ctx.fill();
                            }
                        } else {
                            // Straight Waves
                            const stepX = w / Math.max(1, count - 1);
                            const baseY = visItem.mirror ? (h / 2) : (h - 2);
                            const ampH = visItem.mirror ? (h / 2 - 4) : (h - 8);

                            // Top wave curve
                            ctx.beginPath();
                            ctx.moveTo(0, baseY - pts[0] * ampH);
                            for (let i = 0; i < count - 1; i++) {
                                const x0 = i * stepX;
                                const y0 = baseY - pts[i] * ampH;
                                const x1 = (i + 1) * stepX;
                                const y1 = baseY - pts[i + 1] * ampH;
                                const mx = (x0 + x1) / 2;
                                const my = (y0 + y1) / 2;
                                ctx.quadraticCurveTo(x0, y0, mx, my);
                            }
                            ctx.lineTo(w, baseY - pts[count - 1] * ampH);

                            if (visItem.mirror) {
                                // Mirror bottom wave
                                for (let i = count - 1; i > 0; i--) {
                                    const x0 = i * stepX;
                                    const y0 = baseY + pts[i] * ampH;
                                    const x1 = (i - 1) * stepX;
                                    const y1 = baseY + pts[i - 1] * ampH;
                                    const mx = (x0 + x1) / 2;
                                    const my = (y0 + y1) / 2;
                                    ctx.quadraticCurveTo(x0, y0, mx, my);
                                }
                                ctx.lineTo(0, baseY + pts[0] * ampH);
                                ctx.closePath();
                                if (visItem.fillWave) {
                                    ctx.fillStyle = fillCol;
                                    ctx.fill();
                                }
                                ctx.strokeStyle = strokeCol;
                                ctx.lineWidth = 2.4;
                                ctx.stroke();
                            } else {
                                ctx.strokeStyle = strokeCol;
                                ctx.lineWidth = 2.5;
                                ctx.stroke();
                                if (visItem.fillWave) {
                                    ctx.lineTo(w, baseY);
                                    ctx.lineTo(0, baseY);
                                    ctx.closePath();
                                    ctx.fillStyle = fillCol;
                                    ctx.fill();
                                }
                            }
                        }
                    } else {
                        // Circular shape
                        const cx = w / 2, cy = h / 2;
                        const maxR = Math.max(16, Math.min(cx, cy) - 4);
                        const innerR = maxR * 0.44;
                        const maxAmp = maxR - innerR;

                        // Subtle base circle
                        ctx.beginPath();
                        ctx.arc(cx, cy, innerR, 0, Math.PI * 2);
                        ctx.strokeStyle = Qt.rgba(root.wColor.r, root.wColor.g, root.wColor.b, 0.28);
                        ctx.lineWidth = 1.5;
                        ctx.stroke();

                        if (visItem.mode === "bars") {
                            ctx.strokeStyle = strokeCol;
                            ctx.lineWidth = Math.max(2, Math.min(6, (2 * Math.PI * innerR) / (count * 2.0)));
                            ctx.lineCap = "round";
                            for (let i = 0; i < count; i++) {
                                // Symmetric around circle so start and end meet seamlessly
                                const symIdx = i < count / 2 ? i * 2 : (count - 1 - i) * 2;
                                const v = pts[Math.min(count - 1, symIdx)];
                                const ang = (i / count) * Math.PI * 2 - Math.PI / 2;
                                const len = Math.max(3, v * maxAmp);
                                const r0 = visItem.mirror ? Math.max(4, innerR - len * 0.4) : innerR;
                                const r1 = innerR + len;
                                ctx.beginPath();
                                ctx.moveTo(cx + Math.cos(ang) * r0, cy + Math.sin(ang) * r0);
                                ctx.lineTo(cx + Math.cos(ang) * r1, cy + Math.sin(ang) * r1);
                                ctx.stroke();
                            }
                        } else {
                            // Circular Waves
                            const coords = [];
                            for (let i = 0; i < count; i++) {
                                const symIdx = i < count / 2 ? i * 2 : (count - 1 - i) * 2;
                                const v = pts[Math.min(count - 1, symIdx)];
                                const ang = (i / count) * Math.PI * 2 - Math.PI / 2;
                                const r = innerR + v * maxAmp;
                                coords.push({ x: cx + Math.cos(ang) * r, y: cy + Math.sin(ang) * r });
                            }
                            ctx.beginPath();
                            const firstMidX = (coords[coords.length - 1].x + coords[0].x) / 2;
                            const firstMidY = (coords[coords.length - 1].y + coords[0].y) / 2;
                            ctx.moveTo(firstMidX, firstMidY);
                            for (let i = 0; i < coords.length; i++) {
                                const p0 = coords[i];
                                const p1 = coords[(i + 1) % coords.length];
                                ctx.quadraticCurveTo(p0.x, p0.y, (p0.x + p1.x) / 2, (p0.y + p1.y) / 2);
                            }
                            ctx.closePath();
                            if (visItem.fillWave) {
                                ctx.fillStyle = fillCol;
                                ctx.fill();
                            }
                            ctx.strokeStyle = strokeCol;
                            ctx.lineWidth = 2.4;
                            ctx.stroke();
                        }
                    }
                }
            }
        }
    }

    // =========================================================================
    // 8. AUDIO MIXER WIDGET (Toggleable Master, Mic, Output Devices, Input Devices, Apps)
    // =========================================================================
    Loader {
        anchors.fill: parent
        active: root.wType === "audio-mixer"
        sourceComponent: Item {
            readonly property bool showMaster: root.widget?.showMaster !== false
            readonly property bool showMic: root.widget?.showMic !== false
            readonly property bool showOutDevs: root.widget?.showOutputDevices !== false
            readonly property bool showInDevs: root.widget?.showInputDevices ?? false
            readonly property bool showApps: root.widget?.showApps !== false

            Flickable {
                id: mixerFlick
                anchors.fill: parent
                anchors.margins: 14
                contentHeight: mixerCol.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                interactive: !root.editMode

                ColumnLayout {
                    id: mixerCol
                    width: mixerFlick.width
                    spacing: 8

                    // Header
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Icon { text: "\uf1de"; font.pixelSize: 14; tint: root.wColor }
                        Label { text: "Audio Mixer"; font.weight: Font.DemiBold; Layout.fillWidth: true }
                    }

                    // 1. Master Output Volume
                    ColumnLayout {
                        visible: parent.parent.parent.showMaster
                        Layout.fillWidth: true
                        spacing: 4
                        Label { text: "Master Output"; font.pixelSize: Theme.fsS; color: Theme.subtext }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            IconButton {
                                glyph: Audio.icon(Audio.volume, Audio.muted)
                                size: 26; iconSize: 13
                                enabled: !root.editMode
                                onClicked: Audio.toggleMute()
                            }
                            WidgetSlider {
                                Layout.fillWidth: true
                                value: Audio.muted ? 0 : Audio.volume
                                max: 1.0
                                onMoved: v => Audio.setVolume(v)
                            }
                            Label {
                                text: Math.round((Audio.muted ? 0 : Audio.volume) * 100) + "%"
                                font.pixelSize: Theme.fsS
                                color: Theme.subtext
                                horizontalAlignment: Text.AlignRight
                                Layout.preferredWidth: 34
                            }
                        }
                    }

                    // 2. Microphone Volume
                    ColumnLayout {
                        visible: parent.parent.parent.showMic
                        Layout.fillWidth: true
                        spacing: 4
                        Label { text: "Microphone"; font.pixelSize: Theme.fsS; color: Theme.subtext }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            IconButton {
                                glyph: Audio.micMuted ? "\uf131" : "\uf130"
                                size: 26; iconSize: 13
                                enabled: !root.editMode
                                onClicked: Audio.toggleMic()
                            }
                            WidgetSlider {
                                Layout.fillWidth: true
                                value: Audio.micMuted ? 0 : Audio.micVolume
                                max: 1.0
                                onMoved: v => Audio.setMic(v)
                            }
                            Label {
                                text: Math.round((Audio.micMuted ? 0 : Audio.micVolume) * 100) + "%"
                                font.pixelSize: Theme.fsS
                                color: Theme.subtext
                                horizontalAlignment: Text.AlignRight
                                Layout.preferredWidth: 34
                            }
                        }
                    }

                    // 3. Output Devices (Sinks) with per-device volume
                    ColumnLayout {
                        visible: parent.parent.parent.showOutDevs
                        Layout.fillWidth: true
                        spacing: 4
                        Label { text: "Output Devices"; font.pixelSize: Theme.fsS; color: Theme.subtext }
                        Repeater {
                            model: parent.visible ? Audio.sinks : []
                            delegate: Rectangle {
                                id: sinkRow
                                required property var modelData
                                readonly property bool isDefault: Audio.sink === modelData
                                readonly property real devVol: modelData?.audio?.volume ?? 0
                                readonly property bool devMute: modelData?.audio?.muted ?? false
                                Layout.fillWidth: true
                                height: 54
                                radius: Theme.radiusS + 2
                                color: isDefault ? root.wColorDim : Theme.surface2
                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 6
                                    spacing: 2
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 6
                                        Icon {
                                            text: sinkRow.isDefault ? "\uf00c" : "\uf028"
                                            font.pixelSize: 11
                                            tint: sinkRow.isDefault ? root.wColor : Theme.subtext
                                        }
                                        Label {
                                            Layout.fillWidth: true
                                            text: sinkRow.modelData.description || sinkRow.modelData.name || "Output"
                                            font.pixelSize: Theme.fsS + 1
                                            font.weight: sinkRow.isDefault ? Font.DemiBold : Font.Normal
                                            MouseArea {
                                                anchors.fill: parent
                                                enabled: !root.editMode
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: Audio.setDefault(sinkRow.modelData)
                                            }
                                        }
                                        Label {
                                            text: Math.round((sinkRow.devMute ? 0 : sinkRow.devVol) * 100) + "%"
                                            font.pixelSize: Theme.fsS
                                            color: Theme.subtext
                                        }
                                    }
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 6
                                        IconButton {
                                            glyph: Audio.icon(sinkRow.devVol, sinkRow.devMute)
                                            size: 20; iconSize: 10
                                            enabled: !root.editMode
                                            onClicked: if (sinkRow.modelData?.audio) sinkRow.modelData.audio.muted = !sinkRow.modelData.audio.muted
                                        }
                                        WidgetSlider {
                                            Layout.fillWidth: true
                                            implicitHeight: 16
                                            value: sinkRow.devMute ? 0 : sinkRow.devVol
                                            onMoved: v => {
                                                if (sinkRow.modelData?.audio) {
                                                    sinkRow.modelData.audio.muted = false;
                                                    sinkRow.modelData.audio.volume = Math.max(0, Math.min(1.5, v));
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // 4. Input Devices (Sources) with per-device volume
                    ColumnLayout {
                        visible: parent.parent.parent.showInDevs
                        Layout.fillWidth: true
                        spacing: 4
                        Label { text: "Input Devices"; font.pixelSize: Theme.fsS; color: Theme.subtext }
                        Repeater {
                            model: parent.visible ? Audio.sources : []
                            delegate: Rectangle {
                                id: srcRow
                                required property var modelData
                                readonly property bool isDefault: Audio.source === modelData
                                readonly property real devVol: modelData?.audio?.volume ?? 0
                                readonly property bool devMute: modelData?.audio?.muted ?? false
                                Layout.fillWidth: true
                                height: 54
                                radius: Theme.radiusS + 2
                                color: isDefault ? root.wColorDim : Theme.surface2
                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 6
                                    spacing: 2
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 6
                                        Icon {
                                            text: srcRow.isDefault ? "\uf00c" : "\uf130"
                                            font.pixelSize: 11
                                            tint: srcRow.isDefault ? root.wColor : Theme.subtext
                                        }
                                        Label {
                                            Layout.fillWidth: true
                                            text: srcRow.modelData.description || srcRow.modelData.name || "Input"
                                            font.pixelSize: Theme.fsS + 1
                                            font.weight: srcRow.isDefault ? Font.DemiBold : Font.Normal
                                            MouseArea {
                                                anchors.fill: parent
                                                enabled: !root.editMode
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: Audio.setDefaultSource(srcRow.modelData)
                                            }
                                        }
                                        Label {
                                            text: Math.round((srcRow.devMute ? 0 : srcRow.devVol) * 100) + "%"
                                            font.pixelSize: Theme.fsS
                                            color: Theme.subtext
                                        }
                                    }
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 6
                                        IconButton {
                                            glyph: srcRow.devMute ? "\uf131" : "\uf130"
                                            size: 20; iconSize: 10
                                            enabled: !root.editMode
                                            onClicked: if (srcRow.modelData?.audio) srcRow.modelData.audio.muted = !srcRow.modelData.audio.muted
                                        }
                                        WidgetSlider {
                                            Layout.fillWidth: true
                                            implicitHeight: 16
                                            value: srcRow.devMute ? 0 : srcRow.devVol
                                            onMoved: v => {
                                                if (srcRow.modelData?.audio) {
                                                    srcRow.modelData.audio.muted = false;
                                                    srcRow.modelData.audio.volume = Math.max(0, Math.min(1.0, v));
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // 5. Application Streams
                    ColumnLayout {
                        visible: parent.parent.parent.showApps
                        Layout.fillWidth: true
                        spacing: 4
                        Label { text: "Applications"; font.pixelSize: Theme.fsS; color: Theme.subtext }
                        Repeater {
                            model: parent.visible ? Audio.streams : []
                            delegate: Rectangle {
                                id: appStreamRow
                                required property var modelData
                                readonly property real appVol: modelData?.audio?.volume ?? 0
                                readonly property bool appMute: modelData?.audio?.muted ?? false
                                Layout.fillWidth: true
                                height: 50
                                radius: Theme.radiusS + 2
                                color: Theme.surface2
                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 6
                                    spacing: 2
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Label {
                                            Layout.fillWidth: true
                                            text: Audio.nodeName(appStreamRow.modelData)
                                            font.pixelSize: Theme.fsS + 1
                                        }
                                        Label {
                                            text: Math.round((appStreamRow.appMute ? 0 : appStreamRow.appVol) * 100) + "%"
                                            font.pixelSize: Theme.fsS
                                            color: Theme.subtext
                                        }
                                    }
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 6
                                        IconButton {
                                            glyph: appStreamRow.appMute ? "\ueee8" : "\uf028"
                                            size: 20; iconSize: 10
                                            enabled: !root.editMode
                                            onClicked: if (appStreamRow.modelData?.audio) appStreamRow.modelData.audio.muted = !appStreamRow.modelData.audio.muted
                                        }
                                        WidgetSlider {
                                            Layout.fillWidth: true
                                            implicitHeight: 16
                                            value: appStreamRow.appMute ? 0 : appStreamRow.appVol
                                            onMoved: v => {
                                                if (appStreamRow.modelData?.audio) {
                                                    appStreamRow.modelData.audio.muted = false;
                                                    appStreamRow.modelData.audio.volume = Math.max(0, Math.min(1.5, v));
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        Label {
                            visible: Audio.streams.length === 0
                            text: "No apps playing audio"
                            color: Theme.subtext
                            font.pixelSize: Theme.fsS
                        }
                    }
                }
            }
        }
    }

    // =========================================================================
    // 9. CALENDAR WIDGET
    // =========================================================================
    Loader {
        anchors.fill: parent
        active: root.wType === "calendar"
        sourceComponent: Item {
            id: calWidget
            property int calYear: new Date().getFullYear()
            property int calMonth: new Date().getMonth()
            readonly property bool mondayFirst: root.widget?.firstDayMonday !== false
            readonly property bool showHeader: root.widget?.showHeader !== false
            readonly property bool showDow: root.widget?.showWeekdays !== false

            SystemClock { id: calClock; precision: SystemClock.Minutes }
            readonly property int todayY: calClock.date.getFullYear()
            readonly property int todayM: calClock.date.getMonth()
            readonly property int todayD: calClock.date.getDate()

            function buildDays(year, month, monFirst, tY, tM, tD) {
                const first = new Date(year, month, 1);
                const startDow = monFirst ? ((first.getDay() + 6) % 7) : first.getDay();
                const daysInMonth = new Date(year, month + 1, 0).getDate();
                const daysInPrev = new Date(year, month, 0).getDate();
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

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 4

                // Month / Year Header
                RowLayout {
                    visible: calWidget.showHeader
                    Layout.fillWidth: true
                    height: 28
                    IconButton {
                        glyph: "\uf053"; size: 24; iconSize: 10
                        enabled: !root.editMode
                        onClicked: {
                            if (calWidget.calMonth === 0) { calWidget.calMonth = 11; calWidget.calYear--; }
                            else calWidget.calMonth--;
                        }
                    }
                    Label {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: Qt.formatDate(new Date(calWidget.calYear, calWidget.calMonth, 1), "MMMM yyyy")
                        font.weight: Font.DemiBold
                        font.pixelSize: Theme.fsM
                        MouseArea {
                            anchors.fill: parent
                            enabled: !root.editMode
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                calWidget.calYear = calWidget.todayY;
                                calWidget.calMonth = calWidget.todayM;
                            }
                        }
                    }
                    IconButton {
                        glyph: "\uf054"; size: 24; iconSize: 10
                        enabled: !root.editMode
                        onClicked: {
                            if (calWidget.calMonth === 11) { calWidget.calMonth = 0; calWidget.calYear++; }
                            else calWidget.calMonth++;
                        }
                    }
                }

                // Weekday headers
                Row {
                    id: wdRow
                    visible: calWidget.showDow
                    Layout.fillWidth: true
                    Repeater {
                        model: calWidget.mondayFirst
                            ? ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
                            : ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
                        delegate: Label {
                            required property var modelData
                            width: wdRow.width / 7
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData
                            font.pixelSize: Theme.fsS
                            font.weight: Font.DemiBold
                            color: root.wColor
                        }
                    }
                }

                // 6x7 days grid
                Grid {
                    id: daysGrid
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    columns: 7
                    readonly property real cellW: width / 7
                    readonly property real cellH: height / 6
                    Repeater {
                        model: calWidget.buildDays(calWidget.calYear, calWidget.calMonth, calWidget.mondayFirst, calWidget.todayY, calWidget.todayM, calWidget.todayD)
                        delegate: Item {
                            required property var modelData
                            width: daysGrid.cellW
                            height: daysGrid.cellH
                            Rectangle {
                                anchors.centerIn: parent
                                width: Math.min(parent.width, parent.height) - 2
                                height: width
                                radius: width / 2
                                color: modelData.isToday ? root.wColor : "transparent"
                                Label {
                                    anchors.centerIn: parent
                                    text: modelData.day
                                    font.pixelSize: Theme.fsS
                                    font.weight: modelData.isToday ? Font.Bold : Font.Normal
                                    color: modelData.isToday ? root.wOnColor : (modelData.inMonth ? Theme.text : Theme.subtext)
                                    opacity: modelData.inMonth || modelData.isToday ? 1.0 : 0.38
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
