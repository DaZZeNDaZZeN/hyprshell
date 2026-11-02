pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Persistent user settings, stored in ~/.config/hyprshell/config.json.
// Everything the Settings Manager edits lives on `Config.o`.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string dir: home + "/.config/hyprshell"
    readonly property alias o: adapter
    property bool loaded: false

    function save() { file.writeAdapter(); }

    FileView {
        id: file
        path: root.dir + "/config.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoaded: root.loaded = true
        onLoadFailed: error => { writeAdapter(); root.loaded = true; }

        adapter: JsonAdapter {
            id: adapter

            // ---- appearance ----
            property string themeMode: "dark"          // dark | light
            property string staticTheme: "none"        // none | nord | gruvbox | mocha | rosepine | latte
            property string accentMode: "wallpaper"    // wallpaper | custom
            property string customAccent: "#7aa2f7"
            property string wallpaperAccent: "#7aa2f7"
            property int radius: 16
            property real panelOpacity: 0.92
            property real barOpacity: 0.92
            property real dockOpacity: 0.92
            property real widgetsOpacity: 0.92
            property real animSpeed: 1.0               // 1 = default, 0 = instant
            property string fontFamily: "Noto Sans"
            property real fontScale: 1.0
            property string iconTheme: ""              // empty -> breeze / breeze-dark
            property string cursorTheme: "capitaine-cursors"
            property int cursorSize: 24
            property bool syncToolkits: true

            // ---- bar ----
            property bool barEnabled: true
            property string barPosition: "top"         // top | bottom
            property bool barFloating: true
            property bool barAutoHide: false
            property bool barKeepOnEmpty: false
            property int barHeight: 38
            property bool barShowTitle: true
            property bool barShowTray: true
            property bool barShowMedia: true
            property bool barShowLayout: true
            property bool barClock24h: true
            property bool barSeconds: false
            property int barScrollStep: 5
            property string barMonitors: "all"         // all | primary

            // ---- dock ----
            property bool dockEnabled: true
            property bool dockFloating: true
            property bool dockAutoHide: true
            property bool dockKeepOnEmpty: true
            property int dockIconSize: 44
            property var dockPinned: ["firefox", "org.kde.dolphin", "kitty"]

            // ---- launcher ----
            property string webSearchUrl: "https://duckduckgo.com/?q="
            property var launcherUsage: ({})

            // ---- notifications ----
            property bool dnd: false
            property int notifTimeout: 6000
            property string notifPosition: "top-right"

            // ---- osd ----
            property bool osdEnabled: true
            property int osdTimeout: 1600

            // ---- desktop widgets ----
            property bool widgetsEnabled: true
            property string widgetsPosition: "top-left" // top-left | top-center | top-right | left-center | center | right-center | bottom-left | bottom-center | bottom-right
            property bool widgetClock: true
            property bool widgetWeather: true
            property bool widgetSystem: true
            property bool widgetMedia: true
            property bool widgetLinks: true
            property string weatherCity: ""            // empty -> auto location
            property bool weatherFahrenheit: false
            property var appLinks: ["firefox", "org.kde.dolphin", "kitty", "systemsettings"]

            // ---- wallpaper ----
            property string wallpaper: ""
            property string wallpaperDir: Quickshell.env("HOME") + "/Pictures/Wallpapers"
            property string wallpaperFill: "crop"      // crop | fit | stretch
            property bool slideshow: false
            property int slideshowMinutes: 30
            property string wallhavenApiKey: ""

            // ---- misc ----
            property string terminal: "kitty"
            property string browser: "firefox"
            property string fileManager: "dolphin"
            property bool lockOnSuspend: true
        }
    }

    Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", dir])
}
