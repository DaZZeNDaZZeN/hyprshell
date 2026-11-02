pragma Singleton

import Quickshell
import QtQuick
import qs.config

// Helpers around desktop entries and icons.
Singleton {
    function lookup(id) {
        if (!id) return null;
        return DesktopEntries.heuristicLookup(id) ?? DesktopEntries.byId(id);
    }
    function iconFor(name) {
        if (!name) return Quickshell.iconPath("application-x-executable", true);
        if (name.startsWith("/") || name.startsWith("file:") || name.startsWith("qrc:") || name.startsWith("image://")) return name;
        return Quickshell.iconPath(name, "application-x-executable");
    }
    function bump(id) {
        const u = Object.assign({}, Config.o.launcherUsage);
        u[id] = (u[id] ?? 0) + 1;
        Config.o.launcherUsage = u;
    }
    function run(cmd) { Quickshell.execDetached(["sh", "-c", cmd]); }
}
