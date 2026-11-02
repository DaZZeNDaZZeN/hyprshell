-------------------
---- AUTOSTART ----
-------------------

-- See https://wiki.hypr.land/Configuring/Basics/Autostart/

hl.on("hyprland.start", function()
	hl.exec_cmd("LIBGL_ALWAYS_SOFTWARE=1 qs -c hyprshell")
end)

hl.on("hyprland.start", function()
	hl.exec_cmd("easyeffects -w")
end)
