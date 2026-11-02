# Hyprshell

A full-featured, modular desktop shell for **Hyprland** built with **Quickshell** (Qt6 / QML), paired with a native **Hyprland Lua** configuration (`hyprland.lua`).

---

## Features

- **Top / Bottom Status Bar** ([`modules/Bar.qml`](./modules/Bar.qml))
  - App launcher button & active window title
  - Expandable MPRIS media player pill (left-click opens album art + controls popup, right-click toggles play/pause)
  - Interactive date & time pill with monthly calendar popup
  - Dynamic workspace switcher pills (1–10 persistent + automatic pills for workspaces `> 10`)
  - System tray with native context menus (auto-hide pauses while any tray menu is open)
  - Keyboard layout indicator & dropdown selector
  - Control Center status pill (Wi-Fi/Ethernet, Bluetooth, Volume, Battery)
  - Notification Center button (left-click opens history, right-click toggles Do Not Disturb)
  - Scroll on empty bar space to adjust volume (configurable step, default `5%`)
  - Auto-hide with optional **"Keep visible on empty workspace"** toggle
- **Application Dock** ([`modules/Dock.qml`](./modules/Dock.qml))
  - Pinned and running applications with open window count badges and running indicators
  - Hovering a running app displays static window miniatures (`ScreencopyView`) with window titles and close buttons
  - Right-click context menu to open new windows, pin/unpin apps, or close all windows
  - Floating or edge-attached styles, customizable icon size, opacity, and auto-hide (with **"Keep visible on empty workspace"**)
- **Desktop Widgets** ([`modules/DesktopWidgets.qml`](./modules/DesktopWidgets.qml))
  - Clock, Weather (Open-Meteo), System Monitor (CPU, RAM, Disk), Now Playing Media, and Quick App Links
  - 9 screen positions: `top-left`, `top-center`, `top-right`, `left-center`, `center`, `right-center`, `bottom-left`, `bottom-center`, `bottom-right`
- **Overlay Panels**
  - **Application Launcher** ([`modules/Launcher.qml`](./modules/Launcher.qml)): Launch apps (sorted by usage frequency), switch open windows, run shell commands (`>`), calculate math expressions (`=`), search the web (`?`), or trigger session/shell actions
  - **Workspace Switcher** ([`modules/WorkspaceSwitcher.qml`](./modules/WorkspaceSwitcher.qml)): 10-workspace overview grid with proportional static window miniatures, keyboard navigation (`Arrows`, `1–0`, `Enter`), and click-to-switch
  - **Control Center** ([`modules/ControlCenter.qml`](./modules/ControlCenter.qml)): Quick toggles (Wi-Fi, Bluetooth, DND, Dark/Light theme, Screen Recorder), expandable Wi-Fi & Bluetooth device lists, Volume/Microphone/Brightness sliders, Media card, and Power Profiles
  - **Notification Daemon & Center** ([`modules/NotificationPopups.qml`](./modules/NotificationPopups.qml), [`modules/NotificationCenter.qml`](./modules/NotificationCenter.qml)): Toast popups and persistent history
  - **Clipboard Manager** ([`modules/ClipboardPanel.qml`](./modules/ClipboardPanel.qml)): Searchable text & image clipboard history
  - **Wallpaper & Wallhaven Browser** ([`modules/WallpaperLayer.qml`](./modules/WallpaperLayer.qml), [`modules/WallhavenBrowser.qml`](./modules/WallhavenBrowser.qml)): Local library, slideshow timer, and integrated online Wallhaven search + one-click download & apply
  - **Settings Manager** ([`modules/Settings.qml`](./modules/Settings.qml)): Full GUI configuration for every shell feature
- **System Overlays & Security**
  - **Lock Screen** ([`modules/Lock.qml`](./modules/Lock.qml)): PAM authentication (`pam_unix.so`), Caps Lock warning badge, keyboard layout switcher, and session logout button
  - **Polkit Authentication Agent** ([`modules/PolkitAgent.qml`](./modules/PolkitAgent.qml))
  - **Screenshot & Screen Recorder** ([`modules/ScreenshotOverlay.qml`](./modules/ScreenshotOverlay.qml), [`services/Recorder.qml`](./services/Recorder.qml)): Fullscreen or interactive region capture (saves to `~/Pictures/Screenshots` and copies to clipboard) and `wf-recorder` toggle (`~/Videos/Recordings`)
  - **On-Screen Display (OSD)** ([`modules/OsdPopup.qml`](./modules/OsdPopup.qml)): Volume, microphone, brightness, media, keyboard layout code, Caps/Num/Scroll Lock, and DND
- **Unified Toolkit Theming** ([`scripts/apply-theme.py`](./scripts/apply-theme.py))
  - Automatic dominant accent color extraction from the active wallpaper or 6 built-in static palettes (`Catppuccin`, `TokyoNight`, `RosePine`, `Kanagawa`, `Gruvbox`, `Nord`)
  - Live synchronization with **Hyprland** borders/groupbars (`hyprshell_colors.lua`), **GTK 3/4** (`gtk.css`), **Qt6** (`KColorScheme` at `~/.local/share/color-schemes/Hyprshell.colors` applied via `qt6ct`), and **KDE** (`kdeglobals`)

---

## 1. Dependencies (CachyOS / Arch Linux)

Install all required packages using `pacman`:

```bash
sudo pacman -S --needed \
  hyprland xdg-desktop-portal-hyprland hyprcursor \
  quickshell hyprshutdown \
  pipewire wireplumber playerctl brightnessctl \
  networkmanager bluez bluez-utils upower \
  wl-clipboard grim slurp wf-recorder imagemagick \
  jq curl python \
  breeze breeze-icons breeze-gtk kconfig \
  noto-fonts noto-fonts-cjk noto-fonts-emoji awesome-terminal-fonts \
  kitty firefox dolphin
```

> [!IMPORTANT]
> Install **`qt6ct-kde`** from the AUR (or CachyOS repositories) rather than standard `qt6ct` — vanilla `qt6ct` does not support `KColorScheme` (`.colors`) files and applies Qt/KDE theming inconsistently:
> ```bash
> paru -S qt6ct-kde
> # or: yay -S qt6ct-kde
> ```
> Also ensure system services are enabled:
> ```bash
> sudo systemctl enable --now NetworkManager bluetooth upower
> ```

---

## 2. Installation Guide

### Step 1: Clone the repository

```bash
git clone https://github.com/DaZZeNDaZZeN/hyprshell ~/hyprshell
cd ~/hyprshell
```

### Step 2: Copy `hyprshell` into Quickshell's configuration directory

Quickshell loads shell configurations from `~/.config/quickshell/<name>`:

```bash
mkdir -p ~/.config/quickshell/hyprshell
cp -r shell.qml config components services modules scripts pam ~/.config/quickshell/hyprshell/
chmod +x ~/.config/quickshell/hyprshell/scripts/*.py ~/.config/quickshell/hyprshell/scripts/*.sh
```

### Step 3: Copy the Hyprland Lua configuration

Back up any existing `~/.config/hypr` directory, then copy the Hyprland Lua configuration files into `~/.config/hypr/`:

```bash
[ -d ~/.config/hypr ] && mv ~/.config/hypr ~/.config/hypr.backup
mkdir -p ~/.config/hypr
cp -r hypr/*.lua ~/.config/hypr/
```

### Step 4: Create media & wallpaper directories

```bash
mkdir -p ~/Pictures/Wallpapers ~/Pictures/Screenshots ~/Videos/Recordings
```

Place your wallpapers (`jpg`, `jpeg`, `png`, `webp`) inside `~/Pictures/Wallpapers` (or press `Super + Shift + W` after starting the shell to browse and download wallpapers directly from **Wallhaven**).

### Step 5: Start or Reload Hyprland

- **From a display manager or TTY**: Log into a **Hyprland** session. [`autostart.lua`](./hypr/autostart.lua) will automatically start `qs -c hyprshell`.
- **From an already running Hyprland session**:
  ```bash
  hyprctl reload
  pkill -x qs; setsid nohup qs -c hyprshell >/tmp/qs.log 2>&1 </dev/null &
  ```

---

## 3. Repository Structure

```text
hyprshell/
├── shell.qml                  # Root Quickshell entry point & IPC handler
├── config/
│   ├── Config.qml             # Persistent JSON settings (~/.config/hyprshell/config.json)
│   └── Theme.qml              # Design tokens, static palettes & toolkit sync trigger
├── components/                # Reusable UI widgets (Buttons, Sliders, Cards, Overlays)
├── services/                  # Background singletons (Audio, Network, Bt, Notifs, Media, etc.)
├── modules/                   # Desktop bars, dock, widgets, and overlay panels
├── scripts/
│   ├── apply-theme.py         # Generates KColorScheme (.colors), GTK 3/4 CSS, and Hyprland colors
│   └── extract-colors.py      # Extracts dominant accent color from current wallpaper
├── pam/
│   └── password.conf          # PAM configuration for the lock screen
└── hypr/                      # Hyprland Lua configuration files (~/.config/hypr/)
    ├── hyprland.lua           # Main Hyprland entry point
    ├── variables.lua          # Default apps (kitty, dolphin, firefox) & mainMod (SUPER)
    ├── keybindings.lua        # Window & Hyprshell IPC keybinds
    ├── hardware.lua           # Monitors, keyboard layouts (us, ru, kz), touchpad & gestures
    ├── beautification.lua     # Borders, blur, animations, window/workspace rules & VM check
    ├── autostart.lua          # Starts qs -c hyprshell and background services
    └── hyprshell_colors.lua   # Auto-generated border/groupbar colors
```

---

## 4. Default Keybindings

Configured in [`hypr/keybindings.lua`](./hypr/keybindings.lua):

| Shortcut | Action |
| :--- | :--- |
| `Super + R` | Toggle Application Launcher |
| `Alt + \`` (Grave) | Toggle Workspace Switcher (with static miniatures) |
| `Super + H` | Toggle Control Center |
| `Super + N` | Toggle Notification Center |
| `Super + I` | Toggle Settings Manager |
| `Super + V` | Toggle Clipboard History |
| `Super + Shift + W` | Toggle Wallhaven Wallpaper Browser |
| `Super + Z` | Toggle Session / Power Menu |
| `Super + L` | Lock Screen |
| `Super + Shift + S` | Screenshot Region (saves + copies to clipboard) |
| `Super + Shift + R` | Toggle Screen Recording |
| `Super + T` / `Ctrl + Alt + T` | Open Terminal (`kitty`) |
| `Super + E` | Open File Manager (`dolphin`) |
| `Super + W` | Open Browser (`firefox`) |
| `Super + C` | Close Active Window |
| `Super + B` | Toggle Floating Window |
| `Super + F` | Toggle Fullscreen |
| `Super + G` | Toggle Maximize |
| `Super + Space` | Switch Keyboard Layout (`us`, `ru`, `kz`) |
| `Super + 1…0` | Switch to Workspace 1–10 |
| `Super + Shift + 1…0` | Move Active Window to Workspace 1–10 |
| `Alt + Tab` / `Alt + Shift + Tab` | Next / Previous Workspace |

---

## 5. IPC Commands

You can control `hyprshell` from scripts or custom keybinds using `qs -c hyprshell ipc call shell <command>`:

```bash
# Toggle panels: launcher, workspaces, controlcenter, notifications, settings, clipboard, wallhaven, session
qs -c hyprshell ipc call shell toggle launcher

# Open a specific Settings page: appearance, wallpaper, bar, dock, widgets, notifs, keys, system
qs -c hyprshell ipc call shell open settings appearance

# Lock screen, take screenshots, or toggle screen recording
qs -c hyprshell ipc call shell lock
qs -c hyprshell ipc call shell screenshot region
qs -c hyprshell ipc call shell screenshot screen
qs -c hyprshell ipc call shell record

# Audio, brightness, media & wallpaper controls
qs -c hyprshell ipc call shell volume up
qs -c hyprshell ipc call shell volume down
qs -c hyprshell ipc call shell volume mute
qs -c hyprshell ipc call shell brightness up
qs -c hyprshell ipc call shell media play-pause
qs -c hyprshell ipc call shell wallpaper random
```

---

## 6. Customization & Files

- **Shell Configuration**: Stored at `~/.config/hyprshell/config.json` and managed live via **Settings** (`Super + I`).
- **Theme Token Overrides**: Edit `~/.config/hyprshell/theme-overrides.json` (accessible from **Settings → Appearance → Theme overrides**) to override any property in `Theme.qml` (`accent`, `bg`, `surface`, `text`, `radius`, etc.).
- **Custom GTK CSS**: Edit `~/.config/hyprshell/custom-gtk.css` to append custom rules to GTK 3 and GTK 4.
- **Qt6 / KDE Color Scheme**: Generated automatically at `~/.local/share/color-schemes/Hyprshell.colors` and applied to `qt6ct` (`~/.config/qt6ct/qt6ct.conf`) and `kdeglobals`.
- **VM vs. Real Hardware**: [`beautification.lua`](./hypr/beautification.lua) and [`autostart.lua`](./hypr/autostart.lua) automatically detect QEMU/Virtio-GPU (`virtio-pci`) and enable `LIBGL_ALWAYS_SOFTWARE=1` only inside virtual machines. On bare-metal AMD, Intel, or NVIDIA GPUs, full hardware acceleration and DMA-BUF zero-copy rendering are used automatically.
