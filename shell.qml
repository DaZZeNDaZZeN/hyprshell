//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1

import Quickshell
import Quickshell.Io
import QtQuick
import qs.config
import qs.services
import qs.modules

ShellRoot {
    // desktop layer
    WallpaperLayer {}
    DesktopWidgets {}
    Bar {}
    Dock {}

    // overlay panels
    Launcher {}
    WorkspaceSwitcher {}
    Session {}
    ControlCenter {}
    NotificationCenter {}
    ClipboardPanel {}
    WallhavenBrowser {}
    Settings {}
    ScreenshotOverlay {}

    // always-on
    NotificationPopups {}
    OsdPopup {}
    Lock {}
    PolkitAgent {}

    // `qs -c hyprshell ipc call shell <function> [args]` — used by Hyprland keybinds
    IpcHandler {
        target: "shell"
        function toggle(name: string): void { Panels.toggle(name); }
        function open(name: string): void { Panels.open(name); }
        function close(): void { Panels.close(); }
        function grab(name: string): string { return Panels.grab(name, "/tmp/hs-" + name + ".png"); }
        function lock(): void { Actions.lock(); }
        function screenshot(mode: string): void { Screenshot.start(mode); }
        function record(): void { Recorder.toggle(); }
        function volume(action: string): void {
            if (action === "up") Audio.step(0.05);
            else if (action === "down") Audio.step(-0.05);
            else Audio.toggleMute();
        }
        function mic(): void { Audio.toggleMic(); }
        function brightness(action: string): void { Brightness.step(action === "up" ? 0.05 : -0.05); }
        function media(action: string): void {
            if (action === "next") Media.next();
            else if (action === "prev") Media.previous();
            else Media.playPause();
        }
        function wallpaper(action: string): void { if (action === "next") Wallpaper.next(); else Wallpaper.random(); }
    }
}
