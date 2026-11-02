# Hyprshell

A clean, modern, cohesive desktop shell for Hyprland built with Quickshell (Qt6 / QML).

## Features
- **Design & Theming**: Neutral dark/light base or static themes (`nord`, `gruvbox`, `mocha`, `rosepine`, `latte`), automatic dominant accent color extraction from wallpapers (`scripts/accent.py`), custom accent override, and live synchronization across Hyprland borders, GTK 3/4 (`gtk.css`), Qt (`qt6ct`), and KDE (`kdeglobals`) via `scripts/apply-theme.py`.
- **Bar & Dock**: Multi-monitor customizable status bar and floating/pinned dock with auto-hide support (`modules/Bar.qml`, `modules/Dock.qml`).
- **Launcher, Workspace Switcher & Session**: App/window/calc/command/web launcher (`modules/Launcher.qml`), 10-workspace overview (`modules/WorkspaceSwitcher.qml`), and power/session panel (`modules/Session.qml`).
- **Control Center & OSD**: Quick toggles, Wi-Fi picker, Bluetooth manager, audio per-app/device mixer, brightness, power profiles, MPRIS media (`modules/ControlCenter.qml`), and animated OSD popups for volume, brightness, media, layout, and lock keys (`modules/OsdPopup.qml`).
- **Desktop Widgets & Wallhaven**: Clock, weather, CPU/RAM/disk monitor, media, app links (`modules/DesktopWidgets.qml`), animated wallpaper layer (`modules/WallpaperLayer.qml`), and built-in wallhaven.cc browser (`modules/WallhavenBrowser.qml`).
- **Utilities & Security**: Notification daemon & action center (`modules/NotificationPopups.qml`, `modules/NotificationCenter.qml`), clipboard history (`modules/ClipboardPanel.qml`), screenshot & screen recording (`modules/ScreenshotOverlay.qml`, `services/Recorder.qml`), Polkit authentication agent (`modules/PolkitAgent.qml`), and PAM lock screen (`modules/Lock.qml`).
- **Settings Manager**: Full GUI settings panel (`modules/Settings.qml`) backed by `~/.config/hyprshell/config.json`.
