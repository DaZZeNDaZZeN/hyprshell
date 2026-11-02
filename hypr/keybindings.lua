---------------------
---- KEYBINDINGS ----
---------------------

kb_layout_change_keybind = "grp:win_space_toggle"
local ipc = "qs -c hyprshell ipc call shell "

-- Session & Windows
local closeWindowBind = hl.bind(mainMod .. " + C", hl.dsp.window.close())
hl.bind(
	mainMod .. " + M",
	hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'")
)

-- Applications
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd(terminal))
hl.bind("CONTROL + ALT + T", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd(browser or "firefox"))

-- Window state
hl.bind(mainMod .. " + B", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen" }))
hl.bind(mainMod .. " + G", hl.dsp.window.fullscreen({ mode = "maximized" }))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit")) -- dwindle only

-- Shell Panels & Utilities
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd(ipc .. "toggle launcher"))
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd(ipc .. "toggle notifications"))
hl.bind(mainMod .. " + H", hl.dsp.exec_cmd(ipc .. "toggle controlcenter"))
hl.bind(mainMod .. " + Z", hl.dsp.exec_cmd(ipc .. "toggle session"))
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd(ipc .. "toggle clipboard"))
hl.bind(mainMod .. " + I", hl.dsp.exec_cmd(ipc .. "toggle settings"))
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd(ipc .. "lock"))
hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd(ipc .. "toggle wallhaven"))
hl.bind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd(ipc .. "record"))
hl.bind("ALT + GRAVE", hl.dsp.exec_cmd(ipc .. "toggle workspaces"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd(ipc .. "screenshot region"))

-- Move focus with mainMod + arrow keys
hl.bind(mainMod .. " + left", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down", hl.dsp.focus({ direction = "down" }))

-- Switch workspaces with mainMod + [0-9]
-- Move active window to a workspace with mainMod + SHIFT + [0-9]
for i = 1, 10 do
	local key = i % 10 -- 10 maps to key 0
	hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
	hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

hl.bind("ALT + TAB", hl.dsp.focus({ workspace = "e+1" }))
hl.bind("ALT + SHIFT + TAB", hl.dsp.focus({ workspace = "e-1" }))
hl.bind("ALT + CONTROL + TAB", hl.dsp.window.move({ workspace = "+1" }))
hl.bind("ALT + CONTROL + SHIFT + TAB", hl.dsp.window.move({ workspace = "-1" }))

-- Example special workspace (scratchpad)
hl.bind(mainMod .. " + A", hl.dsp.workspace.toggle_special("magic"))

-- Scroll through existing workspaces with mainMod + scroll
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Laptop multimedia keys for volume and LCD brightness
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd(ipc .. "volume up"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd(ipc .. "volume down"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd(ipc .. "volume mute"), { locked = true, repeating = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd(ipc .. "mic"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd(ipc .. "brightness up"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(ipc .. "brightness down"), { locked = true, repeating = true })

-- Media playback keys
hl.bind("XF86AudioNext", hl.dsp.exec_cmd(ipc .. "media next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd(ipc .. "media play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd(ipc .. "media play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd(ipc .. "media prev"), { locked = true })
