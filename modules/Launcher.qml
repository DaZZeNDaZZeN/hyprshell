import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

// Application launcher: apps, windows, calculator ("=" or maths), commands (">"), web search ("?"), shell actions.
Variants {
    model: Quickshell.screens

    PanelOverlay {
        id: win
        required property var modelData
        screen: modelData
        name: "launcher"
        property var results: []
        property int sel: 0

        function actions() {
            return [
                { title: "Lock screen", sub: "Session", glyph: "\uf023", run: () => Actions.lock() },
                { title: "Log out", sub: "Session", glyph: "\uf2f5", run: () => Actions.logout() },
                { title: "Suspend", sub: "Session", glyph: "\uf186", run: () => Actions.suspend() },
                { title: "Reboot", sub: "Session", glyph: "\uf021", run: () => Actions.reboot() },
                { title: "Power off", sub: "Session", glyph: "\uf011", run: () => Actions.poweroff() },
                { title: "Settings", sub: "Shell", glyph: "\uf013", run: () => Panels.open("settings") },
                { title: "Wallpaper browser", sub: "Shell", glyph: "\uf03e", run: () => Panels.open("wallhaven") },
                { title: "Clipboard history", sub: "Shell", glyph: "\uf328", run: () => Panels.open("clipboard") },
                { title: "Control center", sub: "Shell", glyph: "\uf1de", run: () => Panels.open("controlcenter") },
                { title: "Notifications", sub: "Shell", glyph: "\uf0f3", run: () => Panels.open("notifications") },
                { title: "Screenshot region", sub: "Utility", glyph: "\uf030", run: () => Screenshot.start("region") },
                { title: "Screenshot screen", sub: "Utility", glyph: "\uf108", run: () => Screenshot.start("screen") },
                { title: "Toggle screen recording", sub: "Utility", glyph: "\uf03d", run: () => Recorder.toggle() },
                { title: "Toggle dark / light", sub: "Appearance", glyph: "\uf186", run: () => { Config.o.themeMode = Theme.dark ? "light" : "dark"; Config.o.staticTheme = "none"; } },
                { title: "Random wallpaper", sub: "Appearance", glyph: "\uf074", run: () => Wallpaper.random() },
            ];
        }
        function score(name, q) {
            name = name.toLowerCase();
            if (name === q) return 120;
            if (name.startsWith(q)) return 100;
            if (name.includes(" " + q)) return 70;
            if (name.includes(q)) return 50;
            let i = 0;
            for (const ch of name) { if (ch === q[i]) i++; if (i === q.length) return 20; }
            return 0;
        }
        function compute(q) {
            q = q.trim();
            const out = [];
            const apps = DesktopEntries.applications.values.filter(a => !a.noDisplay);
            const usage = Config.o.launcherUsage;
            const mkApp = (a, s) => ({ title: a.name, sub: a.genericName || a.comment || "", icon: Apps.iconFor(a.icon), score: s, run: () => { Apps.bump(a.id); a.execute(); } });
            if (q === "") {
                return apps.map(a => mkApp(a, (usage[a.id] ?? 0))).sort((x, y) => (y.score - x.score) || x.title.localeCompare(y.title)).slice(0, 40);
            }
            if (q.startsWith(">")) {
                const c = q.substring(1).trim();
                return [{ title: "Run: " + c, sub: "Shell command", glyph: "\uf120", run: () => Apps.run(c) }];
            }
            if (q.startsWith("?")) {
                const c = q.substring(1).trim();
                return [{ title: "Search the web for “" + c + "”", sub: Config.o.webSearchUrl, glyph: "\uf002", run: () => Quickshell.execDetached(["xdg-open", Config.o.webSearchUrl + encodeURIComponent(c)]) }];
            }
            const expr = q.startsWith("=") ? q.substring(1) : q;
            if (/^[0-9+\-*\/().,%^\s]+$/.test(expr) && /[0-9]/.test(expr) && /[+\-*\/%^]/.test(expr)) {
                try {
                    const v = Function("\"use strict\"; return (" + expr.replace(/\^/g, "**").replace(/,/g, ".") + ")")();
                    if (typeof v === "number" && isFinite(v)) {
                        const t = String(Math.round(v * 1e10) / 1e10);
                        out.push({ title: t, sub: "Calculator — Enter to copy", glyph: "\uf1ec", score: 200, run: () => Clipboard.copy(t) });
                    }
                } catch (e) {}
            }
            const lq = q.toLowerCase();
            for (const a of apps) {
                let s = Math.max(score(a.name, lq), (a.genericName ? score(a.genericName, lq) * 0.5 : 0),
                    (a.keywords || []).some(k => k.toLowerCase().includes(lq)) ? 25 : 0, (a.comment || "").toLowerCase().includes(lq) ? 10 : 0);
                if (s > 0) out.push(mkApp(a, s + Math.min(20, (usage[a.id] ?? 0))));
            }
            for (const t of ToplevelManager.toplevels.values) {
                const s = Math.max(score(t.title, lq), score(t.appId, lq)) * 0.8;
                if (s > 0) out.push({ title: t.title, sub: "Open window · " + t.appId, icon: Apps.iconFor(Apps.lookup(t.appId)?.icon ?? t.appId), score: s + 5, run: () => t.activate() });
            }
            for (const a of actions()) { const s = score(a.title, lq); if (s > 0) out.push(Object.assign({ score: s - 5 }, a)); }
            out.sort((x, y) => y.score - x.score);
            const top = out.slice(0, 40);
            top.push({ title: "Search the web for “" + q + "”", sub: "Web", glyph: "\uf002", run: () => Quickshell.execDetached(["xdg-open", Config.o.webSearchUrl + encodeURIComponent(q)]) });
            return top;
        }
        function update() { results = compute(input.text); sel = 0; list.positionViewAtBeginning(); }
        function activate() {
            const r = results[sel];
            if (!r) return;
            Panels.close();
            r.run();
        }
        onOpenChanged: if (open) Qt.callLater(() => { input.text = ""; update(); input.forceActiveFocus(); })

        PopupCard {
            id: card
            shown: win.open
            width: 660
            height: Math.min(560, 96 + Math.min(win.results.length, 7) * 56)
            x: (parent.width - width) / 2
            y: parent.height * 0.16
            slideY: -20
            Behavior on height { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }

            TextField {
                id: input
                anchors { top: parent.top; left: parent.left; right: parent.right; margins: 16 }
                height: 46
                glyph: "\uf002"
                placeholder: "Search apps, windows, actions…   (= calc  > run  ? web)"
                onEdited: win.update()
                onAccepted: win.activate()
                input.Keys.onDownPressed: win.sel = Math.min(win.results.length - 1, win.sel + 1)
                input.Keys.onUpPressed: win.sel = Math.max(0, win.sel - 1)
                input.Keys.onTabPressed: win.sel = (win.sel + 1) % Math.max(1, win.results.length)
                input.Keys.onEscapePressed: Panels.close()
            }
            ListView {
                id: list
                anchors { top: input.bottom; topMargin: 10; left: parent.left; right: parent.right; bottom: parent.bottom; margins: 10 }
                clip: true
                model: win.results
                currentIndex: win.sel
                highlightFollowsCurrentItem: true
                highlightMoveDuration: Theme.animFast
                boundsBehavior: Flickable.StopAtBounds
                highlight: Rectangle { radius: Theme.radiusS + 2; color: Theme.accentDim; border.width: 1; border.color: Theme.accentSoft }
                delegate: Item {
                    id: row
                    required property var modelData
                    required property int index
                    width: list.width; height: 56
                    Item {
                        id: iconBox
                        x: 12; anchors.verticalCenter: parent.verticalCenter; width: 34; height: 34
                        Image { anchors.fill: parent; visible: !!row.modelData.icon; source: row.modelData.icon ?? ""; sourceSize: Qt.size(68, 68); smooth: true }
                        Icon { anchors.centerIn: parent; visible: !row.modelData.icon; text: row.modelData.glyph ?? ""; font.pixelSize: 20; tint: Theme.accent }
                    }
                    Column {
                        anchors { left: iconBox.right; leftMargin: 12; right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                        Label { width: parent.width; text: row.modelData.title; font.weight: Font.Medium }
                        Label { width: parent.width; visible: text !== ""; text: row.modelData.sub; color: Theme.subtext; font.pixelSize: Theme.fsS }
                    }
                    MouseArea {
                        anchors.fill: parent; hoverEnabled: true
                        property real lastX: -1
                        property real lastY: -1
                        onPositionChanged: m => {
                            if (lastX >= 0 && (Math.abs(m.x - lastX) > 1 || Math.abs(m.y - lastY) > 1)) win.sel = row.index;
                            lastX = m.x; lastY = m.y;
                        }
                        onExited: { lastX = -1; lastY = -1; }
                        onClicked: { win.sel = row.index; win.activate(); }
                    }
                }
            }
        }
    }
}
