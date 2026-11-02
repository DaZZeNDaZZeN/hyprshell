pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs.config

// Text clipboard history. Watches the Wayland clipboard with wl-paste.
Singleton {
    id: root
    property var entries: []        // [{text, pinned, time}]
    readonly property string store: Config.dir + "/clipboard.json"

    FileView {
        id: file
        path: root.store
        printErrors: false
        onLoaded: { try { root.entries = JSON.parse(text()); } catch (e) {} }
    }
    function persist() { file.setText(JSON.stringify(root.entries)); }

    Process {
        running: true
        command: ["wl-paste", "--type", "text", "--watch", "jq", "-Rsc", "."]
        stdout: SplitParser {
            onRead: line => {
                let t = "";
                try { t = JSON.parse(line); } catch (e) { return; }
                if (!t || !t.trim() || t.length > 50000) return;
                root.add(t);
            }
        }
    }
    function add(t) {
        const old = root.entries.find(e => e.text === t);
        let list = root.entries.filter(e => e.text !== t);
        list.unshift({ text: t, pinned: old ? old.pinned : false, time: Date.now() });
        const pinned = list.filter(e => e.pinned), rest = list.filter(e => !e.pinned).slice(0, 100);
        root.entries = pinned.concat(rest).sort((a, b) => (b.pinned - a.pinned) || (b.time - a.time));
        persist();
    }
    function copy(t) { Quickshell.execDetached(["wl-copy", "--", t]); }
    function remove(e) { root.entries = root.entries.filter(x => x !== e); persist(); }
    function togglePin(e) {
        e.pinned = !e.pinned;
        root.entries = root.entries.slice().sort((a, b) => (b.pinned - a.pinned) || (b.time - a.time));
        persist();
    }
    function clear() { root.entries = root.entries.filter(e => e.pinned); persist(); }
}
