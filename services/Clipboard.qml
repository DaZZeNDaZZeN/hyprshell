pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs.config

// Text and image clipboard history. Watches the Wayland clipboard with wl-paste + clip-watch.sh.
Singleton {
    id: root
    property var entries: []        // [{type: "text"|"image", text, image, pinned, time}]
    property bool loaded: false
    readonly property string store: Config.dir + "/clipboard.json"
    readonly property string watchScript: Qt.resolvedUrl("../scripts/clip-watch.sh").toString().replace("file://", "")

    function decodeEscapedUnicode(s) {
        if (!s || !/\\u[0-9a-fA-F]{4}/.test(s)) return s;
        try {
            return s.replace(/\\u([0-9a-fA-F]{4})/g, (_, hex) => String.fromCharCode(parseInt(hex, 16)));
        } catch (e) {
            return s;
        }
    }

    FileView {
        id: file
        path: root.store
        printErrors: false
        onLoaded: {
            try {
                const raw = JSON.parse(text());
                root.entries = raw.filter(e => {
                    if (!e) return false;
                    if (e.type === "image") return !!e.image;
                    if (!e.text || !e.text.trim()) return false;
                    if (e.text.startsWith("\u0089PNG") || e.text.includes("\ufffd")) return false;
                    if (/^<meta http-equiv="content-type".*<img /.test(e.text)) return false;
                    return true;
                }).map(e => ({
                    type: e.type || (e.image ? "image" : "text"),
                    text: root.decodeEscapedUnicode(e.text || ""),
                    image: e.image || "",
                    pinned: !!e.pinned,
                    time: e.time || Date.now()
                }));
            } catch (e) {}
            root.loaded = true;
        }
        onLoadFailed: {
            root.loaded = true;
        }
    }
    function persist() { if (root.loaded) file.setText(JSON.stringify(root.entries)); }

    Process {
        id: textWatcher
        running: root.loaded
        command: ["wl-paste", "--type", "text", "--watch", "bash", root.watchScript, "text"]
        stdout: SplitParser {
            onRead: line => {
                let item = null;
                try { item = JSON.parse(line); } catch (e) { return; }
                if (item && item.text && item.text.trim()) root.add(root.decodeEscapedUnicode(item.text));
            }
        }
    }

    Process {
        id: imageWatcher
        running: root.loaded
        command: ["wl-paste", "--type", "image/png", "--watch", "bash", root.watchScript, "image"]
        stdout: SplitParser {
            onRead: line => {
                let item = null;
                try { item = JSON.parse(line); } catch (e) { return; }
                if (item && item.type === "image" && item.image) {
                    root.addImage(item.image, item.text || "Copied image");
                }
            }
        }
    }

    function add(t) {
        const old = root.entries.find(e => e.type !== "image" && e.text === t);
        let list = root.entries.filter(e => !(e.type !== "image" && e.text === t));
        list.unshift({ type: "text", text: t, image: "", pinned: old ? old.pinned : false, time: Date.now() });
        const pinned = list.filter(e => e.pinned), rest = list.filter(e => !e.pinned).slice(0, 100);
        root.entries = pinned.concat(rest).sort((a, b) => (b.pinned - a.pinned) || (b.time - a.time));
        persist();
    }

    function addImage(imgPath, label) {
        if (!imgPath) return;
        const old = root.entries.find(e => e.type === "image" && e.image === imgPath);
        let list = root.entries.filter(e => !(e.type === "image" && e.image === imgPath));
        list.unshift({
            type: "image",
            text: label || ("Screenshot · " + imgPath.split("/").pop()),
            image: imgPath,
            pinned: old ? old.pinned : false,
            time: Date.now()
        });
        const pinned = list.filter(e => e.pinned), rest = list.filter(e => !e.pinned).slice(0, 100);
        root.entries = pinned.concat(rest).sort((a, b) => (b.pinned - a.pinned) || (b.time - a.time));
        persist();
    }

    function copy(t) {
        if (typeof t === "object" && t !== null) {
            if (t.type === "image" && t.image) {
                Quickshell.execDetached(["sh", "-c", "wl-copy --type image/png < '" + t.image.replace(/'/g, "'\\''") + "'"]);
                return;
            }
            Quickshell.execDetached(["wl-copy", "--", t.text || ""]);
            return;
        }
        Quickshell.execDetached(["wl-copy", "--", String(t)]);
    }
    function remove(e) { root.entries = root.entries.filter(x => x !== e); persist(); }
    function togglePin(e) {
        e.pinned = !e.pinned;
        root.entries = root.entries.slice().sort((a, b) => (b.pinned - a.pinned) || (b.time - a.time));
        persist();
    }
    function clear() { root.entries = root.entries.filter(e => e.pinned); persist(); }
}
