import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.config
import qs.components
import qs.services

// Application dock: pinned + running apps, floating or attached, optional auto-hide.
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
        property bool pointerInside: false
        property string menuKey: ""
        readonly property bool hidden: autoHide && !pointerInside && menuKey === "" && !Panels.active

        anchors { left: true; right: true; bottom: true }
        implicitHeight: dockH + gap * 2 + 70
        exclusionMode: ExclusionMode.Normal
        exclusiveZone: autoHide ? 0 : dockH + gap * 2
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "hyprshell-dock"
        color: "transparent"
        mask: Region { item: win.hidden ? trigger : maskItem }

        // Apps shown in the dock: pinned first, then other running apps.
        readonly property var entries: {
            const tops = ToplevelManager.toplevels.values;
            const canon = id => (Apps.lookup(id)?.id ?? id).toLowerCase();
            const list = Config.o.dockPinned.map(p => ({ id: p, key: canon(p), pinned: true, tops: [] }));
            for (const t of tops) {
                const k = canon(t.appId);
                let e = list.find(x => x.key === k);
                if (!e) { e = { id: t.appId, key: k, pinned: false, tops: [] }; list.push(e); }
                e.tops.push(t);
            }
            return list;
        }
        function togglePin(e) {
            const cur = Config.o.dockPinned.slice();
            const i = cur.findIndex(p => (Apps.lookup(p)?.id ?? p).toLowerCase() === e.key);
            if (i >= 0) cur.splice(i, 1); else cur.push(e.id);
            Config.o.dockPinned = cur;
        }

        Timer { id: hideDelay; interval: 500; onTriggered: win.pointerInside = false }
        HoverHandler {
            onHoveredChanged: { if (hovered) { hideDelay.stop(); win.pointerInside = true; } else { hideDelay.restart(); win.menuKey = ""; } }
        }
        Item { id: trigger; width: Math.max(420, dock.width); height: 3; anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter }
        Item { id: maskItem; x: dock.x; y: dock.y - 70; width: dock.width; height: dock.height + 70 }

        Component.onCompleted: Panels.registry["dock"] = { holder: dock }
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
            color: Theme.panel
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
                        readonly property bool running: modelData.tops.length > 0
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
                        Rectangle {
                            visible: item.running
                            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: -1 }
                            width: item.focused ? 18 : 6; height: 4; radius: 2
                            color: item.focused ? Theme.accent : Theme.subtext
                            Behavior on width { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutBack } }
                            Behavior on color { ColorAnimation { duration: Theme.anim } }
                        }
                        MouseArea {
                            id: ma
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                            cursorShape: Qt.PointingHandCursor
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
                        Rectangle {
                            visible: ma.containsMouse && win.menuKey === ""
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
