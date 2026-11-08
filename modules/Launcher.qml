import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

// Application launcher: apps, windows, calculator ("=" or maths via libqalculate), commands (">"), web search ("?"), shell actions.
Variants {
    model: Quickshell.screens

    PanelOverlay {
        id: win
        required property var modelData
        screen: modelData
        name: "launcher"
        property var results: []
        property int sel: 0
        property string calcExpr: ""
        property string calcResult: ""
        property string calcFull: ""
        property string pendingCalcExpr: ""

        function isCalcCandidate(q) {
            if (q.startsWith("=")) return q.substring(1).trim().length > 0;
            if (/^[0-9+\-*\/().,%^\s]+$/.test(q) && /[0-9]/.test(q) && /[+\-*\/%^]/.test(q)) return true;
            if (/^(0x[0-9a-f]+|0b[01]+|[0-9]+([.,][0-9]+)?)\s+[a-z°%$€£¥]+.*\b(to|in)\b\s+[a-z0-9°%$€£¥]+/i.test(q)) return true;
            if (/^(0x[0-9a-f]+|0b[01]+|[0-9]+).*\b(to|in)\s+(hex|bin|binary|oct|octal|dec|decimal|roman|base\b)/i.test(q)) return true;
            if (/\b(sqrt|cbrt|sin|cos|tan|asin|acos|atan|sinh|cosh|tanh|log|ln|exp|abs|ceil|floor|round|fact|factorial|binom|gcd|lcm|solve|integrate|diff|der|sum|product)\s*\(/i.test(q)) return true;
            return false;
        }

        Timer {
            id: qalcTimer
            interval: 80
            onTriggered: {
                if (!win.pendingCalcExpr) return;
                if (qalcProc.running) qalcProc.running = false;
                qalcProc.expr = win.pendingCalcExpr;
                qalcProc.command = ["qalc", "-u8", "-m", "500", "-s", "decimal comma off", win.pendingCalcExpr];
                qalcProc.running = true;
            }
        }

        Process {
            id: qalcProc
            property string expr: ""
            stdout: StdioCollector {
                onStreamFinished: {
                    const lines = text.trim().split("\n").map(l => l.trim()).filter(Boolean);
                    if (!lines.length) return;
                    if (lines.some(l => /^error:/i.test(l) || /^warning:.*misplaced operator/i.test(l))) return;
                    const eqLines = lines.filter(l => !/^warning:/i.test(l));
                    if (!eqLines.length) return;
                    const last = eqLines[eqLines.length - 1];
                    const parts = last.split(/\s+(?:=|≈)\s+/);
                    if (parts.length < 2) return;
                    const rhs = parts[parts.length - 1].trim();
                    if (!rhs) return;
                    win.calcExpr = qalcProc.expr;
                    win.calcResult = rhs;
                    win.calcFull = last;
                    const curQ = input.text.trim();
                    const curExpr = (curQ.startsWith("=") ? curQ.substring(1) : curQ).trim();
                    if (curExpr === qalcProc.expr) {
                        win.results = win.compute(input.text);
                    }
                }
            }
        }

        readonly property var actionList: [
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
            { title: "Toggle dark / light", sub: "Appearance", glyph: "\uf186", run: () => { Config.o.themeMode = Theme.dark ? "light" : "dark"; } },
            { title: "Random wallpaper", sub: "Appearance", glyph: "\uf074", run: () => Wallpaper.random() },
        ]
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
            const expr = (q.startsWith("=") ? q.substring(1) : q).trim();
            if (isCalcCandidate(q) && expr !== "") {
                if (calcExpr === expr && calcResult !== "") {
                    const res = calcResult;
                    out.push({
                        title: res,
                        sub: calcFull + "  ·  libqalculate — Enter to copy",
                        glyph: "\uf1ec",
                        score: 250,
                        run: () => Clipboard.copy(res)
                    });
                } else {
                    if (pendingCalcExpr !== expr) {
                        pendingCalcExpr = expr;
                        qalcTimer.restart();
                    }
                    if (/^[0-9+\-*\/().,%^\s]+$/.test(expr) && /[0-9]/.test(expr) && /[+\-*\/%^]/.test(expr)) {
                        try {
                            const v = Function("\"use strict\"; return (" + expr.replace(/\^/g, "**").replace(/,/g, ".") + ")")();
                            if (typeof v === "number" && isFinite(v)) {
                                const t = String(Math.round(v * 1e10) / 1e10);
                                out.push({ title: t, sub: "Calculator — Enter to copy", glyph: "\uf1ec", score: 200, run: () => Clipboard.copy(t) });
                            }
                        } catch (e) {}
                    }
                }
            } else {
                pendingCalcExpr = "";
                qalcTimer.stop();
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
            for (const a of actionList) { const s = score(a.title, lq); if (s > 0) out.push(Object.assign({ score: s - 5 }, a)); }
            out.sort((x, y) => y.score - x.score);
            const top = out.slice(0, 40);
            top.push({ title: "Search the web for “" + q + "”", sub: "Web", glyph: "\uf002", run: () => Quickshell.execDetached(["xdg-open", Config.o.webSearchUrl + encodeURIComponent(q)]) });
            return top;
        }
        function update() {
            mouseMoved = false;
            initMouseX = -1;
            initMouseY = -1;
            results = compute(input.text);
            sel = 0;
            list.positionViewAtBeginning();
        }
        function activate() {
            const r = results[sel];
            if (!r) return;
            Panels.close();
            r.run();
        }
        property bool mouseMoved: false
        property real initMouseX: -1
        property real initMouseY: -1
        HoverHandler {
            id: winHover
            onPointChanged: {
                if (!win.open) return;
                const p = point.position;
                if (win.initMouseX < 0) {
                    win.initMouseX = p.x;
                    win.initMouseY = p.y;
                } else if (Math.abs(p.x - win.initMouseX) > 2 || Math.abs(p.y - win.initMouseY) > 2) {
                    win.mouseMoved = true;
                    win.initMouseX = p.x;
                    win.initMouseY = p.y;
                }
            }
        }
        onOpenChanged: if (open) {
            mouseMoved = false;
            initMouseX = -1;
            initMouseY = -1;
            Qt.callLater(() => { calcExpr = ""; calcResult = ""; calcFull = ""; pendingCalcExpr = ""; input.text = ""; update(); input.forceActiveFocus(); });
        }
        onVisibleChanged: if (!visible) { results = []; qalcTimer.stop(); pendingCalcExpr = ""; }

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
                input.Keys.onDownPressed: { win.mouseMoved = false; win.initMouseX = -1; win.sel = Math.min(win.results.length - 1, win.sel + 1); }
                input.Keys.onUpPressed: { win.mouseMoved = false; win.initMouseX = -1; win.sel = Math.max(0, win.sel - 1); }
                input.Keys.onTabPressed: { win.mouseMoved = false; win.initMouseX = -1; win.sel = (win.sel + 1) % Math.max(1, win.results.length); }
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
                        onEntered: if (win.mouseMoved) win.sel = row.index
                        onPositionChanged: if (win.mouseMoved) win.sel = row.index
                        onClicked: { win.sel = row.index; win.activate(); }
                    }
                }
            }
        }
    }
}
