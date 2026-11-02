import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.config
import qs.services

// Wallpaper on every screen with a smooth cross-fade between images.
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win
        required property var modelData
        screen: modelData
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "hyprshell-wallpaper"
        color: Theme.bg

        property bool showA: true
        property Image pending: null
        readonly property string src: Wallpaper.current ? "file://" + Wallpaper.current : ""
        readonly property int fill: Config.o.wallpaperFill === "fit" ? Image.PreserveAspectFit
            : Config.o.wallpaperFill === "stretch" ? Image.Stretch : Image.PreserveAspectCrop

        onSrcChanged: {
            const nxt = showA ? b : a;
            if (nxt.source.toString() === src) { showA = nxt === a; return; }
            pending = nxt;
            nxt.source = src;
        }
        function ready(img) {
            if (img.status === Image.Ready && pending === img) { pending = null; showA = img === a; }
        }

        component Pic: Image {
            anchors.fill: parent
            asynchronous: true
            cache: false
            fillMode: win.fill
            sourceSize: Qt.size(win.width, win.height)
            onStatusChanged: win.ready(this)
        }
        Pic { id: a; source: win.src; opacity: win.showA ? 1 : 0; Behavior on opacity { NumberAnimation { duration: Theme.animSlow * 2; easing.type: Easing.InOutCubic } } }
        Pic { id: b; opacity: win.showA ? 0 : 1; Behavior on opacity { NumberAnimation { duration: Theme.animSlow * 2; easing.type: Easing.InOutCubic } } }
    }
}
