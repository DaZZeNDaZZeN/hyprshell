pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs.config

// Wallpaper management: apply, list, slideshow, and accent extraction.
Singleton {
    id: root
    property var files: []
    readonly property string current: Config.o.wallpaper
    readonly property string exts: "\\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.bmp' \\)"

    function refresh() {
        lister.command = ["sh", "-c", "mkdir -p '" + Config.o.wallpaperDir + "' && find '" + Config.o.wallpaperDir
            + "' -maxdepth 2 -type f " + exts + " | sort"];
        lister.running = true;
    }
    function apply(path) {
        if (!path) return;
        Config.o.wallpaper = path;
        extract(path);
    }
    function extract(path) {
        extractor.command = ["python3", Quickshell.shellDir + "/scripts/accent.py", path];
        extractor.running = true;
    }
    function random() {
        if (!files.length) return;
        const others = files.filter(f => f !== current);
        apply((others.length ? others : files)[Math.floor(Math.random() * (others.length || files.length))]);
    }
    function next() {
        if (!files.length) return;
        const i = files.indexOf(current);
        apply(files[(i + 1) % files.length]);
    }

    Process {
        id: lister
        stdout: StdioCollector {
            onStreamFinished: {
                root.files = text.trim() ? text.trim().split("\n") : [];
                if (!Config.o.wallpaper) root.bootstrap();
            }
        }
    }
    Process {
        id: extractor
        stdout: StdioCollector { onStreamFinished: { const c = text.trim(); if (/^#[0-9a-f]{6}$/i.test(c)) Config.o.wallpaperAccent = c; } }
    }
    // Generates a neutral default wallpaper on first run so the shell never starts empty.
    Process { id: maker; onExited: root.refresh() }
    function bootstrap() {
        if (files.length) { apply(files[0]); return; }
        const p = Config.o.wallpaperDir + "/default.png";
        maker.command = ["sh", "-c", "magick -size 2560x1440 gradient:'#2b2f4a-#6a3a6e' -attenuate 0.3 +noise Gaussian -blur 0x3 -depth 8 png:'" + p + ".part' && mv '" + p + ".part' '" + p + "'"];
        maker.running = true;
    }

    Timer {
        interval: Math.max(1, Config.o.slideshowMinutes) * 60000
        running: Config.o.slideshow
        repeat: true
        onTriggered: root.random()
    }
    Component.onCompleted: refresh()
    Connections { target: Config; function onLoadedChanged() { root.refresh(); if (Config.o.wallpaper) root.extract(Config.o.wallpaper); } }
}
