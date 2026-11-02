pragma Singleton

import Quickshell
import QtQuick
import qs.config
import qs.services

// Session actions shared by the launcher, session panel and lock screen.
Singleton {
    function lock() { Panels.close(); Panels.locked = true; }
    function logout() { Quickshell.execDetached(["sh", "-c", "command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"]); }
    function suspend() { Quickshell.execDetached(["systemctl", "suspend"]); }
    function reboot() { Quickshell.execDetached(["systemctl", "reboot"]); }
    function poweroff() { Quickshell.execDetached(["systemctl", "poweroff"]); }
    function hibernate() { Quickshell.execDetached(["systemctl", "hibernate"]); }
}
