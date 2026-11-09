pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs.config
import qs.services

// Manages desktop widget presets, per-wallpaper preset assignments, and widget CRUD for the Desktop Widget Editor.
Singleton {
    id: root

    readonly property string storePath: Config.dir + "/widgets.json"
    property bool loaded: false
    property int revision: 0

    // Map of presetId -> { id, name, widgets: [ ... ] }
    property var presets: ({
        "default": {
            id: "default",
            name: "Default",
            widgets: root.factoryDefaultWidgets()
        }
    })

    // Map of wallpaperPath -> presetId
    property var wallpaperMap: ({})

    // Editor state
    property string editingPresetId: "default"
    property string selectedWidgetId: ""
    property bool snapToGrid: true
    property int gridSize: 10
    property string inspectorSide: "right" // "right" | "left"

    // Catalog of all 9 supported widget types
    readonly property var widgetTypes: [
        { type: "digital-clock", label: "Digital Clock", glyph: "\uf017", desc: "Time & date with custom format strings" },
        { type: "analog-clock",  label: "Analog Clock",  glyph: "\uf1da", desc: "Classic clock face with hour, minute & second hands" },
        { type: "weather",       label: "Weather",       glyph: "\uf0c2", desc: "Current temperature, conditions & multi-day forecast" },
        { type: "system",        label: "System Monitor",glyph: "\uf2db", desc: "Real-time CPU, RAM & Disk usage meters" },
        { type: "media",         label: "Media Player",  glyph: "\uf001", desc: "MPRIS album art, playback controls, seek & volume" },
        { type: "visualizer",    label: "Audio Visualizer", glyph: "\uf028", desc: "Bars or waves in straight or circular layout" },
        { type: "audio-mixer",   label: "Audio Mixer",   glyph: "\uf1de", desc: "Output/input devices & per-app volume mixer" },
        { type: "calendar",      label: "Calendar",      glyph: "\uf073", desc: "Interactive monthly calendar grid" },
        { type: "button",        label: "Command Button",glyph: "\uf120", desc: "Customizable button that runs any shell command" }
    ]

    // Categorized example commands for the Command Button widget
    readonly property var buttonExamples: [
        // Shell (Launcher & Settings)
        { category: "Shell", label: "Launcher", glyph: "\uf00a", cmd: "qs -c hyprshell ipc call shell toggle launcher" },
        { category: "Shell", label: "Settings", glyph: "\uf013", cmd: "qs -c hyprshell ipc call shell toggle settings" },
        { category: "Shell", label: "Control Center", glyph: "\uf1de", cmd: "qs -c hyprshell ipc call shell toggle controlcenter" },
        { category: "Shell", label: "Notifications", glyph: "\uf0f3", cmd: "qs -c hyprshell ipc call shell toggle notifications" },
        { category: "Shell", label: "Widget Editor", glyph: "\uf009", cmd: "qs -c hyprshell ipc call shell toggle widgeteditor" },
        // Apps (Kitty, Firefox, Dolphin)
        { category: "Apps", label: "Kitty", glyph: "\uf120", cmd: "kitty" },
        { category: "Apps", label: "Firefox", glyph: "\uf269", cmd: "firefox" },
        { category: "Apps", label: "Dolphin", glyph: "\uf07b", cmd: "dolphin" },
        // Media Player Control
        { category: "Media", label: "Play / Pause", glyph: "\uf04b", cmd: "qs -c hyprshell ipc call shell media play-pause" },
        { category: "Media", label: "Next Track", glyph: "\uf051", cmd: "qs -c hyprshell ipc call shell media next" },
        { category: "Media", label: "Previous Track", glyph: "\uf048", cmd: "qs -c hyprshell ipc call shell media prev" },
        // Session Control
        { category: "Session", label: "Lock Screen", glyph: "\uf023", cmd: "qs -c hyprshell ipc call shell lock" },
        { category: "Session", label: "Session Menu", glyph: "\uf011", cmd: "qs -c hyprshell ipc call shell toggle session" },
        { category: "Session", label: "Suspend", glyph: "\uf186", cmd: "systemctl suspend" },
        { category: "Session", label: "Logout", glyph: "\uf2f5", cmd: "command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'" },
        { category: "Session", label: "Reboot", glyph: "\uf021", cmd: "systemctl reboot" },
        { category: "Session", label: "Power Off", glyph: "\uf011", cmd: "systemctl poweroff" }
    ]

    readonly property var colorSwatches: [
        "", // "" = Follow Theme.accent
        "#7aa2f7", "#bb9af7", "#f7768e", "#9ece6a",
        "#e0af68", "#7dcfff", "#ff9e64", "#ebbcba",
        "#58c27d", "#f2555a", "#88c0d0", "#ffffff"
    ]

    readonly property var iconChoices: [
        "\uf00a", "\uf013", "\uf120", "\uf269", "\uf07b", "\uf04b", "\uf04c", "\uf051",
        "\uf048", "\uf023", "\uf011", "\uf186", "\uf2f5", "\uf021", "\uf0f3", "\uf1de",
        "\uf009", "\uf002", "\uf030", "\uf03d", "\uf03e", "\uf328", "\uf028", "\uf130",
        "\uf185", "\uf0e7", "\uf015", "\uf1fc", "\uf11b", "\uf1c0", "\uf073", "\uf017"
    ]

    function factoryDefaultWidgets() {
        return [
            {
                id: "w-clock",
                type: "digital-clock",
                x: 40, y: 60, width: 310, height: 150,
                customColor: "",
                showBg: true,
                bgOpacity: -1,
                timeFormat: "HH:mm",
                dateFormat: "dddd, d MMMM",
                showDate: true,
                timeSize: 68,
                dateSize: 15,
                align: "center"
            },
            {
                id: "w-weather",
                type: "weather",
                x: 40, y: 224, width: 310, height: 130,
                customColor: "",
                showBg: true,
                bgOpacity: -1,
                showForecast: true,
                showDetails: true
            },
            {
                id: "w-system",
                type: "system",
                x: 40, y: 368, width: 310, height: 140,
                customColor: "",
                showBg: true,
                bgOpacity: -1,
                showCpu: true,
                showRam: true,
                showDisk: true
            },
            {
                id: "w-media",
                type: "media",
                x: 40, y: 522, width: 310, height: 176,
                customColor: "",
                showBg: true,
                bgOpacity: -1,
                showArt: true,
                showSeek: true,
                showVolume: true,
                showPlayerSelector: true,
                hideWhenIdle: true
            }
        ];
    }

    function createWidgetTemplate(type, indexOffset) {
        const off = ((indexOffset ?? 0) % 6) * 24;
        const base = {
            id: "w-" + type + "-" + Date.now() + "-" + Math.floor(Math.random() * 1000),
            type: type,
            x: 380 + off,
            y: 80 + off,
            width: 300,
            height: 150,
            customColor: "",
            showBg: true,
            bgOpacity: -1
        };
        if (type === "digital-clock") {
            return Object.assign(base, {
                width: 310, height: 150,
                timeFormat: Config.o.barClock24h ? "HH:mm" : "h:mm ap",
                dateFormat: "dddd, d MMMM",
                showDate: true,
                timeSize: 64,
                dateSize: 15,
                align: "center"
            });
        }
        if (type === "analog-clock") {
            return Object.assign(base, {
                width: 220, height: 220,
                showSeconds: true,
                showNumbers: true,
                showTicks: true,
                showDate: true
            });
        }
        if (type === "weather") {
            return Object.assign(base, {
                width: 310, height: 132,
                showForecast: true,
                showDetails: true
            });
        }
        if (type === "system") {
            return Object.assign(base, {
                width: 310, height: 140,
                showCpu: true,
                showRam: true,
                showDisk: true
            });
        }
        if (type === "media") {
            return Object.assign(base, {
                width: 320, height: 180,
                showArt: true,
                showSeek: true,
                showVolume: true,
                showPlayerSelector: true,
                hideWhenIdle: false
            });
        }
        if (type === "visualizer") {
            return Object.assign(base, {
                width: 320, height: 180,
                mode: "bars",        // "bars" | "waves"
                shape: "straight",   // "straight" | "circular"
                barCount: 32,
                sensitivity: 1.0,
                mirror: false,
                fillWave: true
            });
        }
        if (type === "audio-mixer") {
            return Object.assign(base, {
                width: 340, height: 340,
                showMaster: true,
                showMic: true,
                showOutputDevices: true,
                showInputDevices: false,
                showApps: true
            });
        }
        if (type === "calendar") {
            return Object.assign(base, {
                width: 300, height: 310,
                showHeader: true,
                showWeekdays: true,
                firstDayMonday: true
            });
        }
        if (type === "button") {
            return Object.assign(base, {
                width: 170, height: 64,
                label: "Launcher",
                sublabel: "",
                glyph: "\uf00a",
                command: "qs -c hyprshell ipc call shell toggle launcher",
                showLabel: true,
                layout: "horizontal" // "horizontal" | "vertical" | "icon-only"
            });
        }
        return base;
    }

    // Preset list sorted with "default" first
    readonly property var presetList: {
        const _ = root.revision;
        const p = root.presets || ({});
        const list = [];
        if (p["default"]) list.push(p["default"]);
        for (const k of Object.keys(p)) {
            if (k !== "default" && p[k]) list.push(p[k]);
        }
        return list;
    }

    // Active preset for the current wallpaper (falls back to "default" if unassigned or missing)
    readonly property string activePresetId: {
        const _ = root.revision;
        const wp = Wallpaper.current;
        if (wp && root.wallpaperMap && root.wallpaperMap[wp]) {
            const pid = root.wallpaperMap[wp];
            if (root.presets && root.presets[pid]) return pid;
        }
        return "default";
    }

    readonly property var activePreset: {
        const _ = root.revision;
        return (root.presets && root.presets[root.activePresetId])
            ? root.presets[root.activePresetId]
            : (root.presets["default"] ?? { id: "default", name: "Default", widgets: [] });
    }

    readonly property var activeWidgets: {
        const _ = root.revision;
        return root.activePreset?.widgets ?? [];
    }

    readonly property var editingPreset: {
        const _ = root.revision;
        return (root.presets && root.presets[root.editingPresetId])
            ? root.presets[root.editingPresetId]
            : root.activePreset;
    }

    readonly property var editingWidgets: {
        const _ = root.revision;
        return root.editingPreset?.widgets ?? [];
    }

    readonly property var selectedWidget: {
        const _ = root.revision;
        if (!root.selectedWidgetId) return null;
        return root.editingWidgets.find(w => w && w.id === root.selectedWidgetId) ?? null;
    }

    function presetForWallpaper(wp) {
        if (!wp) return "default";
        const pid = root.wallpaperMap ? root.wallpaperMap[wp] : "";
        return (pid && root.presets && root.presets[pid]) ? pid : "default";
    }

    function assignPresetToWallpaper(wp, presetId) {
        if (!wp) return;
        const nextMap = Object.assign({}, root.wallpaperMap);
        if (!presetId || presetId === "default") {
            delete nextMap[wp];
        } else if (root.presets[presetId]) {
            nextMap[wp] = presetId;
        }
        root.wallpaperMap = nextMap;
        root.revision++;
        save();
    }

    function createPreset(name, cloneFromId) {
        const cleanName = (name || "").trim() || ("Preset " + (Object.keys(root.presets).length));
        const id = "preset-" + Date.now() + "-" + Math.floor(Math.random() * 100);
        const srcPreset = cloneFromId && root.presets[cloneFromId] ? root.presets[cloneFromId] : null;
        const clonedWidgets = srcPreset
            ? JSON.parse(JSON.stringify(srcPreset.widgets || [])).map((w, idx) => Object.assign({}, w, { id: "w-" + w.type + "-" + Date.now() + "-" + idx }))
            : [createWidgetTemplate("digital-clock", 0)];
        const next = Object.assign({}, root.presets);
        next[id] = {
            id: id,
            name: cleanName,
            widgets: clonedWidgets
        };
        root.presets = next;
        root.editingPresetId = id;
        root.selectedWidgetId = clonedWidgets.length > 0 ? clonedWidgets[0].id : "";
        root.revision++;
        save();
        return id;
    }

    function renamePreset(presetId, newName) {
        const clean = (newName || "").trim();
        if (!clean || !root.presets[presetId]) return;
        const next = Object.assign({}, root.presets);
        next[presetId] = Object.assign({}, next[presetId], { name: clean });
        root.presets = next;
        root.revision++;
        save();
    }

    function deletePreset(presetId) {
        if (!presetId || presetId === "default" || !root.presets[presetId]) return;
        const next = Object.assign({}, root.presets);
        delete next[presetId];
        root.presets = next;

        const nextMap = Object.assign({}, root.wallpaperMap);
        for (const wp of Object.keys(nextMap)) {
            if (nextMap[wp] === presetId) delete nextMap[wp];
        }
        root.wallpaperMap = nextMap;

        if (root.editingPresetId === presetId) {
            root.editingPresetId = "default";
            root.selectedWidgetId = "";
        }
        root.revision++;
        save();
    }

    function resetDefaultPreset() {
        const next = Object.assign({}, root.presets);
        next["default"] = {
            id: "default",
            name: "Default",
            widgets: root.factoryDefaultWidgets()
        };
        root.presets = next;
        root.selectedWidgetId = "";
        root.revision++;
        save();
    }

    function addWidget(type) {
        const pid = root.presets[root.editingPresetId] ? root.editingPresetId : "default";
        const curList = (root.presets[pid]?.widgets ?? []).slice();
        const w = createWidgetTemplate(type, curList.length);
        curList.push(w);
        const next = Object.assign({}, root.presets);
        next[pid] = Object.assign({}, next[pid], { widgets: curList });
        root.presets = next;
        root.selectedWidgetId = w.id;
        root.revision++;
        save();
        return w.id;
    }

    function updateWidget(widgetId, patch) {
        const pid = root.presets[root.editingPresetId] ? root.editingPresetId : "default";
        const curList = (root.presets[pid]?.widgets ?? []).slice();
        const idx = curList.findIndex(w => w && w.id === widgetId);
        if (idx < 0) return;
        curList[idx] = Object.assign({}, curList[idx], patch);
        const next = Object.assign({}, root.presets);
        next[pid] = Object.assign({}, next[pid], { widgets: curList });
        root.presets = next;
        root.revision++;
        saveTimer.restart();
    }

    function deleteWidget(widgetId) {
        const pid = root.presets[root.editingPresetId] ? root.editingPresetId : "default";
        const curList = (root.presets[pid]?.widgets ?? []).filter(w => w && w.id !== widgetId);
        const next = Object.assign({}, root.presets);
        next[pid] = Object.assign({}, next[pid], { widgets: curList });
        root.presets = next;
        if (root.selectedWidgetId === widgetId) {
            root.selectedWidgetId = curList.length > 0 ? curList[curList.length - 1].id : "";
        }
        root.revision++;
        save();
    }

    function duplicateWidget(widgetId) {
        const pid = root.presets[root.editingPresetId] ? root.editingPresetId : "default";
        const curList = (root.presets[pid]?.widgets ?? []).slice();
        const orig = curList.find(w => w && w.id === widgetId);
        if (!orig) return;
        const copy = JSON.parse(JSON.stringify(orig));
        copy.id = "w-" + copy.type + "-" + Date.now() + "-" + Math.floor(Math.random() * 1000);
        copy.x = (copy.x || 40) + 28;
        copy.y = (copy.y || 60) + 28;
        curList.push(copy);
        const next = Object.assign({}, root.presets);
        next[pid] = Object.assign({}, next[pid], { widgets: curList });
        root.presets = next;
        root.selectedWidgetId = copy.id;
        root.revision++;
        save();
    }

    function applyColorToPreset(presetId, colorHex) {
        const pid = root.presets[presetId] ? presetId : root.editingPresetId;
        if (!root.presets[pid]) return;
        const curList = (root.presets[pid].widgets || []).map(w => Object.assign({}, w, { customColor: colorHex }));
        const next = Object.assign({}, root.presets);
        next[pid] = Object.assign({}, next[pid], { widgets: curList });
        root.presets = next;
        root.revision++;
        save();
    }

    function snap(v) {
        if (!root.snapToGrid || root.gridSize <= 1) return Math.round(v);
        return Math.round(v / root.gridSize) * root.gridSize;
    }

    Timer {
        id: saveTimer
        interval: 250
        onTriggered: root.save()
    }

    function save() {
        saveTimer.stop();
        const payload = {
            version: 1,
            presets: root.presets,
            wallpaperMap: root.wallpaperMap
        };
        storeFile.setText(JSON.stringify(payload, null, 2));
    }

    FileView {
        id: storeFile
        path: root.storePath
        printErrors: false
        onLoaded: {
            try {
                const raw = JSON.parse(text());
                if (raw && typeof raw === "object") {
                    const p = raw.presets && typeof raw.presets === "object" ? raw.presets : {};
                    if (!p["default"] || !Array.isArray(p["default"].widgets)) {
                        p["default"] = { id: "default", name: "Default", widgets: root.factoryDefaultWidgets() };
                    }
                    root.presets = p;
                    root.wallpaperMap = (raw.wallpaperMap && typeof raw.wallpaperMap === "object") ? raw.wallpaperMap : ({});
                    root.editingPresetId = root.activePresetId;
                    root.revision++;
                }
            } catch (e) {}
            root.loaded = true;
        }
        onLoadFailed: {
            root.loaded = true;
            root.save();
        }
    }
}
