-------------------
---- AUTOSTART ----
-------------------

-- See https://wiki.hypr.land/Configuring/Basics/Autostart/

hl.on("hyprland.start", function()
	hl.exec_cmd("qs -c hyprshell")
end)

hl.on("hyprland.start", function()
	hl.exec_cmd("easyeffects -w")
end)
