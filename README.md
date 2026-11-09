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
- **Desktop Widgets & Interactive Widget Editor** ([`modules/DesktopWidgets.qml`](./modules/DesktopWidgets.qml), [`modules/WidgetEditor.qml`](./modules/WidgetEditor.qml), [`components/DesktopWidgetView.qml`](./components/DesktopWidgetView.qml), [`services/WidgetPresets.qml`](./services/WidgetPresets.qml))
  - **Widget Presets & Per-Wallpaper Assignment**: Create, edit, clone, rename, and delete widget presets (`~/.config/hyprshell/widgets.json`). Assign any preset to any wallpaper; wallpapers without a preset automatically use the editable `"Default"` preset.
  - **Interactive Full-Screen Canvas**: Drag to move, drag handles to resize, snap to grid, duplicate, delete, and customize per-widget or preset-wide custom colors (following `Theme.accent` or any custom hex `#rrggbb`).
  - **9 Built-in Widget Types**:
    1. **Digital Clock**: Custom Qt time and date format strings, font sizes, and alignment.
    2. **Analog Clock**: Classic dial with hour, minute, and toggleable second hand, numbers, ticks, and date.
    3. **Weather**: Open-Meteo current conditions, humidity/wind details, and multi-day forecast.
    4. **System Monitor**: Toggleable CPU, RAM, and Disk usage bars.
    5. **Media Player**: MPRIS album art, multi-player switcher, playback controls, seek slider, and volume slider.
    6. **Audio Visualizer**: Real-time 32-band spectrum analyzer ([`scripts/visualizer.py`](./scripts/visualizer.py)) supporting **Bars** or **Waves** in **Straight** or **Circular** geometry.
    7. **Audio Mixer**: Full PipeWire mixer with individually toggleable sections for Master Output, Microphone Input, Output Devices & Volumes, Input Devices & Volumes, and Per-Application Stream Volumes.
    8. **Calendar**: Interactive monthly calendar grid with month navigation and Monday/Sunday start-of-week toggle.
    9. **Command Button**: Customizable button executing any shell command on click, with one-click presets for Launcher, Settings, Session control, Media control, and apps (`kitty`, `firefox`, `dolphin`).
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
  jq curl python libqalculate \
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
│   ├── extract-colors.py      # Extracts dominant accent color from current wallpaper
│   └── visualizer.py          # Real-time 32-band audio spectrum analyzer for visualizer widgets
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
| `Alt + \`` (Grave) / `Super + Tab` | Toggle Workspace Switcher (with static miniatures) |
| `Super + H` | Toggle Control Center |
| `Super + N` | Toggle Notification Center |
| `Super + I` | Toggle Settings Manager |
| `Super + V` | Toggle Clipboard History |
| `Super + Shift + W` | Toggle Wallhaven Wallpaper Browser |
| `Super + Z` | Toggle Session / Power Menu |
| `Super + L` | Lock Screen |
| `Super + Shift + S` | Screenshot Region (saves + copies to clipboard) |
| `Super + Shift + R` | Toggle Screen Recording |
| `Mouse4` (`mouse:275`) | Toggle Microphone Mute |
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
# Toggle panels: launcher, workspaces, controlcenter, notifications, settings, widgeteditor, clipboard, wallhaven, session
qs -c hyprshell ipc call shell toggle launcher
qs -c hyprshell ipc call shell toggle widgeteditor

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

## 6. Custom Themes (JSON)

Hyprshell supports full custom theming through a hot-reloaded JSON file at **`~/.config/hyprshell/theme-overrides.json`**. Any changes saved to this file take effect immediately across the shell and (when **Sync toolkits** is enabled) automatically propagate to **Hyprland**, **GTK 3/4**, **Qt5/Qt6 (`qt6ct`)**, and **KDE (`kdeglobals`)**.

### Opening the Theme File

You can create and open `~/.config/hyprshell/theme-overrides.json` in two ways:
1. **Via Settings GUI**: Open Settings (`Super + I`) → **Appearance** → **Custom styling** → click **Open** next to **Theme overrides**.
2. **Via Terminal**:
   ```bash
   mkdir -p ~/.config/hyprshell
   ${EDITOR:-nano} ~/.config/hyprshell/theme-overrides.json
   ```

### Supported JSON Keys

All properties are optional — any key omitted falls back to your active static theme or Dark/Light base in [`config/Theme.qml`](./config/Theme.qml).

| Key | Type | Default (Dark / Light) | Description |
| :--- | :--- | :--- | :--- |
| `"accent"` | `string` (Hex) | Wallpaper / `"#7aa2f7"` | Primary highlight color used for active indicators, buttons, sliders, and window borders. |
| `"bg"` | `string` (Hex) | `"#121214"` / `"#f4f4f6"` | Base background color for bars, docks, overlays, and windows. |
| `"surface"` | `string` (Hex) | `"#1c1c20"` / `"#ffffff"` | Elevated card, sidebar, popover, and control surface color. |
| `"surface2"` | `string` (Hex) | `"#28282e"` / `"#e8e8ec"` | Secondary surface color for inputs, chips, and nested containers. |
| `"text"` | `string` (Hex) | `"#ececf0"` / `"#1b1b1f"` | Primary foreground text and icon color. |
| `"subtext"` | `string` (Hex) | `"#9a9aa6"` / `"#62626c"` | Muted secondary text, labels, and inactive icons. |
| `"radius"` | `number` (Int) | `16` | Base corner radius in pixels (`radiusS` and `radiusL` scale automatically). |
| `"font"` | `string` | `"Noto Sans"` | Primary UI font family across all shell modules. |

> [!NOTE]
> Derived tokens (`onAccent`, `accentDim`, `accentSoft`, `surface3`, `border`, `hover`, `panel`, `barPanel`, `dockPanel`, `widgetsPanel`, `card`, `radiusS`, `radiusL`) are computed automatically from the tokens above and your opacity settings in `config.json`.
> Base mode (`"dark"` vs `"light"`) and separate Dark/Light theme presets (`darkTheme` and `lightTheme`) are controlled in `~/.config/hyprshell/config.json`.

### Example Custom Themes (`~/.config/hyprshell/theme-overrides.json`)

#### Tokyo Night
```json
{
  "accent": "#7aa2f7",
  "bg": "#1a1b26",
  "surface": "#24283b",
  "surface2": "#292e42",
  "text": "#c0caf5",
  "subtext": "#565f89",
  "radius": 16,
  "font": "Noto Sans"
}
```

#### Dracula
```json
{
  "accent": "#bd93f9",
  "bg": "#1e1f29",
  "surface": "#282a36",
  "surface2": "#44475a",
  "text": "#f8f8f2",
  "subtext": "#6272a4"
}
```

#### Kanagawa Wave
```json
{
  "accent": "#7e9cd8",
  "bg": "#1f1f28",
  "surface": "#2a2a37",
  "surface2": "#363646",
  "text": "#dcd7ba",
  "subtext": "#727169"
}
```

#### Resetting to Default
To disable custom JSON overrides and return to the GUI settings, replace the file contents with an empty JSON object `{}` or delete `~/.config/hyprshell/theme-overrides.json`:
```bash
echo '{}' > ~/.config/hyprshell/theme-overrides.json
```

### Exported Palette for External Scripts (`colors.json`)

Whenever the active theme changes, [`scripts/apply-theme.py`](./scripts/apply-theme.py) writes the resolved palette to **`~/.config/hyprshell/colors.json`**:

```json
{"mode":"dark","accent":"#7aa2f7","bg":"#1a1b26","surface":"#24283b","text":"#c0caf5"}
```

You can read this file from external scripts or tools (e.g., `jq` in terminal/bar scripts) to match your active Hyprshell palette.

---

## 7. Other Customization & Files

- **Shell Configuration**: Stored at `~/.config/hyprshell/config.json` and managed live via **Settings** (`Super + I`).
- **Custom GTK CSS**: Edit `~/.config/hyprshell/custom-gtk.css` to append custom rules to GTK 3 and GTK 4.
- **Qt6 / KDE Color Scheme**: Generated automatically at `~/.local/share/color-schemes/Hyprshell.colors` and applied to `qt6ct` (`~/.config/qt6ct/qt6ct.conf`) and `kdeglobals`.
- **VM vs. Real Hardware**: [`beautification.lua`](./hypr/beautification.lua) and [`autostart.lua`](./hypr/autostart.lua) automatically detect QEMU/Virtio-GPU (`virtio-pci`) and enable `LIBGL_ALWAYS_SOFTWARE=1` only inside virtual machines. On bare-metal AMD, Intel, or NVIDIA GPUs, full hardware acceleration and DMA-BUF zero-copy rendering are used automatically.
