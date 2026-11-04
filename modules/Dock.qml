import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import qs.config
import qs.components
import qs.services

// Application dock: pinned + running apps, floating or attached, optional auto-hide, window count badge & live hover miniatures.
Variants {
    model: Config.o.dockEnabled ? Quickshell.screens.slice(0, 1) : []

    PanelWindow {
        id: win
        required property var modelData
        screen: modelData
        readonly property int isz: Config.o.dockIconSize
        readonly property int pad: 10
        readonly property bool floating: Config.o.dockFloating
        readonly property int gap: floating ? 8 : 0
        readonly property int dockH: isz + pad * 2 + 6
        readonly property bool autoHide: Config.o.dockAutoHide
        readonly property int activeWsId: Hyprland.monitorFor(win.screen)?.activeWorkspace?.id ?? 1
        readonly property bool wsEmpty: ToplevelManager.toplevels.values.length === 0
            || !Hyprland.toplevels.values.some(t => t.workspace && t.workspace.id === win.activeWsId)
        property bool pointerInside: false
        property string menuKey: ""
        property string hoverKey: ""
        property real hoverCenterX: win.width / 2
        readonly property var hoveredEntry: entries.find(e => e.key === hoverKey) ?? null
        readonly property bool previewShown: menuKey === "" && hoveredEntry !== null && hoveredEntry.tops.length > 0
        readonly property int extraTopSpace: 196
        readonly property bool hidden: autoHide && !(Config.o.dockKeepOnEmpty && wsEmpty) && !pointerInside && menuKey === "" && !previewShown && !Panels.active

        anchors { left: true; right: true; bottom: true }
        implicitHeight: dockH + gap * 2 + extraTopSpace
        exclusionMode: ExclusionMode.Normal
        exclusiveZone: autoHide ? 0 : dockH + gap * 2
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "hyprshell-dock"
        color: "transparent"
        mask: Region { item: win.hidden ? trigger : maskItem }

        // Apps shown in the dock: ordered by their workspace and leftmost window position (non-running pinned apps follow).
        readonly property var entries: {
            const tops = ToplevelManager.toplevels.values;
            const hyprTops = Hyprland.toplevels.values;
            const canon = id => (Apps.lookup(id)?.id ?? id).toLowerCase();
            const list = Config.o.dockPinned.map((p, idx) => ({
                id: p,
                key: canon(p),
                pinned: true,
                pinIdx: idx,
                tops: [],
                minWs: Infinity,
                minX: Infinity,
                minY: Infinity
            }));

            function winPos(t) {
                const ht = hyprTops.find(h => h && h.wayland === t);
                const ipc = ht ? ht.lastIpcObject : null;
                const rawWs = ht?.workspace?.id ?? ipc?.workspace?.id ?? 999999;
                const ws = rawWs > 0 ? rawWs : (100000 - rawWs);
                const x = (ipc && ipc.at && typeof ipc.at[0] === "number") ? ipc.at[0] : 999999;
                const y = (ipc && ipc.at && typeof ipc.at[1] === "number") ? ipc.at[1] : 999999;
                return { ws: ws, x: x, y: y };
            }

            let nextIdx = list.length;
            for (const t of tops) {
                const k = canon(t.appId);
                let e = list.find(x => x.key === k);
                if (!e) {
                    e = {
                        id: t.appId,
                        key: k,
                        pinned: false,
                        pinIdx: nextIdx++,
                        tops: [],
                        minWs: Infinity,
                        minX: Infinity,
                        minY: Infinity
                    };
                    list.push(e);
                }
                e.tops.push(t);
            }

            for (const e of list) {
                if (e.tops.length > 0) {
                    const withPos = e.tops.map(t => ({ t: t, pos: winPos(t) }));
                    withPos.sort((a, b) => (a.pos.ws - b.pos.ws) || (a.pos.x - b.pos.x) || (a.pos.y - b.pos.y));
                    e.tops = withPos.map(w => w.t);
                    e.minWs = withPos[0].pos.ws;
                    e.minX = withPos[0].pos.x;
                    e.minY = withPos[0].pos.y;
                }
            }

            list.sort((a, b) => {
                const aRun = a.tops.length > 0;
                const bRun = b.tops.length > 0;
                if (aRun !== bRun) return aRun ? -1 : 1;
                if (aRun) {
                    if (a.minWs !== b.minWs) return a.minWs - b.minWs;
                    if (a.minX !== b.minX) return a.minX - b.minX;
                    if (a.minY !== b.minY) return a.minY - b.minY;
                }
                return a.pinIdx - b.pinIdx;
            });

            return list;
        }
        function togglePin(e) {
            const cur = Config.o.dockPinned.slice();
            const i = cur.findIndex(p => (Apps.lookup(p)?.id ?? p).toLowerCase() === e.key);
            if (i >= 0) cur.splice(i, 1); else cur.push(e.id);
            Config.o.dockPinned = cur;
        }

        Timer { id: hideDelay; interval: 500; onTriggered: { win.pointerInside = false; win.hoverKey = ""; } }
        Timer { id: previewHideDelay; interval: 200; onTriggered: if (!previewHover.hovered) win.hoverKey = "" }
        HoverHandler {
            onHoveredChanged: {
                if (hovered) { hideDelay.stop(); win.pointerInside = true; Panels.refreshHypr(); }
                else { hideDelay.restart(); previewHideDelay.restart(); win.menuKey = ""; }
            }
        }
        Item { id: trigger; width: Math.max(420, dock.width); height: 3; anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter }
        Item {
            id: maskItem
            x: win.previewShown ? Math.min(dock.x, previewCard.x - 8) : dock.x
            y: win.previewShown || win.menuKey !== "" ? 0 : dock.y - 44
            width: win.previewShown ? Math.max(dock.x + dock.width, previewCard.x + previewCard.width + 8) - x : dock.width
            height: win.height - y
        }

        Component.onCompleted: Panels.registry["dock"] = { holder: dock }

        // Live window miniatures popup on hover
        Rectangle {
            id: previewCard
            visible: opacity > 0.01 && win.hoveredEntry !== null && win.hoveredEntry.tops.length > 0
            opacity: win.previewShown ? 1 : 0
            scale: win.previewShown ? 1 : 0.95
            Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
            Behavior on scale { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }
            width: previewRow.implicitWidth + 20
            height: 158
            x: Math.min(win.width - width - 12, Math.max(12, win.hoverCenterX - width / 2))
            y: dock.y - height - 10
            Behavior on x { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }
            radius: Theme.radiusL
            color: Theme.card
            border.width: 1
            border.color: Theme.border

            HoverHandler {
                id: previewHover
                onHoveredChanged: {
                    if (hovered) {
                        hideDelay.stop();
                        previewHideDelay.stop();
                        win.pointerInside = true;
                    } else {
                        previewHideDelay.restart();
                    }
                }
            }

            Row {
                id: previewRow
                anchors.centerIn: parent
                spacing: 10
                Repeater {
                    model: win.previewShown && win.hoveredEntry ? win.hoveredEntry.tops.slice(0, 5) : []
                    delegate: Rectangle {
                        id: thumbCard
                        required property var modelData
                        width: 188
                        height: 138
                        radius: Theme.radius
                        color: thumbMa.containsMouse ? Theme.surface3 : Theme.surface2
                        border.width: modelData.activated ? 2 : 1
                        border.color: modelData.activated ? Theme.accent : (thumbMa.containsMouse ? Theme.accentSoft : Theme.border)
                        Behavior on color { ColorAnimation { duration: Theme.animFast } }
                        clip: true

                        // Header with title + close
                        Item {
                            id: thumbHeader
                            x: 8; y: 5; width: parent.width - 16; height: 22
                            Label {
                                anchors { left: parent.left; right: closeWinBtn.left; rightMargin: 4; verticalCenter: parent.verticalCenter }
                                text: thumbCard.modelData.title || thumbCard.modelData.appId || "Window"
                                font.pixelSize: Theme.fsS
                                font.weight: Font.Medium
                                color: Theme.text
                            }
                            Rectangle {
                                id: closeWinBtn
                                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                                width: 18; height: 18; radius: 9
                                color: closeMa.containsMouse ? Theme.danger : "transparent"
                                Icon {
                                    anchors.centerIn: parent
                                    text: "\uf00d"
                                    font.pixelSize: 9
                                    tint: closeMa.containsMouse ? Theme.onAccent : Theme.subtext
                                }
                                MouseArea {
                                    id: closeMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: thumbCard.modelData.close()
                                }
                            }
                        }

                        // Static window miniature via ScreencopyView (captures single frame once on hover)
                        Rectangle {
                            anchors { left: parent.left; right: parent.right; top: thumbHeader.bottom; bottom: parent.bottom; margins: 6; topMargin: 2 }
                            radius: Theme.radiusS
                            color: Theme.bg
                            clip: true
                            ScreencopyView {
                                id: scv
                                anchors.fill: parent
                                captureSource: win.previewShown ? thumbCard.modelData : null
                                live: false
                                constraintSize: Qt.size(280, 170)
                            }
                        }

                        MouseArea {
                            id: thumbMa
                            anchors { left: parent.left; right: parent.right; top: thumbHeader.bottom; bottom: parent.bottom }
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                thumbCard.modelData.activate();
                                win.hoverKey = "";
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            id: dock
            readonly property real contentW: row.implicitWidth + win.pad * 2
            width: win.floating ? contentW : win.width
            height: win.dockH
            x: (win.width - width) / 2
            y: win.hidden ? win.height + 4 : win.height - height - win.gap
            Behavior on y { NumberAnimation { duration: Theme.animSlow; easing.type: Easing.OutQuint } }
            Behavior on width { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }
            opacity: win.hidden ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: Theme.anim } }
            radius: win.floating ? Theme.radiusL : 0
            color: Theme.dockPanel
            border.width: win.floating ? 1 : 0
            border.color: Theme.border

            Row {
                id: row
                anchors.centerIn: parent
                spacing: 6
                Repeater {
                    model: win.entries
                    delegate: Item {
                        id: item
                        required property var modelData
                        readonly property var entry: Apps.lookup(modelData.id)
                        readonly property int winCount: modelData.tops.length
                        readonly property bool running: winCount > 0
                        readonly property bool focused: running && modelData.tops.some(t => t.activated)
                        width: win.isz + 8; height: win.isz + 6

                        Rectangle {
                            anchors.fill: parent; radius: Theme.radiusS + 4
                            color: ma.containsMouse ? Theme.hover : "transparent"
                            Behavior on color { ColorAnimation { duration: Theme.animFast } }
                        }
                        Image {
                            id: icon
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: ma.containsMouse ? -4 : 0
                            width: win.isz; height: win.isz
                            sourceSize: Qt.size(win.isz * 2, win.isz * 2)
                            source: Apps.iconFor(entry?.icon ?? modelData.id)
                            smooth: true
                            scale: ma.pressed ? 0.88 : (ma.containsMouse ? 1.15 : 1)
                            Behavior on scale { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutBack } }
                            Behavior on y { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutBack } }
                        }

                        // Open window count badge
                        Rectangle {
                            visible: item.winCount > 0
                            anchors { right: parent.right; top: parent.top; rightMargin: 0; topMargin: -2 }
                            height: 18
                            width: Math.max(18, countLbl.implicitWidth + 8)
                            radius: 9
                            color: item.focused ? Theme.accent : Theme.surface3
                            border.width: 1.5
                            border.color: Theme.dockPanel
                            Label {
                                id: countLbl
                                anchors.centerIn: parent
                                text: item.winCount
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                color: item.focused ? Theme.onAccent : Theme.text
                            }
                        }

                        // Running indicator bar/dots at bottom
                        Row {
                            visible: item.running
                            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: -1 }
                            spacing: 3
                            Repeater {
                                model: Math.min(item.winCount, 4)
                                delegate: Rectangle {
                                    required property int index
                                    width: index === 0 && item.focused ? 12 : 5
                                    height: 4
                                    radius: 2
                                    color: item.focused ? Theme.accent : Theme.subtext
                                    Behavior on width { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutBack } }
                                }
                            }
                        }

                        MouseArea {
                            id: ma
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                            cursorShape: Qt.PointingHandCursor
                            onEntered: {
                                previewHideDelay.stop();
                                win.hoverCenterX = dock.x + row.x + item.x + item.width / 2;
                                win.hoverKey = item.modelData.key;
                            }
                            onExited: {
                                previewHideDelay.restart();
                            }
                            onClicked: m => {
                                if (m.button === Qt.RightButton) { win.menuKey = win.menuKey === item.modelData.key ? "" : item.modelData.key; return; }
                                win.menuKey = "";
                                if (m.button === Qt.MiddleButton || !item.running) {
                                    if (item.entry) item.entry.execute(); else Apps.run(item.modelData.id);
                                } else {
                                    const t = item.modelData.tops;
                                    const i = t.findIndex(x => x.activated);
                                    t[(i + 1) % t.length].activate();
                                }
                            }
                        }
                        // Simple tooltip only when app is not running (running apps show the live miniatures card)
                        Rectangle {
                            visible: ma.containsMouse && !item.running && win.menuKey === ""
                            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.top; bottomMargin: 8 }
                            width: tip.implicitWidth + 20; height: 26; radius: 8; color: Theme.card; border.width: 1; border.color: Theme.border
                            Label { id: tip; anchors.centerIn: parent; text: item.entry?.name ?? item.modelData.id; font.pixelSize: Theme.fsS + 1 }
                        }
                        // context menu
                        Rectangle {
                            id: menu
                            readonly property bool shown: win.menuKey === item.modelData.key
                            visible: opacity > 0.01
                            opacity: shown ? 1 : 0
                            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.top; bottomMargin: shown ? 10 : 0 }
                            Behavior on opacity { NumberAnimation { duration: Theme.anim } }
                            Behavior on anchors.bottomMargin { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }
                            width: 170; height: mcol.implicitHeight + 12; radius: Theme.radius
                            color: Theme.card; border.width: 1; border.color: Theme.border
                            Column {
                                id: mcol
                                anchors { fill: parent; margins: 6 }
                                Repeater {
                                    model: [
                                        { t: "Open new window", g: "\uf067", a: "new" },
                                        { t: item.modelData.pinned ? "Unpin from dock" : "Pin to dock", g: "\uf08d", a: "pin" },
                                        { t: "Close window" + (item.modelData.tops.length > 1 ? "s" : ""), g: "\uf00d", a: "close", off: !item.running },
                                    ].filter(x => !x.off)
                                    delegate: Rectangle {
                                        required property var modelData
                                        width: mcol.width; height: 32; radius: Theme.radiusS
                                        color: mm.containsMouse ? Theme.accentDim : "transparent"
                                        Row { x: 10; anchors.verticalCenter: parent.verticalCenter; spacing: 10
                                            Icon { text: modelData.g; font.pixelSize: 12; tint: Theme.subtext }
                                            Label { text: modelData.t; font.pixelSize: Theme.fsS + 1 } }
                                        MouseArea { id: mm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                win.menuKey = "";
                                                if (modelData.a === "new") { if (item.entry) item.entry.execute(); }
                                                else if (modelData.a === "pin") win.togglePin(item.modelData);
                                                else for (const t of item.modelData.tops) t.close();
                                            } }
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
