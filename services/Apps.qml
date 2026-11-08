pragma Singleton

import Quickshell
import QtQuick
import qs.config

// Helpers around desktop entries and icons, with lookup caching.
Singleton {
    id: root
    property var _entryCache: ({})
    property var _iconCache: ({})
    readonly property string _fallbackIcon: Quickshell.iconPath("application-x-executable", true)

    Connections {
        target: DesktopEntries.applications
        function onValuesChanged() { root._entryCache = ({}); }
    }
    Connections {
        target: Config.o
        function onIconThemeChanged() { root._iconCache = ({}); }
    }

    function lookup(id) {
        if (!id) return null;
        if (id in _entryCache) return _entryCache[id];
        const res = DesktopEntries.heuristicLookup(id) ?? DesktopEntries.byId(id) ?? null;
        _entryCache[id] = res;
        return res;
    }
    function iconFor(name) {
        if (!name) return _fallbackIcon;
        if (name.startsWith("/") || name.startsWith("file:") || name.startsWith("qrc:") || name.startsWith("image://")) return name;
        if (name in _iconCache) return _iconCache[name];
        const res = Quickshell.iconPath(name, "application-x-executable");
        _iconCache[name] = res;
        return res;
    }
    function bump(id) {
        const u = Object.assign({}, Config.o.launcherUsage);
        u[id] = (u[id] ?? 0) + 1;
        Config.o.launcherUsage = u;
    }
    function run(cmd) { Quickshell.execDetached(["sh", "-c", cmd]); }
}
