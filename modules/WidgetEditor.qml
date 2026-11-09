import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

// Interactive full-screen Desktop Widget Editor:
// - Create, edit, rename, reset, and delete widget presets
// - Assign any preset to any wallpaper (unassigned wallpapers automatically use "default")
// - Add, select, drag-move, drag-resize, duplicate, delete, and customize all 9 widget types
Variants {
    model: Quickshell.screens.slice(0, 1)

    PanelWindow {
        id: win
        required property var modelData
        screen: modelData
        readonly property string name: "widgeteditor"
        readonly property string targetScreenName: modelData ? modelData.name : (screen ? screen.name : "")
        readonly property bool open: Panels.active === name && (Panels.screenName === targetScreenName || Panels.screenName === "")

        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        visible: open || closing.running
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "hyprshell-widgeteditor"
        WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        property string activeTab: "properties" // "properties" | "add" | "presets"
        property bool inspectorVisible: true

        Component.onCompleted: {
            if (screen && screen.name === Quickshell.screens[0].name)
                Panels.registry[name] = win;
        }
        Timer { id: closing; interval: Theme.animSlow + 60 }

        onOpenChanged: {
            if (open) {
                inspectorVisible = true;
                Wallpaper.refresh();
                WidgetPresets.editingPresetId = WidgetPresets.activePresetId;
                const list = WidgetPresets.editingWidgets;
                if (list.length > 0 && !WidgetPresets.selectedWidget)
                    WidgetPresets.selectedWidgetId = list[0].id;
                holder.forceActiveFocus();
            } else {
                WidgetPresets.save();
                if (Panels.instantClose) closing.stop();
                else closing.restart();
            }
        }

        readonly property var selWidget: WidgetPresets.selectedWidget

        function patchSelected(patch) {
            if (!win.selWidget) return;
            WidgetPresets.updateWidget(win.selWidget.id, patch);
        }

        function typeMeta(t) {
            return WidgetPresets.widgetTypes.find(x => x.type === t) ?? { type: t, label: t, glyph: "\uf009", desc: "" };
        }

        FocusScope {
            id: holder
            anchors.fill: parent
            focus: win.open
            Keys.onEscapePressed: Panels.close()
            Keys.onDeletePressed: {
                if (win.selWidget) WidgetPresets.deleteWidget(win.selWidget.id);
            }

            // Subtle dark scrim (fades out when previewing whole desktop with inspector hidden)
            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0, 0, 0, (win.open && win.inspectorVisible) ? 0.22 : 0)
                Behavior on color { ColorAnimation { duration: Theme.anim } }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        WidgetPresets.selectedWidgetId = "";
                        holder.forceActiveFocus();
                    }
                }
            }

            // Alignment grid overlay when snapToGrid is enabled and inspector is visible
            Canvas {
                id: gridCanvas
                anchors.fill: parent
                visible: win.open && win.inspectorVisible && WidgetPresets.snapToGrid
                opacity: 0.18
                property int step: Math.max(10, WidgetPresets.gridSize * 2)
                onStepChanged: requestPaint()
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onVisibleChanged: if (visible) requestPaint()
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    const s = Math.max(10, step);
                    ctx.strokeStyle = "#ffffff";
                    ctx.lineWidth = 1;
                    ctx.beginPath();
                    for (let x = 0; x < width; x += s) {
                        ctx.moveTo(x + 0.5, 0);
                        ctx.lineTo(x + 0.5, height);
                    }
                    for (let y = 0; y < height; y += s) {
                        ctx.moveTo(0, y + 0.5);
                        ctx.lineTo(width, y + 0.5);
                    }
                    ctx.stroke();
                }
            }

            // ==================== Interactive Widget Canvas ====================
            Item {
                id: canvasLayer
                anchors.fill: parent

                Repeater {
                    model: win.visible ? WidgetPresets.editingWidgets : []
                    delegate: Item {
                        id: wBox
                        required property var modelData
                        required property int index

                        readonly property bool isSelected: WidgetPresets.selectedWidgetId === modelData.id
                        property bool dragging: false
                        property bool resizing: false
                        property bool rotating: false
                        property real liveX: modelData.x ?? 40
                        property real liveY: modelData.y ?? 60
                        property real liveW: modelData.width ?? 300
                        property real liveH: modelData.height ?? 150
                        property real liveRot: modelData.rotation ?? 0

                        onModelDataChanged: {
                            if (!dragging && !resizing && !rotating) {
                                liveX = modelData.x ?? 40;
                                liveY = modelData.y ?? 60;
                                liveW = modelData.width ?? 300;
                                liveH = modelData.height ?? 150;
                                liveRot = modelData.rotation ?? 0;
                            }
                        }

                        x: dragging ? liveX : (modelData.x ?? 40)
                        y: dragging ? liveY : (modelData.y ?? 60)
                        width: resizing ? liveW : (modelData.width ?? 300)
                        height: resizing ? liveH : (modelData.height ?? 150)
                        rotation: rotating ? liveRot : (modelData.rotation ?? 0)
                        z: isSelected ? 20 : index + 1

                        DesktopWidgetView {
                            id: wView
                            anchors.fill: parent
                            widget: wBox.modelData
                            editMode: true
                        }

                        // Drag-to-move mouse area over widget body
                        MouseArea {
                            id: moveMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: wBox.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                            property real startMouseX: 0
                            property real startMouseY: 0
                            property real origX: 0
                            property real origY: 0

                            onPressed: m => {
                                WidgetPresets.selectedWidgetId = wBox.modelData.id;
                                holder.forceActiveFocus();
                                const pt = moveMa.mapToItem(canvasLayer, m.x, m.y);
                                startMouseX = pt.x;
                                startMouseY = pt.y;
                                origX = wBox.modelData.x ?? 40;
                                origY = wBox.modelData.y ?? 60;
                                wBox.liveX = origX;
                                wBox.liveY = origY;
                                wBox.dragging = true;
                            }
                            onDoubleClicked: {
                                win.inspectorVisible = true;
                            }
                            onPositionChanged: m => {
                                if (!pressed || !wBox.dragging) return;
                                const pt = moveMa.mapToItem(canvasLayer, m.x, m.y);
                                const nx = Math.max(0, Math.min(canvasLayer.width - wBox.width, origX + (pt.x - startMouseX)));
                                const ny = Math.max(0, Math.min(canvasLayer.height - wBox.height, origY + (pt.y - startMouseY)));
                                wBox.liveX = WidgetPresets.snap(nx);
                                wBox.liveY = WidgetPresets.snap(ny);
                            }
                            onReleased: {
                                if (wBox.dragging) {
                                    wBox.dragging = false;
                                    WidgetPresets.updateWidget(wBox.modelData.id, {
                                        x: Math.round(wBox.liveX),
                                        y: Math.round(wBox.liveY)
                                    });
                                }
                            }
                            onCanceled: wBox.dragging = false
                        }

                        // Selection outline matching widget shape & corner radius
                        Rectangle {
                            anchors.centerIn: parent
                            width: (wView.isCircularCard ? Math.min(parent.width, parent.height) : parent.width) + 4
                            height: (wView.isCircularCard ? Math.min(parent.width, parent.height) : parent.height) + 4
                            radius: wView.cardRadius + 2
                            color: "transparent"
                            border.width: wBox.isSelected ? 2 : (moveMa.containsMouse ? 1 : 0)
                            border.color: wBox.isSelected ? Theme.accent : Qt.rgba(1, 1, 1, 0.45)
                        }

                        // Top rotation handle on selected widget
                        Item {
                            visible: wBox.isSelected
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: -30
                            width: 24; height: 30

                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: 18; width: 2; height: 12
                                color: Theme.accent
                            }
                            Rectangle {
                                id: rotKnob
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: 0; width: 22; height: 22; radius: 11
                                color: Theme.accent
                                border.width: 2; border.color: Theme.bg
                                Icon {
                                    anchors.centerIn: parent
                                    text: "\uf01e"
                                    font.pixelSize: 10
                                    tint: Theme.onAccent
                                }
                                MouseArea {
                                    id: rotMa
                                    anchors.fill: parent
                                    anchors.margins: -5
                                    cursorShape: Qt.CrossCursor
                                    onPressed: {
                                        wBox.liveRot = wBox.modelData.rotation ?? 0;
                                        wBox.rotating = true;
                                    }
                                    onPositionChanged: m => {
                                        if (!pressed || !wBox.rotating) return;
                                        const pt = rotMa.mapToItem(canvasLayer, m.x, m.y);
                                        const cx = wBox.x + wBox.width / 2;
                                        const cy = wBox.y + wBox.height / 2;
                                        let deg = Math.atan2(pt.y - cy, pt.x - cx) * 180 / Math.PI + 90;
                                        while (deg > 180) deg -= 360;
                                        while (deg < -180) deg += 360;
                                        if (WidgetPresets.snapToGrid)
                                            deg = Math.round(deg / 5) * 5;
                                        else
                                            deg = Math.round(deg);
                                        wBox.liveRot = deg;
                                    }
                                    onReleased: {
                                        if (wBox.rotating) {
                                            wBox.rotating = false;
                                            WidgetPresets.updateWidget(wBox.modelData.id, {
                                                rotation: Math.round(wBox.liveRot)
                                            });
                                        }
                                    }
                                    onCanceled: wBox.rotating = false
                                }
                            }
                        }

                        // Floating header badge on selected widget
                        Rectangle {
                            visible: wBox.isSelected
                            y: wBox.y < 68 ? wBox.height + 8 : -62
                            x: 0
                            height: 28
                            width: Math.max(badgeRow.implicitWidth + 16, 160)
                            radius: 8
                            color: Theme.bg
                            border.width: 1
                            border.color: Theme.accent

                            RowLayout {
                                id: badgeRow
                                anchors { fill: parent; leftMargin: 8; rightMargin: 6 }
                                spacing: 6
                                Icon {
                                    text: win.typeMeta(wBox.modelData.type).glyph
                                    font.pixelSize: 11
                                    tint: Theme.accent
                                }
                                Label {
                                    text: win.typeMeta(wBox.modelData.type).label
                                        + "  (" + Math.round(wBox.x) + ", " + Math.round(wBox.y) + ") · "
                                        + Math.round(wBox.width) + "×" + Math.round(wBox.height)
                                        + (Math.round(wBox.rotation) !== 0 ? (" · " + Math.round(wBox.rotation) + "°") : "")
                                    font.pixelSize: Theme.fsS - 1
                                    font.weight: Font.DemiBold
                                }
                                IconButton {
                                    glyph: "\uf24d"
                                    size: 20; iconSize: 10
                                    onClicked: WidgetPresets.duplicateWidget(wBox.modelData.id)
                                }
                                IconButton {
                                    glyph: "\uf1f8"
                                    size: 20; iconSize: 10
                                    onClicked: WidgetPresets.deleteWidget(wBox.modelData.id)
                                }
                            }
                        }

                        // Right edge resize handle
                        Rectangle {
                            visible: wBox.isSelected
                            anchors.right: parent.right
                            anchors.rightMargin: -6
                            anchors.verticalCenter: parent.verticalCenter
                            width: 12; height: Math.min(48, parent.height * 0.5)
                            radius: 6
                            color: Theme.accent
                            border.width: 1; border.color: Theme.bg
                            MouseArea {
                                id: rightResizeMa
                                anchors.fill: parent
                                anchors.margins: -4
                                cursorShape: Qt.SizeHorCursor
                                property real startX: 0
                                property real origW: 0
                                onPressed: m => {
                                    const pt = rightResizeMa.mapToItem(canvasLayer, m.x, m.y);
                                    startX = pt.x;
                                    origW = wBox.modelData.width ?? 300;
                                    wBox.liveW = origW;
                                    wBox.liveH = wBox.modelData.height ?? 150;
                                    wBox.resizing = true;
                                }
                                onPositionChanged: m => {
                                    if (!pressed || !wBox.resizing) return;
                                    const pt = rightResizeMa.mapToItem(canvasLayer, m.x, m.y);
                                    const nw = Math.max(96, Math.min(canvasLayer.width - wBox.x, origW + (pt.x - startX)));
                                    wBox.liveW = WidgetPresets.snap(nw);
                                }
                                onReleased: {
                                    if (wBox.resizing) {
                                        wBox.resizing = false;
                                        WidgetPresets.updateWidget(wBox.modelData.id, { width: Math.round(wBox.liveW) });
                                    }
                                }
                                onCanceled: wBox.resizing = false
                            }
                        }

                        // Bottom edge resize handle
                        Rectangle {
                            visible: wBox.isSelected
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: -6
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: Math.min(48, parent.width * 0.5); height: 12
                            radius: 6
                            color: Theme.accent
                            border.width: 1; border.color: Theme.bg
                            MouseArea {
                                id: bottomResizeMa
                                anchors.fill: parent
                                anchors.margins: -4
                                cursorShape: Qt.SizeVerCursor
                                property real startY: 0
                                property real origH: 0
                                onPressed: m => {
                                    const pt = bottomResizeMa.mapToItem(canvasLayer, m.x, m.y);
                                    startY = pt.y;
                                    origH = wBox.modelData.height ?? 150;
                                    wBox.liveW = wBox.modelData.width ?? 300;
                                    wBox.liveH = origH;
                                    wBox.resizing = true;
                                }
                                onPositionChanged: m => {
                                    if (!pressed || !wBox.resizing) return;
                                    const pt = bottomResizeMa.mapToItem(canvasLayer, m.x, m.y);
                                    const nh = Math.max(48, Math.min(canvasLayer.height - wBox.y, origH + (pt.y - startY)));
                                    wBox.liveH = WidgetPresets.snap(nh);
                                }
                                onReleased: {
                                    if (wBox.resizing) {
                                        wBox.resizing = false;
                                        WidgetPresets.updateWidget(wBox.modelData.id, { height: Math.round(wBox.liveH) });
                                    }
                                }
                                onCanceled: wBox.resizing = false
                            }
                        }

                        // Bottom-right corner resize handle
                        Rectangle {
                            visible: wBox.isSelected
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.rightMargin: -7
                            anchors.bottomMargin: -7
                            width: 16; height: 16
                            radius: 8
                            color: Theme.accent
                            border.width: 2; border.color: Theme.bg
                            MouseArea {
                                id: cornerResizeMa
                                anchors.fill: parent
                                anchors.margins: -4
                                cursorShape: Qt.SizeFDiagCursor
                                property real startX: 0
                                property real startY: 0
                                property real origW: 0
                                property real origH: 0
                                onPressed: m => {
                                    const pt = cornerResizeMa.mapToItem(canvasLayer, m.x, m.y);
                                    startX = pt.x;
                                    startY = pt.y;
                                    origW = wBox.modelData.width ?? 300;
                                    origH = wBox.modelData.height ?? 150;
                                    wBox.liveW = origW;
                                    wBox.liveH = origH;
                                    wBox.resizing = true;
                                }
                                onPositionChanged: m => {
                                    if (!pressed || !wBox.resizing) return;
                                    const pt = cornerResizeMa.mapToItem(canvasLayer, m.x, m.y);
                                    const nw = Math.max(96, Math.min(canvasLayer.width - wBox.x, origW + (pt.x - startX)));
                                    const nh = Math.max(48, Math.min(canvasLayer.height - wBox.y, origH + (pt.y - startY)));
                                    wBox.liveW = WidgetPresets.snap(nw);
                                    wBox.liveH = WidgetPresets.snap(nh);
                                }
                                onReleased: {
                                    if (wBox.resizing) {
                                        wBox.resizing = false;
                                        WidgetPresets.updateWidget(wBox.modelData.id, {
                                            width: Math.round(wBox.liveW),
                                            height: Math.round(wBox.liveH)
                                        });
                                    }
                                }
                                onCanceled: wBox.resizing = false
                            }
                        }
                    }
                }
            }

            // ==================== Top Floating Status Banner ====================
            Rectangle {
                anchors.top: parent.top
                anchors.topMargin: 14
                anchors.horizontalCenter: parent.horizontalCenter
                height: 40
                width: bannerRow.implicitWidth + 28
                radius: 20
                color: Theme.panel
                border.width: 1
                border.color: Theme.border
                z: 45

                RowLayout {
                    id: bannerRow
                    anchors.centerIn: parent
                    spacing: 12

                    Icon { text: "\uf009"; tint: Theme.accent; font.pixelSize: 14 }
                    Label {
                        text: "Editing Preset: " + (WidgetPresets.editingPreset?.name ?? "Default")
                        font.weight: Font.DemiBold
                    }
                    Rectangle { width: 1; height: 18; color: Theme.border }
                    Label {
                        text: (WidgetPresets.editingPresetId === WidgetPresets.activePresetId)
                            ? "Active on current wallpaper"
                            : ("Current wallpaper uses: " + (WidgetPresets.activePreset?.name ?? "Default"))
                        font.pixelSize: Theme.fsS
                        color: (WidgetPresets.editingPresetId === WidgetPresets.activePresetId) ? Theme.ok : Theme.subtext
                    }
                    Button {
                        visible: WidgetPresets.editingPresetId !== WidgetPresets.activePresetId && Wallpaper.current !== ""
                        text: "Use on Current Wallpaper"
                        primary: true
                        implicitHeight: 26
                        onClicked: WidgetPresets.assignPresetToWallpaper(Wallpaper.current, WidgetPresets.editingPresetId)
                    }
                    Rectangle { width: 1; height: 18; color: Theme.border }
                    Button {
                        text: win.inspectorVisible ? "Hide Panel (Preview)" : "Show Panel"
                        glyph: win.inspectorVisible ? "\uf070" : "\uf06e"
                        implicitHeight: 28
                        onClicked: win.inspectorVisible = !win.inspectorVisible
                    }
                    Button {
                        text: "Done"
                        glyph: "\uf00c"
                        primary: true
                        implicitHeight: 28
                        onClicked: Panels.close()
                    }
                }
            }

            // ==================== Dockable Inspector Panel ====================
            PopupCard {
                id: inspector
                shown: win.open && win.inspectorVisible
                visible: opacity > 0.01
                width: 430
                height: parent.height - 32
                y: 16
                x: WidgetPresets.inspectorSide === "left" ? 16 : (parent.width - width - 16)
                slideX: WidgetPresets.inspectorSide === "left" ? -28 : 28
                z: 50
                clip: true

                Behavior on x { NumberAnimation { duration: Theme.animSlow; easing.type: Easing.OutQuint } }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 10

                    // Inspector Header
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        IconButton {
                            glyph: WidgetPresets.inspectorSide === "left" ? "\uf061" : "\uf060"
                            size: 30; iconSize: 12
                            onClicked: WidgetPresets.inspectorSide = (WidgetPresets.inspectorSide === "left" ? "right" : "left")
                        }
                        Column {
                            Layout.fillWidth: true
                            Label { text: "Widget Editor"; font.pixelSize: Theme.fsL; font.weight: Font.Bold }
                            Label {
                                text: WidgetPresets.editingWidgets.length + " widgets in \"" + (WidgetPresets.editingPreset?.name ?? "Default") + "\""
                                font.pixelSize: Theme.fsS
                                color: Theme.subtext
                            }
                        }
                        Chip {
                            text: "Snap"
                            glyph: "\uf00a"
                            active: WidgetPresets.snapToGrid
                            onClicked: WidgetPresets.snapToGrid = !WidgetPresets.snapToGrid
                        }
                        IconButton {
                            glyph: "\uf070"
                            size: 30; iconSize: 12
                            onClicked: win.inspectorVisible = false
                        }
                        IconButton {
                            glyph: "\uf00d"
                            size: 30; iconSize: 12
                            onClicked: Panels.close()
                        }
                    }

                    // Tab Bar
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        Repeater {
                            model: [
                                { id: "properties", label: "Properties", glyph: "\uf1de" },
                                { id: "add",        label: "Add Widget", glyph: "\uf067" },
                                { id: "presets",    label: "Presets & Wallpapers", glyph: "\uf03e" }
                            ]
                            delegate: Rectangle {
                                required property var modelData
                                readonly property bool cur: win.activeTab === modelData.id
                                Layout.fillWidth: true
                                height: 34
                                radius: Theme.radiusS + 2
                                color: cur ? Theme.accent : (tabMa.containsMouse ? Theme.surface3 : Theme.surface2)
                                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                Row {
                                    anchors.centerIn: parent
                                    spacing: 6
                                    Icon { text: modelData.glyph; font.pixelSize: 11; tint: cur ? Theme.onAccent : Theme.subtext }
                                    Label {
                                        text: modelData.label
                                        font.pixelSize: Theme.fsS
                                        font.weight: cur ? Font.DemiBold : Font.Medium
                                        color: cur ? Theme.onAccent : Theme.text
                                    }
                                }
                                MouseArea {
                                    id: tabMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: win.activeTab = modelData.id
                                }
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border }

                    // ==================== Tab Content Scroll Area ====================
                    Flickable {
                        id: tabScroll
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        contentHeight: tabBody.implicitHeight + 28
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        ColumnLayout {
                            id: tabBody
                            width: tabScroll.width
                            spacing: 12

                            // =========================================================================
                            // TAB 1: PRESETS & WALLPAPER ASSIGNMENT
                            // =========================================================================
                            ColumnLayout {
                                Layout.fillWidth: true
                                visible: win.activeTab === "presets"
                                spacing: 10

                                Label {
                                    text: "WIDGET PRESETS"
                                    color: Theme.accent
                                    font.pixelSize: Theme.fsS
                                    font.weight: Font.Bold
                                    font.letterSpacing: 0.8
                                }
                                Label {
                                    Layout.fillWidth: true
                                    wrapMode: Text.WordWrap
                                    text: "Select a preset to edit its widgets. Any wallpaper without a specific preset automatically uses the Default preset."
                                    font.pixelSize: Theme.fsS
                                    color: Theme.subtext
                                }

                                // List of presets
                                Repeater {
                                    model: win.visible && win.activeTab === "presets" ? WidgetPresets.presetList : []
                                    delegate: Rectangle {
                                        required property var modelData
                                        readonly property bool isEditing: WidgetPresets.editingPresetId === modelData.id
                                        readonly property bool isActiveForCurrentWp: WidgetPresets.activePresetId === modelData.id
                                        Layout.fillWidth: true
                                        height: 46
                                        radius: Theme.radiusS + 2
                                        color: isEditing ? Theme.accentDim : Theme.surface2
                                        border.width: isEditing ? 1.5 : 1
                                        border.color: isEditing ? Theme.accent : Theme.border

                                        RowLayout {
                                            anchors { fill: parent; leftMargin: 12; rightMargin: 10 }
                                            spacing: 8

                                            Icon {
                                                text: modelData.id === "default" ? "\uf005" : "\uf009"
                                                font.pixelSize: 13
                                                tint: isEditing ? Theme.accent : Theme.subtext
                                            }
                                            Column {
                                                Layout.fillWidth: true
                                                Label {
                                                    text: modelData.name + (modelData.id === "default" ? " (Fallback)" : "")
                                                    font.weight: isEditing ? Font.Bold : Font.Medium
                                                }
                                                Label {
                                                    text: (modelData.widgets?.length ?? 0) + " widgets" + (isActiveForCurrentWp ? " · Active on current wallpaper" : "")
                                                    font.pixelSize: Theme.fsS - 1
                                                    color: isActiveForCurrentWp ? Theme.accent : Theme.subtext
                                                }
                                            }
                                            Button {
                                                text: isEditing ? "Editing" : "Edit"
                                                primary: isEditing
                                                implicitHeight: 28
                                                onClicked: {
                                                    WidgetPresets.editingPresetId = modelData.id;
                                                    const w = WidgetPresets.editingWidgets;
                                                    WidgetPresets.selectedWidgetId = w.length > 0 ? w[0].id : "";
                                                }
                                            }
                                            IconButton {
                                                visible: modelData.id !== "default"
                                                glyph: "\uf1f8"
                                                size: 28; iconSize: 11
                                                onClicked: WidgetPresets.deletePreset(modelData.id)
                                            }
                                        }
                                    }
                                }

                                // Create new preset card
                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: createCol.implicitHeight + 20
                                    radius: Theme.radiusS + 2
                                    color: Theme.surface2
                                    border.width: 1; border.color: Theme.border

                                    ColumnLayout {
                                        id: createCol
                                        anchors { fill: parent; margins: 10 }
                                        spacing: 8
                                        Label { text: "Create New Preset"; font.weight: Font.DemiBold; font.pixelSize: Theme.fsS + 1 }
                                        TextField {
                                            id: newPresetNameInput
                                            Layout.fillWidth: true
                                            height: 34
                                            placeholder: "Preset name (e.g. Minimal, Cyberpunk, Work)…"
                                        }
                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 8
                                            Button {
                                                Layout.fillWidth: true
                                                text: "Clone Current"
                                                glyph: "\uf24d"
                                                primary: true
                                                onClicked: {
                                                    WidgetPresets.createPreset(newPresetNameInput.text, WidgetPresets.editingPresetId);
                                                    newPresetNameInput.text = "";
                                                }
                                            }
                                            Button {
                                                Layout.fillWidth: true
                                                text: "Create Starter"
                                                glyph: "\uf067"
                                                onClicked: {
                                                    WidgetPresets.createPreset(newPresetNameInput.text, "");
                                                    newPresetNameInput.text = "";
                                                }
                                            }
                                        }
                                    }
                                }

                                // Rename or Reset currently editing preset
                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: manageCol.implicitHeight + 20
                                    radius: Theme.radiusS + 2
                                    color: Theme.surface2
                                    border.width: 1; border.color: Theme.border

                                    ColumnLayout {
                                        id: manageCol
                                        anchors { fill: parent; margins: 10 }
                                        spacing: 8
                                        Label {
                                            text: "Manage \"" + (WidgetPresets.editingPreset?.name ?? "Default") + "\""
                                            font.weight: Font.DemiBold
                                            font.pixelSize: Theme.fsS + 1
                                        }
                                        RowLayout {
                                            visible: WidgetPresets.editingPresetId !== "default"
                                            Layout.fillWidth: true
                                            spacing: 8
                                            TextField {
                                                id: renameInput
                                                Layout.fillWidth: true
                                                height: 34
                                                placeholder: "New preset name…"
                                                text: WidgetPresets.editingPreset?.name ?? ""
                                                onAccepted: if (text.trim()) WidgetPresets.renamePreset(WidgetPresets.editingPresetId, text)
                                            }
                                            Button {
                                                text: "Rename"
                                                onClicked: if (renameInput.text.trim()) WidgetPresets.renamePreset(WidgetPresets.editingPresetId, renameInput.text)
                                            }
                                        }
                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 8
                                            Button {
                                                visible: WidgetPresets.editingPresetId === "default"
                                                Layout.fillWidth: true
                                                text: "Reset Default Preset to Factory Layout"
                                                glyph: "\uf021"
                                                danger: true
                                                onClicked: WidgetPresets.resetDefaultPreset()
                                            }
                                            Button {
                                                visible: WidgetPresets.editingPresetId !== "default"
                                                Layout.fillWidth: true
                                                text: "Delete Preset"
                                                glyph: "\uf1f8"
                                                danger: true
                                                onClicked: WidgetPresets.deletePreset(WidgetPresets.editingPresetId)
                                            }
                                        }
                                    }
                                }

                                Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border; Layout.topMargin: 4; Layout.bottomMargin: 4 }

                                // Current Wallpaper Preset Assignment
                                Label {
                                    text: "CURRENT WALLPAPER PRESET"
                                    color: Theme.accent
                                    font.pixelSize: Theme.fsS
                                    font.weight: Font.Bold
                                    font.letterSpacing: 0.8
                                }
                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: curWpCol.implicitHeight + 20
                                    radius: Theme.radiusS + 2
                                    color: Theme.surface2
                                    border.width: 1; border.color: Theme.border

                                    ColumnLayout {
                                        id: curWpCol
                                        anchors { fill: parent; margins: 10 }
                                        spacing: 8

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 10
                                            Rectangle {
                                                width: 64; height: 42; radius: 6; color: Theme.surface3; clip: true
                                                Image {
                                                    anchors.fill: parent
                                                    source: win.visible && Wallpaper.current ? "file://" + Wallpaper.current : ""
                                                    fillMode: Image.PreserveAspectCrop
                                                    sourceSize: Qt.size(128, 84)
                                                    asynchronous: true
                                                    cache: false
                                                }
                                            }
                                            Column {
                                                Layout.fillWidth: true
                                                Label {
                                                    width: parent.width
                                                    text: Wallpaper.current ? Wallpaper.current.split("/").pop() : "No wallpaper set"
                                                    font.weight: Font.DemiBold
                                                }
                                                Label {
                                                    width: parent.width
                                                    text: (WidgetPresets.wallpaperMap && WidgetPresets.wallpaperMap[Wallpaper.current])
                                                        ? ("Assigned: " + (WidgetPresets.presets[WidgetPresets.wallpaperMap[Wallpaper.current]]?.name ?? "Default"))
                                                        : "Unassigned — using Default preset"
                                                    font.pixelSize: Theme.fsS
                                                    color: Theme.subtext
                                                }
                                            }
                                        }

                                        Flow {
                                            Layout.fillWidth: true
                                            spacing: 6
                                            Repeater {
                                                model: win.visible && win.activeTab === "presets" ? WidgetPresets.presetList : []
                                                delegate: Chip {
                                                    required property var modelData
                                                    readonly property string assignedId: WidgetPresets.presetForWallpaper(Wallpaper.current)
                                                    text: modelData.id === "default" ? (modelData.name + " (Default)") : modelData.name
                                                    active: assignedId === modelData.id
                                                    onClicked: {
                                                        WidgetPresets.assignPresetToWallpaper(Wallpaper.current, modelData.id);
                                                        WidgetPresets.editingPresetId = modelData.id;
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                // Per-Wallpaper Assignment Library
                                Label {
                                    text: "ASSIGN PRESETS TO WALLPAPERS (" + Wallpaper.files.length + ")"
                                    color: Theme.accent
                                    font.pixelSize: Theme.fsS
                                    font.weight: Font.Bold
                                    font.letterSpacing: 0.8
                                    Layout.topMargin: 4
                                }
                                Label {
                                    Layout.fillWidth: true
                                    wrapMode: Text.WordWrap
                                    text: "Assign a widget preset to any wallpaper. Switching wallpapers will automatically switch your desktop widgets!"
                                    font.pixelSize: Theme.fsS
                                    color: Theme.subtext
                                }

                                Repeater {
                                    model: win.visible && win.activeTab === "presets" ? Wallpaper.files : []
                                    delegate: Rectangle {
                                        id: wpRow
                                        required property string modelData
                                        readonly property bool isCurrentWp: modelData === Wallpaper.current
                                        readonly property string wpPresetId: {
                                            const _ = WidgetPresets.revision;
                                            return WidgetPresets.presetForWallpaper(modelData);
                                        }
                                        readonly property bool hasExplicitPreset: {
                                            const _ = WidgetPresets.revision;
                                            return !!(WidgetPresets.wallpaperMap && WidgetPresets.wallpaperMap[modelData] && WidgetPresets.presets[WidgetPresets.wallpaperMap[modelData]]);
                                        }

                                        Layout.fillWidth: true
                                        implicitHeight: wpItemCol.implicitHeight + 16
                                        radius: Theme.radiusS + 2
                                        color: isCurrentWp ? Theme.accentDim : Theme.surface2
                                        border.width: isCurrentWp ? 1.5 : 1
                                        border.color: isCurrentWp ? Theme.accent : Theme.border

                                        ColumnLayout {
                                            id: wpItemCol
                                            anchors { fill: parent; margins: 8 }
                                            spacing: 6

                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 8
                                                Rectangle {
                                                    width: 56; height: 36; radius: 5; color: Theme.surface3; clip: true
                                                    Image {
                                                        anchors.fill: parent
                                                        source: "file://" + wpRow.modelData
                                                        fillMode: Image.PreserveAspectCrop
                                                        sourceSize: Qt.size(112, 72)
                                                        asynchronous: true
                                                        cache: false
                                                    }
                                                }
                                                Column {
                                                    Layout.fillWidth: true
                                                    Label {
                                                        width: parent.width
                                                        text: wpRow.modelData.split("/").pop()
                                                        font.pixelSize: Theme.fsS + 1
                                                        font.weight: wpRow.isCurrentWp ? Font.Bold : Font.Medium
                                                    }
                                                    Label {
                                                        width: parent.width
                                                        text: wpRow.hasExplicitPreset
                                                            ? ("Preset: " + (WidgetPresets.presets[wpRow.wpPresetId]?.name ?? "Default"))
                                                            : "Using Default preset"
                                                        font.pixelSize: Theme.fsS - 1
                                                        color: wpRow.hasExplicitPreset ? Theme.accent : Theme.subtext
                                                    }
                                                }
                                                Button {
                                                    text: wpRow.isCurrentWp ? "Active" : "Set Wallpaper"
                                                    primary: wpRow.isCurrentWp
                                                    implicitHeight: 26
                                                    onClicked: if (!wpRow.isCurrentWp) Wallpaper.apply(wpRow.modelData)
                                                }
                                            }

                                            Flow {
                                                Layout.fillWidth: true
                                                spacing: 4
                                                Repeater {
                                                    model: WidgetPresets.presetList
                                                    delegate: Chip {
                                                        required property var modelData
                                                        implicitHeight: 24
                                                        text: modelData.id === "default" ? "Default" : modelData.name
                                                        active: wpRow.wpPresetId === modelData.id
                                                        onClicked: WidgetPresets.assignPresetToWallpaper(wpRow.modelData, modelData.id)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // =========================================================================
                            // TAB 2: ADD WIDGETS
                            // =========================================================================
                            ColumnLayout {
                                Layout.fillWidth: true
                                visible: win.activeTab === "add"
                                spacing: 8

                                Label {
                                    text: "CLICK TO ADD WIDGET TO \"" + (WidgetPresets.editingPreset?.name ?? "Default").toUpperCase() + "\""
                                    color: Theme.accent
                                    font.pixelSize: Theme.fsS
                                    font.weight: Font.Bold
                                    font.letterSpacing: 0.8
                                }

                                Repeater {
                                    model: WidgetPresets.widgetTypes
                                    delegate: Rectangle {
                                        required property var modelData
                                        Layout.fillWidth: true
                                        height: 58
                                        radius: Theme.radiusS + 2
                                        color: addCardMa.containsMouse ? Theme.surface3 : Theme.surface2
                                        border.width: 1
                                        border.color: addCardMa.containsMouse ? Theme.accent : Theme.border
                                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                        RowLayout {
                                            anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                                            spacing: 12
                                            Rectangle {
                                                width: 36; height: 36; radius: 10
                                                color: Theme.accentDim
                                                Icon { anchors.centerIn: parent; text: modelData.glyph; font.pixelSize: 15; tint: Theme.accent }
                                            }
                                            Column {
                                                Layout.fillWidth: true
                                                Label { text: modelData.label; font.weight: Font.DemiBold }
                                                Label { width: parent.width; text: modelData.desc; font.pixelSize: Theme.fsS - 1; color: Theme.subtext }
                                            }
                                            Icon { text: "\uf067"; font.pixelSize: 13; tint: Theme.accent }
                                        }
                                        MouseArea {
                                            id: addCardMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                WidgetPresets.addWidget(modelData.type);
                                                win.activeTab = "properties";
                                            }
                                        }
                                    }
                                }
                            }

                            // =========================================================================
                            // TAB 3: SELECTED WIDGET PROPERTIES
                            // =========================================================================
                            ColumnLayout {
                                Layout.fillWidth: true
                                visible: win.activeTab === "properties"
                                spacing: 10

                                // Quick switcher for widgets in current preset
                                Label {
                                    text: "WIDGETS IN PRESET (" + WidgetPresets.editingWidgets.length + ")"
                                    color: Theme.accent
                                    font.pixelSize: Theme.fsS
                                    font.weight: Font.Bold
                                    font.letterSpacing: 0.8
                                }
                                Flow {
                                    Layout.fillWidth: true
                                    spacing: 6
                                    Repeater {
                                        model: win.visible && win.activeTab === "properties" ? WidgetPresets.editingWidgets : []
                                        delegate: Chip {
                                            required property var modelData
                                            required property int index
                                            readonly property var meta: win.typeMeta(modelData.type)
                                            glyph: meta.glyph
                                            text: (index + 1) + ". " + (modelData.type === "button" && modelData.label ? modelData.label : meta.label)
                                            active: WidgetPresets.selectedWidgetId === modelData.id
                                            onClicked: WidgetPresets.selectedWidgetId = modelData.id
                                        }
                                    }
                                    Chip {
                                        glyph: "\uf067"
                                        text: "Add…"
                                        onClicked: win.activeTab = "add"
                                    }
                                }

                                // Empty state if no widget is selected
                                Rectangle {
                                    visible: !win.selWidget
                                    Layout.fillWidth: true
                                    height: 120
                                    radius: Theme.radiusS + 2
                                    color: Theme.surface2
                                    border.width: 1; border.color: Theme.border
                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 8
                                        Icon { anchors.horizontalCenter: parent.horizontalCenter; text: "\uf245"; font.pixelSize: 22; tint: Theme.subtext }
                                        Label { anchors.horizontalCenter: parent.horizontalCenter; text: "Click any widget on the desktop to edit it"; color: Theme.subtext }
                                        Button {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: "Add a Widget"
                                            glyph: "\uf067"
                                            primary: true
                                            onClicked: win.activeTab = "add"
                                        }
                                    }
                                }

                                // Properties form when a widget is selected
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    visible: !!win.selWidget
                                    spacing: 10

                                    // Selected widget header & actions
                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 46
                                        radius: Theme.radiusS + 2
                                        color: Theme.surface2
                                        border.width: 1; border.color: Theme.border
                                        RowLayout {
                                            anchors { fill: parent; leftMargin: 12; rightMargin: 10 }
                                            spacing: 8
                                            Icon {
                                                text: win.selWidget ? win.typeMeta(win.selWidget.type).glyph : "\uf009"
                                                font.pixelSize: 15
                                                tint: Theme.accent
                                            }
                                            Label {
                                                Layout.fillWidth: true
                                                text: win.selWidget ? win.typeMeta(win.selWidget.type).label : ""
                                                font.weight: Font.Bold
                                            }
                                            Button {
                                                text: "Duplicate"
                                                glyph: "\uf24d"
                                                implicitHeight: 28
                                                onClicked: if (win.selWidget) WidgetPresets.duplicateWidget(win.selWidget.id)
                                            }
                                            Button {
                                                text: "Delete"
                                                glyph: "\uf1f8"
                                                danger: true
                                                implicitHeight: 28
                                                onClicked: if (win.selWidget) WidgetPresets.deleteWidget(win.selWidget.id)
                                            }
                                        }
                                    }

                                    // ==================== Geometry (Move, Resize & Rotate) ====================
                                    Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: geomCol.implicitHeight + 20
                                        radius: Theme.radiusS + 2
                                        color: Theme.surface2
                                        border.width: 1; border.color: Theme.border

                                        ColumnLayout {
                                            id: geomCol
                                            anchors { fill: parent; margins: 10 }
                                            spacing: 8

                                            Label { text: "Position, Size & Rotation"; font.weight: Font.DemiBold; font.pixelSize: Theme.fsS + 1 }

                                            GridLayout {
                                                Layout.fillWidth: true
                                                columns: 2
                                                rowSpacing: 6
                                                columnSpacing: 10

                                                // X
                                                RowLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 4
                                                    Label { text: "X"; width: 18; color: Theme.subtext; font.pixelSize: Theme.fsS }
                                                    IconButton { glyph: "\uf068"; size: 24; iconSize: 9; onClicked: win.patchSelected({ x: Math.max(0, (win.selWidget?.x ?? 0) - 10) }) }
                                                    Label { text: Math.round(win.selWidget?.x ?? 0) + " px"; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; font.pixelSize: Theme.fsS }
                                                    IconButton { glyph: "\uf067"; size: 24; iconSize: 9; onClicked: win.patchSelected({ x: (win.selWidget?.x ?? 0) + 10 }) }
                                                }
                                                // Y
                                                RowLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 4
                                                    Label { text: "Y"; width: 18; color: Theme.subtext; font.pixelSize: Theme.fsS }
                                                    IconButton { glyph: "\uf068"; size: 24; iconSize: 9; onClicked: win.patchSelected({ y: Math.max(0, (win.selWidget?.y ?? 0) - 10) }) }
                                                    Label { text: Math.round(win.selWidget?.y ?? 0) + " px"; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; font.pixelSize: Theme.fsS }
                                                    IconButton { glyph: "\uf067"; size: 24; iconSize: 9; onClicked: win.patchSelected({ y: (win.selWidget?.y ?? 0) + 10 }) }
                                                }
                                                // Width
                                                RowLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 4
                                                    Label { text: "W"; width: 18; color: Theme.subtext; font.pixelSize: Theme.fsS }
                                                    IconButton { glyph: "\uf068"; size: 24; iconSize: 9; onClicked: win.patchSelected({ width: Math.max(96, (win.selWidget?.width ?? 300) - 10) }) }
                                                    Label { text: Math.round(win.selWidget?.width ?? 300) + " px"; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; font.pixelSize: Theme.fsS }
                                                    IconButton { glyph: "\uf067"; size: 24; iconSize: 9; onClicked: win.patchSelected({ width: (win.selWidget?.width ?? 300) + 10 }) }
                                                }
                                                // Height
                                                RowLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 4
                                                    Label { text: "H"; width: 18; color: Theme.subtext; font.pixelSize: Theme.fsS }
                                                    IconButton { glyph: "\uf068"; size: 24; iconSize: 9; onClicked: win.patchSelected({ height: Math.max(48, (win.selWidget?.height ?? 150) - 10) }) }
                                                    Label { text: Math.round(win.selWidget?.height ?? 150) + " px"; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; font.pixelSize: Theme.fsS }
                                                    IconButton { glyph: "\uf067"; size: 24; iconSize: 9; onClicked: win.patchSelected({ height: (win.selWidget?.height ?? 150) + 10 }) }
                                                }
                                            }

                                            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border }

                                            // Rotation controls
                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 6
                                                Label {
                                                    text: "Rotation: " + Math.round(win.selWidget?.rotation ?? 0) + "°"
                                                    font.pixelSize: Theme.fsS
                                                    color: Theme.subtext
                                                    Layout.preferredWidth: 96
                                                }
                                                IconButton {
                                                    glyph: "\uf0e2"; size: 24; iconSize: 10
                                                    onClicked: {
                                                        let r = Math.round(win.selWidget?.rotation ?? 0) - 15;
                                                        if (r < -180) r += 360;
                                                        win.patchSelected({ rotation: r });
                                                    }
                                                }
                                                Slider {
                                                    Layout.fillWidth: true
                                                    value: (win.selWidget?.rotation ?? 0) + 180
                                                    max: 360
                                                    onMoved: v => win.patchSelected({ rotation: Math.round(v - 180) })
                                                }
                                                IconButton {
                                                    glyph: "\uf01e"; size: 24; iconSize: 10
                                                    onClicked: {
                                                        let r = Math.round(win.selWidget?.rotation ?? 0) + 15;
                                                        if (r > 180) r -= 360;
                                                        win.patchSelected({ rotation: r });
                                                    }
                                                }
                                            }

                                            Flow {
                                                Layout.fillWidth: true
                                                spacing: 5
                                                Repeater {
                                                    model: [-90, -45, -15, 0, 15, 45, 90, 180]
                                                    delegate: Chip {
                                                        required property int modelData
                                                        implicitHeight: 24
                                                        text: (modelData > 0 ? "+" : "") + modelData + "°"
                                                        active: Math.round(win.selWidget?.rotation ?? 0) === modelData
                                                        onClicked: win.patchSelected({ rotation: modelData })
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // ==================== Widget Color & Card Appearance ====================
                                    Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: colorCol.implicitHeight + 20
                                        radius: Theme.radiusS + 2
                                        color: Theme.surface2
                                        border.width: 1; border.color: Theme.border

                                        ColumnLayout {
                                            id: colorCol
                                            anchors { fill: parent; margins: 10 }
                                            spacing: 8

                                            Label { text: "Widget Color & Card Style"; font.weight: Font.DemiBold; font.pixelSize: Theme.fsS + 1 }

                                            Flow {
                                                Layout.fillWidth: true
                                                spacing: 6
                                                Repeater {
                                                    model: WidgetPresets.colorSwatches
                                                    delegate: Rectangle {
                                                        required property string modelData
                                                        readonly property bool isDefaultAccent: modelData === ""
                                                        readonly property bool active: (win.selWidget?.customColor ?? "") === modelData
                                                        width: isDefaultAccent ? 76 : 26
                                                        height: 26
                                                        radius: 13
                                                        color: isDefaultAccent ? Theme.accent : modelData
                                                        border.width: active ? 2.5 : 1
                                                        border.color: active ? Theme.text : Theme.border

                                                        Label {
                                                            visible: isDefaultAccent
                                                            anchors.centerIn: parent
                                                            text: "Accent"
                                                            font.pixelSize: Theme.fsS - 1
                                                            font.weight: Font.Bold
                                                            color: Theme.onAccent
                                                        }
                                                        MouseArea {
                                                            anchors.fill: parent
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: win.patchSelected({ customColor: modelData })
                                                        }
                                                    }
                                                }
                                            }

                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 8
                                                TextField {
                                                    id: customHexField
                                                    Layout.fillWidth: true
                                                    height: 32
                                                    placeholder: "Custom hex (#7aa2f7) or empty for Accent"
                                                    text: win.selWidget?.customColor ?? ""
                                                    onAccepted: {
                                                        const v = text.trim();
                                                        if (v === "" || /^#[0-9a-fA-F]{6}$/.test(v))
                                                            win.patchSelected({ customColor: v });
                                                    }
                                                }
                                                Button {
                                                    text: "Set Hex"
                                                    implicitHeight: 30
                                                    onClicked: {
                                                        const v = customHexField.text.trim();
                                                        if (v === "" || /^#[0-9a-fA-F]{6}$/.test(v))
                                                            win.patchSelected({ customColor: v });
                                                    }
                                                }
                                            }

                                            Button {
                                                Layout.fillWidth: true
                                                text: "Apply This Color to All Widgets in Preset"
                                                glyph: "\uf1fc"
                                                implicitHeight: 28
                                                onClicked: WidgetPresets.applyColorToPreset(WidgetPresets.editingPresetId, win.selWidget?.customColor ?? "")
                                            }

                                            RowLayout {
                                                Layout.fillWidth: true
                                                Label { Layout.fillWidth: true; text: "Show card background"; font.pixelSize: Theme.fsS + 1 }
                                                Toggle {
                                                    checked: win.selWidget?.showBg !== false
                                                    onToggled: v => win.patchSelected({ showBg: v })
                                                }
                                            }

                                            RowLayout {
                                                visible: win.selWidget?.showBg !== false
                                                Layout.fillWidth: true
                                                spacing: 8
                                                Label {
                                                    text: "Card opacity: " + ((win.selWidget?.bgOpacity ?? -1) < 0 ? "Theme" : Math.round((win.selWidget?.bgOpacity ?? 0.8) * 100) + "%")
                                                    font.pixelSize: Theme.fsS
                                                    color: Theme.subtext
                                                    Layout.preferredWidth: 120
                                                }
                                                Slider {
                                                    Layout.fillWidth: true
                                                    value: (win.selWidget?.bgOpacity ?? -1) < 0 ? Config.o.widgetsOpacity : (win.selWidget?.bgOpacity ?? 0.8)
                                                    max: 1.0
                                                    onMoved: v => win.patchSelected({ bgOpacity: Math.round(v * 100) / 100 })
                                                }
                                                Chip {
                                                    visible: (win.selWidget?.bgOpacity ?? -1) >= 0
                                                    text: "Auto"
                                                    implicitHeight: 22
                                                    onClicked: win.patchSelected({ bgOpacity: -1 })
                                                }
                                            }

                                            RowLayout {
                                                visible: win.selWidget?.showBg !== false && !(win.selWidget?.type === "analog-clock" && win.selWidget?.circularCard === true)
                                                Layout.fillWidth: true
                                                spacing: 8
                                                Label {
                                                    text: "Corner radius: " + ((win.selWidget?.cornerRadius ?? -1) < 0 ? "Theme" : Math.round(win.selWidget?.cornerRadius ?? 0) + "px")
                                                    font.pixelSize: Theme.fsS
                                                    color: Theme.subtext
                                                    Layout.preferredWidth: 120
                                                }
                                                Slider {
                                                    Layout.fillWidth: true
                                                    value: (win.selWidget?.cornerRadius ?? -1) < 0 ? Theme.radiusL : (win.selWidget?.cornerRadius ?? 0)
                                                    max: 120
                                                    onMoved: v => win.patchSelected({ cornerRadius: Math.round(v) })
                                                }
                                                Chip {
                                                    visible: (win.selWidget?.cornerRadius ?? -1) >= 0
                                                    text: "Theme"
                                                    implicitHeight: 22
                                                    onClicked: win.patchSelected({ cornerRadius: -1 })
                                                }
                                            }
                                        }
                                    }

                                    // ==================== TYPE-SPECIFIC PROPERTIES ====================

                                    // 1. DIGITAL CLOCK
                                    Rectangle {
                                        visible: win.selWidget?.type === "digital-clock"
                                        Layout.fillWidth: true
                                        implicitHeight: dClockCol.implicitHeight + 20
                                        radius: Theme.radiusS + 2
                                        color: Theme.surface2
                                        border.width: 1; border.color: Theme.border

                                        ColumnLayout {
                                            id: dClockCol
                                            anchors { fill: parent; margins: 10 }
                                            spacing: 8

                                            Label { text: "Digital Clock Settings"; font.weight: Font.DemiBold; font.pixelSize: Theme.fsS + 1 }

                                            Label { text: "Custom Time Format String (Qt format, e.g. HH:mm:ss, h:mm ap)"; font.pixelSize: Theme.fsS; color: Theme.subtext }
                                            TextField {
                                                Layout.fillWidth: true
                                                height: 34
                                                placeholder: "HH:mm"
                                                text: win.selWidget?.timeFormat ?? "HH:mm"
                                                onEdited: win.patchSelected({ timeFormat: text })
                                                onAccepted: win.patchSelected({ timeFormat: text })
                                            }
                                            Flow {
                                                Layout.fillWidth: true; spacing: 6
                                                Repeater {
                                                    model: ["HH:mm", "HH:mm:ss", "h:mm ap", "h:mm:ss ap", "hh:mm"]
                                                    delegate: Chip {
                                                        required property string modelData
                                                        implicitHeight: 24
                                                        text: modelData
                                                        active: (win.selWidget?.timeFormat ?? "") === modelData
                                                        onClicked: win.patchSelected({ timeFormat: modelData })
                                                    }
                                                }
                                            }

                                            // Time Text Color
                                            Label { text: "Time Text Color"; font.pixelSize: Theme.fsS; color: Theme.subtext }
                                            Flow {
                                                Layout.fillWidth: true
                                                spacing: 5
                                                Chip {
                                                    implicitHeight: 24
                                                    text: "Theme Text"
                                                    active: (win.selWidget?.timeColor ?? "") === ""
                                                    onClicked: win.patchSelected({ timeColor: "" })
                                                }
                                                Chip {
                                                    implicitHeight: 24
                                                    text: "Widget / Accent"
                                                    active: (win.selWidget?.timeColor ?? "") === "accent"
                                                    onClicked: win.patchSelected({ timeColor: "accent" })
                                                }
                                                Chip {
                                                    implicitHeight: 24
                                                    text: "Subtext"
                                                    active: (win.selWidget?.timeColor ?? "") === "subtext"
                                                    onClicked: win.patchSelected({ timeColor: "subtext" })
                                                }
                                                Repeater {
                                                    model: WidgetPresets.colorSwatches.filter(c => c !== "")
                                                    delegate: Rectangle {
                                                        required property string modelData
                                                        readonly property bool active: (win.selWidget?.timeColor ?? "") === modelData
                                                        width: 24; height: 24; radius: 12
                                                        color: modelData
                                                        border.width: active ? 2.5 : 1
                                                        border.color: active ? Theme.text : Theme.border
                                                        MouseArea {
                                                            anchors.fill: parent
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: win.patchSelected({ timeColor: modelData })
                                                        }
                                                    }
                                                }
                                            }
                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 6
                                                TextField {
                                                    id: timeHexInput
                                                    Layout.fillWidth: true
                                                    height: 30
                                                    placeholder: "Custom time hex (#ffffff)…"
                                                    text: /^#[0-9a-fA-F]{6}$/.test(win.selWidget?.timeColor ?? "") ? (win.selWidget?.timeColor ?? "") : ""
                                                    onAccepted: {
                                                        const v = text.trim();
                                                        if (v === "" || /^#[0-9a-fA-F]{6}$/.test(v))
                                                            win.patchSelected({ timeColor: v });
                                                    }
                                                }
                                                Button {
                                                    text: "Set"
                                                    implicitHeight: 28
                                                    onClicked: {
                                                        const v = timeHexInput.text.trim();
                                                        if (v === "" || /^#[0-9a-fA-F]{6}$/.test(v))
                                                            win.patchSelected({ timeColor: v });
                                                    }
                                                }
                                            }

                                            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border }

                                            RowLayout {
                                                Layout.fillWidth: true
                                                Label { Layout.fillWidth: true; text: "Show Date"; font.pixelSize: Theme.fsS + 1 }
                                                Toggle {
                                                    checked: win.selWidget?.showDate !== false
                                                    onToggled: v => win.patchSelected({ showDate: v })
                                                }
                                            }

                                            Label {
                                                visible: win.selWidget?.showDate !== false
                                                text: "Custom Date Format String (e.g. dddd, d MMMM or yyyy-MM-dd)"
                                                font.pixelSize: Theme.fsS; color: Theme.subtext
                                            }
                                            TextField {
                                                visible: win.selWidget?.showDate !== false
                                                Layout.fillWidth: true
                                                height: 34
                                                placeholder: "dddd, d MMMM"
                                                text: win.selWidget?.dateFormat ?? "dddd, d MMMM"
                                                onEdited: win.patchSelected({ dateFormat: text })
                                                onAccepted: win.patchSelected({ dateFormat: text })
                                            }
                                            Flow {
                                                visible: win.selWidget?.showDate !== false
                                                Layout.fillWidth: true; spacing: 6
                                                Repeater {
                                                    model: ["dddd, d MMMM", "ddd, MMM d, yyyy", "yyyy-MM-dd", "d MMMM yyyy", "dddd · dd/MM/yyyy"]
                                                    delegate: Chip {
                                                        required property string modelData
                                                        implicitHeight: 24
                                                        text: modelData
                                                        active: (win.selWidget?.dateFormat ?? "") === modelData
                                                        onClicked: win.patchSelected({ dateFormat: modelData })
                                                    }
                                                }
                                            }

                                            // Date Text Color
                                            Label {
                                                visible: win.selWidget?.showDate !== false
                                                text: "Date Text Color"
                                                font.pixelSize: Theme.fsS; color: Theme.subtext
                                            }
                                            Flow {
                                                visible: win.selWidget?.showDate !== false
                                                Layout.fillWidth: true
                                                spacing: 5
                                                Chip {
                                                    implicitHeight: 24
                                                    text: "Widget / Accent"
                                                    active: (win.selWidget?.dateColor ?? "") === ""
                                                    onClicked: win.patchSelected({ dateColor: "" })
                                                }
                                                Chip {
                                                    implicitHeight: 24
                                                    text: "Theme Text"
                                                    active: (win.selWidget?.dateColor ?? "") === "text"
                                                    onClicked: win.patchSelected({ dateColor: "text" })
                                                }
                                                Chip {
                                                    implicitHeight: 24
                                                    text: "Subtext"
                                                    active: (win.selWidget?.dateColor ?? "") === "subtext"
                                                    onClicked: win.patchSelected({ dateColor: "subtext" })
                                                }
                                                Repeater {
                                                    model: WidgetPresets.colorSwatches.filter(c => c !== "")
                                                    delegate: Rectangle {
                                                        required property string modelData
                                                        readonly property bool active: (win.selWidget?.dateColor ?? "") === modelData
                                                        width: 24; height: 24; radius: 12
                                                        color: modelData
                                                        border.width: active ? 2.5 : 1
                                                        border.color: active ? Theme.text : Theme.border
                                                        MouseArea {
                                                            anchors.fill: parent
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: win.patchSelected({ dateColor: modelData })
                                                        }
                                                    }
                                                }
                                            }
                                            RowLayout {
                                                visible: win.selWidget?.showDate !== false
                                                Layout.fillWidth: true
                                                spacing: 6
                                                TextField {
                                                    id: dateHexInput
                                                    Layout.fillWidth: true
                                                    height: 30
                                                    placeholder: "Custom date hex (#7aa2f7)…"
                                                    text: /^#[0-9a-fA-F]{6}$/.test(win.selWidget?.dateColor ?? "") ? (win.selWidget?.dateColor ?? "") : ""
                                                    onAccepted: {
                                                        const v = text.trim();
                                                        if (v === "" || /^#[0-9a-fA-F]{6}$/.test(v))
                                                            win.patchSelected({ dateColor: v });
                                                    }
                                                }
                                                Button {
                                                    text: "Set"
                                                    implicitHeight: 28
                                                    onClicked: {
                                                        const v = dateHexInput.text.trim();
                                                        if (v === "" || /^#[0-9a-fA-F]{6}$/.test(v))
                                                            win.patchSelected({ dateColor: v });
                                                    }
                                                }
                                            }

                                            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border }

                                            RowLayout {
                                                Layout.fillWidth: true
                                                Label { text: "Time Size (" + (win.selWidget?.timeSize ?? 64) + "px)"; font.pixelSize: Theme.fsS; Layout.preferredWidth: 120 }
                                                Slider {
                                                    Layout.fillWidth: true
                                                    value: (win.selWidget?.timeSize ?? 64) - 24
                                                    max: 96
                                                    onMoved: v => win.patchSelected({ timeSize: Math.round(v + 24) })
                                                }
                                            }
                                            RowLayout {
                                                visible: win.selWidget?.showDate !== false
                                                Layout.fillWidth: true
                                                Label { text: "Date Size (" + (win.selWidget?.dateSize ?? 15) + "px)"; font.pixelSize: Theme.fsS; Layout.preferredWidth: 120 }
                                                Slider {
                                                    Layout.fillWidth: true
                                                    value: (win.selWidget?.dateSize ?? 15) - 10
                                                    max: 26
                                                    onMoved: v => win.patchSelected({ dateSize: Math.round(v + 10) })
                                                }
                                            }
                                            RowLayout {
                                                Layout.fillWidth: true
                                                Label { Layout.fillWidth: true; text: "Alignment"; font.pixelSize: Theme.fsS + 1 }
                                                Segmented {
                                                    options: [
                                                        { label: "Left", value: "left" },
                                                        { label: "Center", value: "center" },
                                                        { label: "Right", value: "right" }
                                                    ]
                                                    current: win.selWidget?.align ?? "center"
                                                    onPicked: v => win.patchSelected({ align: v })
                                                }
                                            }
                                        }
                                    }

                                    // 2. ANALOG CLOCK
                                    Rectangle {
                                        visible: win.selWidget?.type === "analog-clock"
                                        Layout.fillWidth: true
                                        implicitHeight: aClockCol.implicitHeight + 20
                                        radius: Theme.radiusS + 2
                                        color: Theme.surface2
                                        border.width: 1; border.color: Theme.border

                                        ColumnLayout {
                                            id: aClockCol
                                            anchors { fill: parent; margins: 10 }
                                            spacing: 8
                                            Label { text: "Analog Clock Settings"; font.weight: Font.DemiBold; font.pixelSize: Theme.fsS + 1 }
                                            RowLayout {
                                                Layout.fillWidth: true
                                                Label { Layout.fillWidth: true; text: "Background Card Shape" }
                                                Segmented {
                                                    options: [
                                                        { label: "Rounded", value: false },
                                                        { label: "Circular", value: true }
                                                    ]
                                                    current: win.selWidget?.circularCard === true
                                                    onPicked: v => win.patchSelected({ circularCard: v })
                                                }
                                            }
                                            RowLayout {
                                                Layout.fillWidth: true
                                                Label { Layout.fillWidth: true; text: "Show Second Hand" }
                                                Toggle { checked: win.selWidget?.showSeconds !== false; onToggled: v => win.patchSelected({ showSeconds: v }) }
                                            }
                                            RowLayout {
                                                Layout.fillWidth: true
                                                Label { Layout.fillWidth: true; text: "Show Hour Numbers (1–12)" }
                                                Toggle { checked: win.selWidget?.showNumbers !== false; onToggled: v => win.patchSelected({ showNumbers: v }) }
                                            }
                                            RowLayout {
                                                Layout.fillWidth: true
                                                Label { Layout.fillWidth: true; text: "Show Dial Ticks" }
                                                Toggle { checked: win.selWidget?.showTicks !== false; onToggled: v => win.patchSelected({ showTicks: v }) }
                                            }
                                            RowLayout {
                                                Layout.fillWidth: true
                                                Label { Layout.fillWidth: true; text: "Show Date on Dial" }
                                                Toggle { checked: win.selWidget?.showDate !== false; onToggled: v => win.patchSelected({ showDate: v }) }
                                            }
                                        }
                                    }

                                    // 3. WEATHER
                                    Rectangle {
                                        visible: win.selWidget?.type === "weather"
                                        Layout.fillWidth: true
                                        implicitHeight: weatherCol.implicitHeight + 20
                                        radius: Theme.radiusS + 2
                                        color: Theme.surface2
                                        border.width: 1; border.color: Theme.border

                                        ColumnLayout {
                                            id: weatherCol
                                            anchors { fill: parent; margins: 10 }
                                            spacing: 8
                                            Label { text: "Weather Settings"; font.weight: Font.DemiBold; font.pixelSize: Theme.fsS + 1 }
                                            RowLayout {
                                                Layout.fillWidth: true
                                                Label { Layout.fillWidth: true; text: "Show Multi-Day Forecast" }
                                                Toggle { checked: win.selWidget?.showForecast !== false; onToggled: v => win.patchSelected({ showForecast: v }) }
                                            }
                                            RowLayout {
                                                Layout.fillWidth: true
                                                Label { Layout.fillWidth: true; text: "Show Humidity & Wind" }
                                                Toggle { checked: win.selWidget?.showDetails !== false; onToggled: v => win.patchSelected({ showDetails: v }) }
                                            }
                                            RowLayout {
                                                Layout.fillWidth: true
                                                Label { Layout.fillWidth: true; text: "Use Fahrenheit (°F)" }
                                                Toggle { checked: Config.o.weatherFahrenheit; onToggled: v => Config.o.weatherFahrenheit = v }
                                            }
                                            Label { text: "City (empty = auto-detect)"; font.pixelSize: Theme.fsS; color: Theme.subtext }
                                            TextField {
                                                Layout.fillWidth: true
                                                height: 34
                                                placeholder: "Auto-detect location…"
                                                text: Config.o.weatherCity
                                                onAccepted: Config.o.weatherCity = text
                                            }
                                        }
                                    }

                                    // 4. SYSTEM MONITOR
                                    Rectangle {
                                        visible: win.selWidget?.type === "system"
                                        Layout.fillWidth: true
                                        implicitHeight: sysCol.implicitHeight + 20
                                        radius: Theme.radiusS + 2
                                        color: Theme.surface2
                                        border.width: 1; border.color: Theme.border

                                        ColumnLayout {
                                            id: sysCol
                                            anchors { fill: parent; margins: 10 }
                                            spacing: 8
                                            Label { text: "System Monitor Sections"; font.weight: Font.DemiBold; font.pixelSize: Theme.fsS + 1 }
                                            RowLayout {
                                                Layout.fillWidth: true
                                                Label { Layout.fillWidth: true; text: "Show CPU Usage" }
                                                Toggle { checked: win.selWidget?.showCpu !== false; onToggled: v => win.patchSelected({ showCpu: v }) }
                                            }
                                            RowLayout {
                                                Layout.fillWidth: true
                                                Label { Layout.fillWidth: true; text: "Show RAM Usage" }
                                                Toggle { checked: win.selWidget?.showRam !== false; onToggled: v => win.patchSelected({ showRam: v }) }
                                            }
                                            RowLayout {
                                                Layout.fillWidth: true
                                                Label { Layout.fillWidth: true; text: "Show Disk Usage" }
                                                Toggle { checked: win.selWidget?.showDisk !== false; onToggled: v => win.patchSelected({ showDisk: v }) }
                                            }
                                        }
                                    }

                                    // 5. MEDIA PLAYER
                                    Rectangle {
                                        visible: win.selWidget?.type === "media"
                                        Layout.fillWidth: true
                                        implicitHeight: mediaCol.implicitHeight + 20
                                        radius: Theme.radiusS + 2
                                        color: Theme.surface2
                                        border.width: 1; border.color: Theme.border

                                        ColumnLayout {
                                            id: mediaCol
                                            anchors { fill: parent; margins: 10 }
                                            spacing: 8
                                            Label { text: "Media Player Settings"; font.weight: Font.DemiBold; font.pixelSize: Theme.fsS + 1 }
                                            RowLayout {
                                                Layout.fillWidth: true
                                                Label { Layout.fillWidth: true; text: "Show Album Art" }
                                                Toggle { checked: win.selWidget?.showArt !== false; onToggled: v => win.patchSelected({ showArt: v }) }
                                            }
                                            RowLayout {
                                                Layout.fillWidth: true
                                                Label { Layout.fillWidth: true; text: "Show Seek Bar" }
                                                Toggle { checked: win.selWidget?.showSeek !== false; onToggled: v => win.patchSelected({ showSeek: v }) }
                                            }
                                            RowLayout {
                                                Layout.fillWidth: true
                                                Label { Layout.fillWidth: true; text: "Show Player Volume Slider" }
                                                Toggle { checked: win.selWidget?.showVolume !== false; onToggled: v => win.patchSelected({ showVolume: v }) }
                                            }
                                            RowLayout {
                                                Layout.fillWidth: true
                                                Label { Layout.fillWidth: true; text: "Show Multi-Player Switcher" }
                                                Toggle { checked: win.selWidget?.showPlayerSelector !== false; onToggled: v => win.patchSelected({ showPlayerSelector: v }) }
                                            }
                                            RowLayout {
                                                Layout.fillWidth: true
                                                Label { Layout.fillWidth: true; text: "Hide Widget When Idle" }
                                                Toggle { checked: win.selWidget?.hideWhenIdle === true; onToggled: v => win.patchSelected({ hideWhenIdle: v }) }
                                            }
                                        }
                                    }

                                    // 6. AUDIO VISUALIZER
                                    Rectangle {
                                        visible: win.selWidget?.type === "visualizer"
                                        Layout.fillWidth: true
                                        implicitHeight: visCol.implicitHeight + 20
                                        radius: Theme.radiusS + 2
                                        color: Theme.surface2
                                        border.width: 1; border.color: Theme.border

                                        ColumnLayout {
                                            id: visCol
                                            anchors { fill: parent; margins: 10 }
                                            spacing: 8
                                            Label { text: "Audio Visualizer Settings"; font.weight: Font.DemiBold; font.pixelSize: Theme.fsS + 1 }

                                            RowLayout {
                                                Layout.fillWidth: true
                                                Label { Layout.fillWidth: true; text: "Style" }
                                                Segmented {
                                                    options: [
                                                        { label: "Bars", value: "bars" },
                                                        { label: "Waves", value: "waves" }
                                                    ]
                                                    current: win.selWidget?.mode ?? "bars"
                                                    onPicked: v => win.patchSelected({ mode: v })
                                                }
                                            }

                                            RowLayout {
                                                Layout.fillWidth: true
                                                Label { Layout.fillWidth: true; text: "Geometry / Shape" }
                                                Segmented {
                                                    options: [
                                                        { label: "Straight", value: "straight" },
                                                        { label: "Circular", value: "circular" }
                                                    ]
                                                    current: win.selWidget?.shape ?? "straight"
                                                    onPicked: v => win.patchSelected({ shape: v })
                                                }
                                            }

                                            RowLayout {
                                                Layout.fillWidth: true
                                                Label { text: "Bands (" + (win.selWidget?.barCount ?? 32) + ")"; font.pixelSize: Theme.fsS; Layout.preferredWidth: 100 }
                                                Slider {
                                                    Layout.fillWidth: true
                                                    value: (win.selWidget?.barCount ?? 32) - 8
                                                    max: 56
                                                    onMoved: v => win.patchSelected({ barCount: Math.round(v + 8) })
                                                }
                                            }

                                            RowLayout {
                                                Layout.fillWidth: true
                                                Label { text: "Gain (" + Number(win.selWidget?.sensitivity ?? 1.0).toFixed(1) + "×)"; font.pixelSize: Theme.fsS; Layout.preferredWidth: 100 }
                                                Slider {
                                                    Layout.fillWidth: true
                                                    value: (win.selWidget?.sensitivity ?? 1.0) - 0.3
                                                    max: 2.7
                                                    onMoved: v => win.patchSelected({ sensitivity: Math.round((v + 0.3) * 10) / 10 })
                                                }
                                            }

                                            RowLayout {
                                                visible: (win.selWidget?.mode ?? "bars") === "bars" && (win.selWidget?.shape ?? "straight") === "straight"
                                                Layout.fillWidth: true
                                                Label { Layout.fillWidth: true; text: "Mirror Bars Vertically" }
                                                Toggle { checked: win.selWidget?.mirror === true; onToggled: v => win.patchSelected({ mirror: v }) }
                                            }

                                            RowLayout {
                                                visible: (win.selWidget?.mode ?? "bars") === "waves"
                                                Layout.fillWidth: true
                                                Label { Layout.fillWidth: true; text: "Fill Wave Area" }
                                                Toggle { checked: win.selWidget?.fillWave !== false; onToggled: v => win.patchSelected({ fillWave: v }) }
                                            }
                                        }
                                    }

                                    // 7. AUDIO MIXER (Every section toggleable)
                                    Rectangle {
                                        visible: win.selWidget?.type === "audio-mixer"
                                        Layout.fillWidth: true
                                        implicitHeight: mixerCol.implicitHeight + 20
                                        radius: Theme.radiusS + 2
                                        color: Theme.surface2
                                        border.width: 1; border.color: Theme.border

                                        ColumnLayout {
                                            id: mixerCol
                                            anchors { fill: parent; margins: 10 }
                                            spacing: 8
                                            Label { text: "Audio Mixer Sections (Toggleable)"; font.weight: Font.DemiBold; font.pixelSize: Theme.fsS + 1 }

                                            RowLayout {
                                                Layout.fillWidth: true
                                                Label { Layout.fillWidth: true; text: "Master Output Volume" }
                                                Toggle { checked: win.selWidget?.showMaster !== false; onToggled: v => win.patchSelected({ showMaster: v }) }
                                            }
                                            RowLayout {
                                                Layout.fillWidth: true
                                                Label { Layout.fillWidth: true; text: "Microphone Input Volume" }
                                                Toggle { checked: win.selWidget?.showMic !== false; onToggled: v => win.patchSelected({ showMic: v }) }
                                            }
                                            RowLayout {
                                                Layout.fillWidth: true
                                                Label { Layout.fillWidth: true; text: "Output Devices & Volumes" }
                                                Toggle { checked: win.selWidget?.showOutputDevices !== false; onToggled: v => win.patchSelected({ showOutputDevices: v }) }
                                            }
                                            RowLayout {
                                                Layout.fillWidth: true
                                                Label { Layout.fillWidth: true; text: "Input Devices & Volumes" }
                                                Toggle { checked: win.selWidget?.showInputDevices === true; onToggled: v => win.patchSelected({ showInputDevices: v }) }
                                            }
                                            RowLayout {
                                                Layout.fillWidth: true
                                                Label { Layout.fillWidth: true; text: "Application Stream Volumes" }
                                                Toggle { checked: win.selWidget?.showApps !== false; onToggled: v => win.patchSelected({ showApps: v }) }
                                            }
                                        }
                                    }

                                    // 8. CALENDAR
                                    Rectangle {
                                        visible: win.selWidget?.type === "calendar"
                                        Layout.fillWidth: true
                                        implicitHeight: calCol.implicitHeight + 20
                                        radius: Theme.radiusS + 2
                                        color: Theme.surface2
                                        border.width: 1; border.color: Theme.border

                                        ColumnLayout {
                                            id: calCol
                                            anchors { fill: parent; margins: 10 }
                                            spacing: 8
                                            Label { text: "Calendar Settings"; font.weight: Font.DemiBold; font.pixelSize: Theme.fsS + 1 }

                                            RowLayout {
                                                Layout.fillWidth: true
                                                Label { Layout.fillWidth: true; text: "Show Month Navigation Header" }
                                                Toggle { checked: win.selWidget?.showHeader !== false; onToggled: v => win.patchSelected({ showHeader: v }) }
                                            }
                                            RowLayout {
                                                Layout.fillWidth: true
                                                Label { Layout.fillWidth: true; text: "Show Weekday Row" }
                                                Toggle { checked: win.selWidget?.showWeekdays !== false; onToggled: v => win.patchSelected({ showWeekdays: v }) }
                                            }
                                            RowLayout {
                                                Layout.fillWidth: true
                                                Label { Layout.fillWidth: true; text: "Start Week on Monday" }
                                                Toggle { checked: win.selWidget?.firstDayMonday !== false; onToggled: v => win.patchSelected({ firstDayMonday: v }) }
                                            }
                                        }
                                    }

                                    // 9. COMMAND BUTTON (with categorized example commands)
                                    Rectangle {
                                        visible: win.selWidget?.type === "button"
                                        Layout.fillWidth: true
                                        implicitHeight: btnCol.implicitHeight + 20
                                        radius: Theme.radiusS + 2
                                        color: Theme.surface2
                                        border.width: 1; border.color: Theme.border

                                        ColumnLayout {
                                            id: btnCol
                                            anchors { fill: parent; margins: 10 }
                                            spacing: 8
                                            Label { text: "Command Button Settings"; font.weight: Font.DemiBold; font.pixelSize: Theme.fsS + 1 }

                                            Label { text: "Button Label"; font.pixelSize: Theme.fsS; color: Theme.subtext }
                                            TextField {
                                                Layout.fillWidth: true
                                                height: 34
                                                placeholder: "Launcher"
                                                text: win.selWidget?.label ?? ""
                                                onEdited: win.patchSelected({ label: text })
                                                onAccepted: win.patchSelected({ label: text })
                                            }

                                            Label { text: "Sublabel (optional)"; font.pixelSize: Theme.fsS; color: Theme.subtext }
                                            TextField {
                                                Layout.fillWidth: true
                                                height: 32
                                                placeholder: "Optional secondary text…"
                                                text: win.selWidget?.sublabel ?? ""
                                                onEdited: win.patchSelected({ sublabel: text })
                                                onAccepted: win.patchSelected({ sublabel: text })
                                            }

                                            Label { text: "Command Executed on Click"; font.pixelSize: Theme.fsS; color: Theme.subtext }
                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 6
                                                TextField {
                                                    Layout.fillWidth: true
                                                    height: 34
                                                    placeholder: "Shell command…"
                                                    text: win.selWidget?.command ?? ""
                                                    onEdited: win.patchSelected({ command: text })
                                                    onAccepted: win.patchSelected({ command: text })
                                                }
                                                Button {
                                                    text: "Test"
                                                    glyph: "\uf04b"
                                                    implicitHeight: 32
                                                    onClicked: {
                                                        const cmd = (win.selWidget?.command ?? "").trim();
                                                        if (cmd) Quickshell.execDetached(["sh", "-c", cmd]);
                                                    }
                                                }
                                            }

                                            RowLayout {
                                                Layout.fillWidth: true
                                                Label { Layout.fillWidth: true; text: "Button Layout" }
                                                Segmented {
                                                    options: [
                                                        { label: "Row", value: "horizontal" },
                                                        { label: "Stack", value: "vertical" },
                                                        { label: "Icon", value: "icon-only" }
                                                    ]
                                                    current: win.selWidget?.layout ?? "horizontal"
                                                    onPicked: v => win.patchSelected({ layout: v, showLabel: v !== "icon-only" })
                                                }
                                            }

                                            Label { text: "Icon Glyph"; font.pixelSize: Theme.fsS; color: Theme.subtext }
                                            Flow {
                                                Layout.fillWidth: true
                                                spacing: 5
                                                Repeater {
                                                    model: WidgetPresets.iconChoices
                                                    delegate: Rectangle {
                                                        required property string modelData
                                                        readonly property bool cur: (win.selWidget?.glyph ?? "") === modelData
                                                        width: 30; height: 30; radius: 7
                                                        color: cur ? Theme.accent : Theme.surface3
                                                        Icon {
                                                            anchors.centerIn: parent
                                                            text: modelData
                                                            font.pixelSize: 13
                                                            tint: cur ? Theme.onAccent : Theme.text
                                                        }
                                                        MouseArea {
                                                            anchors.fill: parent
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: win.patchSelected({ glyph: modelData })
                                                        }
                                                    }
                                                }
                                            }

                                            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border; Layout.topMargin: 4; Layout.bottomMargin: 2 }

                                            Label {
                                                text: "Example Commands (Click to apply)"
                                                font.weight: Font.DemiBold
                                                font.pixelSize: Theme.fsS + 1
                                                color: Theme.accent
                                            }

                                            Repeater {
                                                model: ["Shell", "Apps", "Media", "Session"]
                                                delegate: ColumnLayout {
                                                    required property string modelData
                                                    Layout.fillWidth: true
                                                    spacing: 4
                                                    Label {
                                                        text: modelData
                                                        font.pixelSize: Theme.fsS
                                                        font.weight: Font.DemiBold
                                                        color: Theme.subtext
                                                    }
                                                    Flow {
                                                        Layout.fillWidth: true
                                                        spacing: 5
                                                        Repeater {
                                                            model: WidgetPresets.buttonExamples.filter(e => e.category === modelData)
                                                            delegate: Chip {
                                                                required property var modelData
                                                                implicitHeight: 26
                                                                glyph: modelData.glyph
                                                                text: modelData.label
                                                                active: (win.selWidget?.command ?? "") === modelData.cmd
                                                                onClicked: win.patchSelected({
                                                                    label: modelData.label,
                                                                    glyph: modelData.glyph,
                                                                    command: modelData.cmd
                                                                })
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
