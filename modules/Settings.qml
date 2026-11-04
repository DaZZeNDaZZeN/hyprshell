import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

// Settings Manager: every shell feature is configurable here, no file editing needed.
Variants {
    model: Quickshell.screens

    PanelOverlay {
        id: win
        required property var modelData
        screen: modelData
        name: "settings"
        scrimOpacity: 0.45
        property string page: "appearance"
        readonly property var pages: [
            { id: "appearance", label: "Appearance", glyph: "\uf1fc" },
            { id: "wallpaper", label: "Wallpaper", glyph: "\uf03e" },
            { id: "bar", label: "Bar", glyph: "\uf0c9" },
            { id: "dock", label: "Dock", glyph: "\uf108" },
            { id: "widgets", label: "Desktop widgets", glyph: "\uf009" },
            { id: "notifs", label: "Notifications & OSD", glyph: "\uf0f3" },
            { id: "keys", label: "Keybindings", glyph: "\uf11c" },
            { id: "system", label: "System", glyph: "\uf013" },
        ]
        onOpenChanged: if (open) { page = Panels.page || page; Wallpaper.refresh(); }

        readonly property var o: Config.o

        component Section: Label { Layout.topMargin: 14; text: ""; color: Theme.accent; font.pixelSize: Theme.fsS + 1; font.weight: Font.DemiBold; font.capitalization: Font.AllUppercase; font.letterSpacing: 1 }
        component Page: Flickable {
            id: pg
            property string key
            default property alias items: col.data
            anchors.fill: parent
            contentHeight: col.implicitHeight + 40
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            opacity: win.page === key ? 1 : 0
            visible: opacity > 0.01
            transform: Translate { y: win.page === pg.key ? 0 : 16; Behavior on y { NumberAnimation { duration: Theme.animSlow; easing.type: Easing.OutQuint } } }
            Behavior on opacity { NumberAnimation { duration: Theme.anim } }
            ColumnLayout { id: col; x: 28; y: 20; width: pg.width - 56; spacing: 0 }
        }
        component Sw: Toggle { }
        component Sl: Slider { implicitWidth: 200 }

        PopupCard {
            id: card
            shown: win.open
            width: Math.min(parent.width - 80, 1000); height: Math.min(parent.height - 80, 700)
            anchors.centerIn: parent
            slideY: 20
            clip: true

            Rectangle {
                id: side
                x: 1; y: 1
                width: 232; height: parent.height - 2
                radius: Math.max(0, card.radius - 1)
                color: Theme.surface
                Rectangle {
                    anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
                    width: parent.radius
                    color: parent.color
                }
                Label { x: 22; y: 22; text: "Settings"; font.pixelSize: Theme.fsXL - 4; font.weight: Font.Bold }
                Column {
                    x: 12; y: 76; width: parent.width - 24; spacing: 4
                    Repeater {
                        model: win.pages
                        delegate: Rectangle {
                            required property var modelData
                            readonly property bool cur: win.page === modelData.id
                            width: parent.width; height: 40; radius: Theme.radiusS + 2
                            color: cur ? Theme.accent : (sm.containsMouse ? Theme.hover : "transparent")
                            Behavior on color { ColorAnimation { duration: Theme.animFast } }
                            Row { x: 14; anchors.verticalCenter: parent.verticalCenter; spacing: 12
                                Icon { width: 18; text: modelData.glyph; font.pixelSize: 14; tint: cur ? Theme.onAccent : Theme.subtext }
                                Label { text: modelData.label; color: cur ? Theme.onAccent : Theme.text; font.weight: cur ? Font.DemiBold : Font.Normal } }
                            MouseArea { id: sm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.page = modelData.id }
                        }
                    }
                }
                IconButton { anchors { left: parent.left; bottom: parent.bottom; margins: 14 } glyph: "\uf00d"; size: 34; onClicked: Panels.close() }
            }
            Item {
                anchors { left: side.right; right: parent.right; top: parent.top; bottom: parent.bottom }

                // ================= Appearance =================
                Page {
                    key: "appearance"
                    Section { text: "Theme" }
                    SettingRow { title: "Mode"; desc: "Toggle between your selected dark and light themes."
                        Segmented { options: [{ label: "Dark", value: "dark" }, { label: "Light", value: "light" }]; current: win.o.themeMode
                            onPicked: v => win.o.themeMode = v } }
                    SettingRow { title: "Dark theme"; desc: "Palette used when dark mode is active."
                        Flow { width: 410; spacing: 6
                            Repeater { model: Theme.darkThemes
                                delegate: Chip { required property var modelData; text: modelData === "none" ? "Neutral" : modelData; active: win.o.darkTheme === modelData
                                    onClicked: { win.o.darkTheme = modelData; win.o.themeMode = "dark"; } } } } }
                    SettingRow { title: "Light theme"; desc: "Palette used when light mode is active."
                        Flow { width: 410; spacing: 6
                            Repeater { model: Theme.lightThemes
                                delegate: Chip { required property var modelData; text: modelData === "none" ? "Neutral" : modelData; active: win.o.lightTheme === modelData
                                    onClicked: { win.o.lightTheme = modelData; win.o.themeMode = "light"; } } } } }
                    Section { text: "Accent color" }
                    SettingRow { title: "Source"; desc: "Extract one dominant color from the wallpaper, or choose your own."
                        Segmented { options: [{ label: "From wallpaper", value: "wallpaper" }, { label: "Custom", value: "custom" }]; current: win.o.accentMode; onPicked: v => win.o.accentMode = v } }
                    SettingRow { title: "Current accent"; desc: Theme.hex(Theme.accent)
                        Rectangle { width: 40; height: 28; radius: 8; color: Theme.accent; border.width: 1; border.color: Theme.border }
                        Button { text: "Re-extract"; glyph: "\uf021"; onClicked: Wallpaper.extract(Config.o.wallpaper) } }
                    SettingRow { title: "Custom accent"; desc: "Used when the source is Custom. Hex like #7aa2f7."
                        Row { spacing: 6
                            Repeater { model: ["#7aa2f7", "#f7768e", "#9ece6a", "#e0af68", "#bb9af7", "#7dcfff", "#ff9e64", "#ebbcba"]
                                delegate: Rectangle { required property var modelData; width: 24; height: 24; radius: 12; color: modelData
                                    border.width: win.o.customAccent === modelData ? 2 : 0; border.color: Theme.text
                                    scale: sw.containsMouse ? 1.15 : 1; Behavior on scale { NumberAnimation { duration: Theme.animFast } }
                                    MouseArea { id: sw; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { win.o.customAccent = modelData; win.o.accentMode = "custom"; } } } }
                            TextField { width: 100; height: 30; text: win.o.customAccent; onAccepted: { if (/^#[0-9a-fA-F]{6}$/.test(text)) { win.o.customAccent = text; win.o.accentMode = "custom"; } } } } }
                    Section { text: "Style" }
                    SettingRow { title: "Corner radius"; desc: win.o.radius + " px"; Sl { value: win.o.radius; max: 28; onMoved: v => win.o.radius = Math.round(v) } }
                    SettingRow { title: "Panel opacity"; desc: Math.round(win.o.panelOpacity * 100) + "% (popups & overlays)"; Sl { value: win.o.panelOpacity - 0.1; max: 0.9; onMoved: v => win.o.panelOpacity = Math.round((v + 0.1) * 100) / 100 } }
                    SettingRow { title: "Top bar opacity"; desc: Math.round(win.o.barOpacity * 100) + "%"; Sl { value: win.o.barOpacity - 0.1; max: 0.9; onMoved: v => win.o.barOpacity = Math.round((v + 0.1) * 100) / 100 } }
                    SettingRow { title: "Dock opacity"; desc: Math.round(win.o.dockOpacity * 100) + "%"; Sl { value: win.o.dockOpacity - 0.1; max: 0.9; onMoved: v => win.o.dockOpacity = Math.round((v + 0.1) * 100) / 100 } }
                    SettingRow { title: "Desktop widgets opacity"; desc: Math.round(win.o.widgetsOpacity * 100) + "%"; Sl { value: win.o.widgetsOpacity - 0.1; max: 0.9; onMoved: v => win.o.widgetsOpacity = Math.round((v + 0.1) * 100) / 100 } }
                    SettingRow { title: "Animation speed"; desc: win.o.animSpeed <= 0.01 ? "Off" : win.o.animSpeed.toFixed(1) + "×"; Sl { value: win.o.animSpeed; max: 2; onMoved: v => win.o.animSpeed = Math.round(v * 10) / 10 } }
                    SettingRow { title: "Font family"; TextField { width: 200; text: win.o.fontFamily; onAccepted: win.o.fontFamily = text } }
                    SettingRow { title: "Font size"; desc: Math.round(win.o.fontScale * 100) + "%"; Sl { value: win.o.fontScale - 0.8; max: 0.6; onMoved: v => win.o.fontScale = Math.round((v + 0.8) * 20) / 20 } }
                    Section { text: "Qt & GTK integration" }
                    SettingRow { title: "Sync toolkits"; desc: "Apply colors, accent, dark/light, icons and cursor to GTK 3/4, Qt (qt6ct) and KDE apps."
                        Sw { checked: win.o.syncToolkits; onToggled: v => win.o.syncToolkits = v } }
                    SettingRow { title: "Icon theme"; desc: "Empty = breeze (light) / breeze-dark (dark)"; TextField { width: 200; text: win.o.iconTheme; onAccepted: win.o.iconTheme = text } }
                    SettingRow { title: "Cursor theme"; TextField { width: 200; text: win.o.cursorTheme; onAccepted: win.o.cursorTheme = text } }
                    SettingRow { title: "Cursor size"; desc: win.o.cursorSize + " px"; Sl { value: win.o.cursorSize - 16; max: 48; onMoved: v => win.o.cursorSize = Math.round((v + 16) / 4) * 4 } }
                    Section { text: "Custom styling" }
                    SettingRow { title: "Theme overrides"; desc: "JSON file that overrides any design token (accent, bg, surface, text, radius, font…). Hot-reloaded."
                        Button { text: "Open"; glyph: "\uf044"; onClicked: Quickshell.execDetached(["sh", "-c", "f=\"$HOME/.config/hyprshell/theme-overrides.json\"; [ -f \"$f\" ] || echo '{}' > \"$f\"; xdg-open \"$f\""]) } }
                    SettingRow { title: "Custom GTK CSS"; desc: "Appended to GTK 3/4 gtk.css whenever the theme is applied."
                        Button { text: "Edit"; glyph: "\uf044"; onClicked: Quickshell.execDetached(["sh", "-c", "f=\"$HOME/.config/hyprshell/custom-gtk.css\"; [ -f \"$f\" ] || echo '/* your CSS */' > \"$f\"; xdg-open \"$f\""]) } }
                }

                // ================= Wallpaper =================
                Page {
                    key: "wallpaper"
                    Section { text: "Current" }
                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: 180; radius: Theme.radius; color: Theme.surface2; clip: true
                        Image { anchors.fill: parent; source: Wallpaper.current ? "file://" + Wallpaper.current : ""; fillMode: Image.PreserveAspectCrop; sourceSize: Qt.size(900, 360); asynchronous: true }
                        Rectangle { anchors { left: parent.left; bottom: parent.bottom; margins: 10 } height: 28; width: ct.implicitWidth + 20; radius: 14; color: "#aa000000"
                            Label { id: ct; anchors.centerIn: parent; color: "white"; text: Wallpaper.current.split("/").pop(); font.pixelSize: Theme.fsS } }
                    }
                    Row { Layout.topMargin: 12; spacing: 8
                        Button { text: "Browse Wallhaven"; glyph: "\uf002"; primary: true; onClicked: Panels.open("wallhaven") }
                        Button { text: "Random"; glyph: "\uf074"; onClicked: Wallpaper.random() }
                        Button { text: "Next"; glyph: "\uf051"; onClicked: Wallpaper.next() }
                        Button { text: "Refresh"; glyph: "\uf021"; onClicked: Wallpaper.refresh() } }
                    Section { text: "Behaviour" }
                    SettingRow { title: "Fill mode"; Segmented { options: [{ label: "Crop", value: "crop" }, { label: "Fit", value: "fit" }, { label: "Stretch", value: "stretch" }]; current: win.o.wallpaperFill; onPicked: v => win.o.wallpaperFill = v } }
                    SettingRow { title: "Slideshow"; desc: "Rotate through wallpapers in the folder."
                        Sw { checked: win.o.slideshow; onToggled: v => win.o.slideshow = v } }
                    SettingRow { title: "Slideshow interval"; desc: win.o.slideshowMinutes + " min"; Sl { value: win.o.slideshowMinutes; max: 120; onMoved: v => win.o.slideshowMinutes = Math.max(1, Math.round(v)) } }
                    SettingRow { title: "Wallpaper folder"; TextField { width: 260; text: win.o.wallpaperDir; onAccepted: { win.o.wallpaperDir = text; Wallpaper.refresh(); } } }
                    SettingRow { title: "Wallhaven API key"; desc: "Optional. Needed for NSFW content and your account's settings."
                        TextField { width: 260; echoMode: TextInput.Password; text: win.o.wallhavenApiKey; onAccepted: win.o.wallhavenApiKey = text } }
                    Section { text: "Library (" + Wallpaper.files.length + ")" }
                    Flow {
                        Layout.fillWidth: true; spacing: 10
                        Repeater {
                            model: Wallpaper.files
                            delegate: Rectangle {
                                required property var modelData
                                readonly property bool cur: modelData === Wallpaper.current
                                width: 150; height: 92; radius: Theme.radiusS + 2; color: Theme.surface2; clip: true
                                border.width: cur ? 3 : 0; border.color: Theme.accent
                                scale: wm.containsMouse ? 1.04 : 1; Behavior on scale { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }
                                Image { anchors.fill: parent; source: "file://" + modelData; fillMode: Image.PreserveAspectCrop; sourceSize: Qt.size(300, 184); asynchronous: true }
                                MouseArea { id: wm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Wallpaper.apply(modelData) }
                            }
                        }
                    }
                }

                // ================= Bar =================
                Page {
                    key: "bar"
                    Section { text: "Status bar" }
                    SettingRow { title: "Enable bar"; Sw { checked: win.o.barEnabled; onToggled: v => win.o.barEnabled = v } }
                    SettingRow { title: "Position"; Segmented { options: ["top", "bottom"]; current: win.o.barPosition; onPicked: v => win.o.barPosition = v } }
                    SettingRow { title: "Floating"; desc: "Detached rounded bar with margins."; Sw { checked: win.o.barFloating; onToggled: v => win.o.barFloating = v } }
                    SettingRow { title: "Auto-hide"; desc: "Slide away until the pointer touches the screen edge."; Sw { checked: win.o.barAutoHide; onToggled: v => win.o.barAutoHide = v } }
                    SettingRow { title: "Keep visible on empty workspace"; desc: "Do not auto-hide when there are no windows on the current workspace."; Sw { checked: win.o.barKeepOnEmpty; onToggled: v => win.o.barKeepOnEmpty = v } }
                    SettingRow { title: "Opacity"; desc: Math.round(win.o.barOpacity * 100) + "%"; Sl { value: win.o.barOpacity - 0.1; max: 0.9; onMoved: v => win.o.barOpacity = Math.round((v + 0.1) * 100) / 100 } }
                    SettingRow { title: "Height"; desc: win.o.barHeight + " px"; Sl { value: win.o.barHeight - 28; max: 24; onMoved: v => win.o.barHeight = Math.round(v) + 28 } }
                    SettingRow { title: "Scroll to change volume"; desc: "Scroll on empty bar space to adjust volume."; Sw { checked: win.o.barScrollVolume; onToggled: v => win.o.barScrollVolume = v } }
                    SettingRow { title: "Scroll volume step"; visible: win.o.barScrollVolume; desc: win.o.barScrollStep + "% when scrolling on empty bar space"; Sl { value: win.o.barScrollStep - 1; max: 19; onMoved: v => win.o.barScrollStep = Math.max(1, Math.round(v + 1)) } }
                    SettingRow { title: "Right-click opens Control Center"; desc: "Open Control Center at cursor when right-clicking empty bar space."; Sw { checked: win.o.barRightClickCc; onToggled: v => win.o.barRightClickCc = v } }
                    SettingRow { title: "Monitors"; desc: "Show a bar on every monitor or only the first."; Segmented { options: [{ label: "All", value: "all" }, { label: "Primary", value: "primary" }]; current: win.o.barMonitors; onPicked: v => win.o.barMonitors = v } }
                    Section { text: "Modules" }
                    SettingRow { title: "Window title"; Sw { checked: win.o.barShowTitle; onToggled: v => win.o.barShowTitle = v } }
                    SettingRow { title: "Media"; Sw { checked: win.o.barShowMedia; onToggled: v => win.o.barShowMedia = v } }
                    SettingRow { title: "System tray"; Sw { checked: win.o.barShowTray; onToggled: v => win.o.barShowTray = v } }
                    SettingRow { title: "Keyboard layout"; Sw { checked: win.o.barShowLayout; onToggled: v => win.o.barShowLayout = v } }
                    SettingRow { title: "24-hour clock"; Sw { checked: win.o.barClock24h; onToggled: v => win.o.barClock24h = v } }
                    SettingRow { title: "Show seconds"; Sw { checked: win.o.barSeconds; onToggled: v => win.o.barSeconds = v } }
                }

                // ================= Dock =================
                Page {
                    key: "dock"
                    Section { text: "Dock" }
                    SettingRow { title: "Enable dock"; Sw { checked: win.o.dockEnabled; onToggled: v => win.o.dockEnabled = v } }
                    SettingRow { title: "Floating"; desc: "Off = attached to the screen edge across the full width."; Sw { checked: win.o.dockFloating; onToggled: v => win.o.dockFloating = v } }
                    SettingRow { title: "Auto-hide"; Sw { checked: win.o.dockAutoHide; onToggled: v => win.o.dockAutoHide = v } }
                    SettingRow { title: "Keep visible on empty workspace"; desc: "Do not auto-hide when there are no windows on the current workspace."; Sw { checked: win.o.dockKeepOnEmpty; onToggled: v => win.o.dockKeepOnEmpty = v } }
                    SettingRow { title: "Opacity"; desc: Math.round(win.o.dockOpacity * 100) + "%"; Sl { value: win.o.dockOpacity - 0.1; max: 0.9; onMoved: v => win.o.dockOpacity = Math.round((v + 0.1) * 100) / 100 } }
                    SettingRow { title: "Icon size"; desc: win.o.dockIconSize + " px"; Sl { value: win.o.dockIconSize - 28; max: 44; onMoved: v => win.o.dockIconSize = Math.round(v) + 28 } }
                    Section { text: "Pinned apps" }
                    Repeater {
                        model: win.o.dockPinned
                        delegate: SettingRow {
                            required property var modelData
                            readonly property var entry: Apps.lookup(modelData)
                            title: entry ? entry.name : modelData; desc: modelData
                            Button { text: "Remove"; danger: true; onClicked: win.o.dockPinned = win.o.dockPinned.filter(p => p !== modelData) }
                        }
                    }
                    SettingRow { title: "Pin an app"; desc: "Desktop file id, e.g. org.kde.konsole"
                        TextField { id: pinId; width: 220; placeholder: "app id"; onAccepted: { if (text) { win.o.dockPinned = win.o.dockPinned.concat([text]); text = ""; } } }
                        Button { text: "Add"; primary: true; onClicked: { if (pinId.text) { win.o.dockPinned = win.o.dockPinned.concat([pinId.text]); pinId.text = ""; } } } }
                    Label { Layout.topMargin: 8; text: "Tip: right-click any dock icon to pin or unpin it."; color: Theme.subtext; font.pixelSize: Theme.fsS + 1 }
                }

                // ================= Widgets =================
                Page {
                    key: "widgets"
                    Section { text: "Desktop widgets" }
                    SettingRow { title: "Enable widgets"; Sw { checked: win.o.widgetsEnabled; onToggled: v => win.o.widgetsEnabled = v } }
                    SettingRow { title: "Opacity"; desc: Math.round(win.o.widgetsOpacity * 100) + "%"; Sl { value: win.o.widgetsOpacity - 0.1; max: 0.9; onMoved: v => win.o.widgetsOpacity = Math.round((v + 0.1) * 100) / 100 } }
                    SettingRow { title: "Position"; Grid { columns: 3; spacing: 6
                        Repeater { model: ["top-left", "top-center", "top-right", "left-center", "center", "right-center", "bottom-left", "bottom-center", "bottom-right"]
                            delegate: Chip { required property var modelData; text: modelData; active: win.o.widgetsPosition === modelData; onClicked: win.o.widgetsPosition = modelData } } } }
                    SettingRow { title: "Clock"; Sw { checked: win.o.widgetClock; onToggled: v => win.o.widgetClock = v } }
                    SettingRow { title: "Weather"; Sw { checked: win.o.widgetWeather; onToggled: v => win.o.widgetWeather = v } }
                    SettingRow { title: "System monitor"; Sw { checked: win.o.widgetSystem; onToggled: v => win.o.widgetSystem = v } }
                    SettingRow { title: "Active media"; Sw { checked: win.o.widgetMedia; onToggled: v => win.o.widgetMedia = v } }
                    SettingRow { title: "App links"; Sw { checked: win.o.widgetLinks; onToggled: v => win.o.widgetLinks = v } }
                    Section { text: "Weather" }
                    SettingRow { title: "City"; desc: "Leave empty to detect automatically."; TextField { width: 220; text: win.o.weatherCity; onAccepted: win.o.weatherCity = text } }
                    SettingRow { title: "Fahrenheit"; Sw { checked: win.o.weatherFahrenheit; onToggled: v => win.o.weatherFahrenheit = v } }
                    Section { text: "App links" }
                    Repeater {
                        model: win.o.appLinks
                        delegate: SettingRow {
                            required property var modelData
                            title: Apps.lookup(modelData)?.name ?? modelData; desc: modelData
                            Button { text: "Remove"; danger: true; onClicked: win.o.appLinks = win.o.appLinks.filter(p => p !== modelData) }
                        }
                    }
                    SettingRow { title: "Add link"; desc: "Desktop file id or a shell command"
                        TextField { id: linkId; width: 220; placeholder: "app id"; onAccepted: { if (text) { win.o.appLinks = win.o.appLinks.concat([text]); text = ""; } } }
                        Button { text: "Add"; primary: true; onClicked: { if (linkId.text) { win.o.appLinks = win.o.appLinks.concat([linkId.text]); linkId.text = ""; } } } }
                }

                // ================= Notifications & OSD =================
                Page {
                    key: "notifs"
                    Section { text: "Notifications" }
                    SettingRow { title: "Do not disturb"; desc: "Collect notifications silently in the history."; Sw { checked: win.o.dnd; onToggled: v => win.o.dnd = v } }
                    SettingRow { title: "Popup duration"; desc: (win.o.notifTimeout / 1000).toFixed(0) + " s"; Sl { value: win.o.notifTimeout - 1000; max: 14000; onMoved: v => win.o.notifTimeout = Math.round((v + 1000) / 500) * 500 } }
                    SettingRow { title: "Position"; Row { spacing: 6
                        Repeater { model: ["top-right", "top-left", "bottom-right", "bottom-left"]
                            delegate: Chip { required property var modelData; text: modelData; active: win.o.notifPosition === modelData; onClicked: win.o.notifPosition = modelData } } } }
                    Section { text: "On-screen display" }
                    SettingRow { title: "Enable OSD"; desc: "Volume, brightness, media, layout and lock keys."; Sw { checked: win.o.osdEnabled; onToggled: v => win.o.osdEnabled = v } }
                    SettingRow { title: "OSD duration"; desc: win.o.osdTimeout + " ms"; Sl { value: win.o.osdTimeout - 600; max: 3400; onMoved: v => win.o.osdTimeout = Math.round((v + 600) / 100) * 100 } }
                }

                // ================= Keybindings =================
                Page {
                    key: "keys"
                    Section { text: "Session & windows" }
                    Repeater {
                        model: [
                            ["Super + M", "Exit Hyprland"], ["Super + C", "Close window"], ["Super + B", "Float / tile"], ["Super + F", "Fullscreen"],
                            ["Super + G", "Maximize"], ["Super + ← ↑ → ↓", "Move focus"], ["Super + T / Ctrl+Alt+T", "Terminal"], ["Super + W", "Browser"],
                            ["Alt + Tab / Shift", "Next / previous workspace"], ["Alt + Ctrl + Tab / Shift", "Move window to next / previous"],
                            ["Super + 1…0", "Go to workspace 1–10"], ["Super + Shift + 1…0", "Move window to workspace"],
                            ["Super + N", "Notifications"], ["Super + H", "Control center"], ["Super + Z", "Session panel"], ["Super + R", "Launcher"],
                            ["Alt + ` / Super + Tab", "Workspace switcher"], ["Super + Shift + S", "Screenshot"], ["Super + V", "Clipboard history"],
                            ["Super + I", "Settings"], ["Super + L", "Lock screen"], ["Super + Shift + W", "Wallpaper browser"], ["Super + Shift + R", "Toggle screen recording"],
                            ["Mouse4", "Toggle microphone mute"],
                        ]
                        delegate: SettingRow { required property var modelData; title: modelData[1]
                            Rectangle { height: 28; width: kl.implicitWidth + 20; radius: 8; color: Theme.surface3
                                Label { id: kl; anchors.centerIn: parent; text: modelData[0]; font.family: "monospace"; font.pixelSize: Theme.fsS + 1 } } }
                    }
                }

                // ================= System =================
                Page {
                    key: "system"
                    Section { text: "Default apps" }
                    SettingRow { title: "Terminal"; TextField { width: 200; text: win.o.terminal; onAccepted: win.o.terminal = text } }
                    SettingRow { title: "Browser"; TextField { width: 200; text: win.o.browser; onAccepted: win.o.browser = text } }
                    SettingRow { title: "File manager"; TextField { width: 200; text: win.o.fileManager; onAccepted: win.o.fileManager = text } }
                    SettingRow { title: "Web search URL"; desc: "Used by the launcher."; TextField { width: 260; text: win.o.webSearchUrl; onAccepted: win.o.webSearchUrl = text } }
                    Section { text: "Utilities" }
                    SettingRow { title: "Screen recorder"; desc: Recorder.tool ? "Using " + Recorder.tool : "None found. Install wf-recorder (sudo pacman -S wf-recorder)." }
                    SettingRow { title: "Backlight"; desc: Brightness.available ? Brightness.device : "No controllable backlight detected." }
                    Section { text: "Shell" }
                    SettingRow { title: "Reload shell"; desc: "Restarts the shell process."
                        Button { text: "Reload"; glyph: "\uf021"; onClicked: Quickshell.reload(true) } }
                    SettingRow { title: "Config file"; desc: Config.dir + "/config.json" }
                }
            }
        }
    }
}
