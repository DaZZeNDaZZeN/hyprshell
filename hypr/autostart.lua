-------------------
---- AUTOSTART ----
-------------------

-- See https://wiki.hypr.land/Configuring/Basics/Autostart/

hl.on("hyprland.start", function()
	hl.exec_cmd("grep -qiE 'virtio|qemu' /sys/class/drm/card*/device/uevent /sys/class/dmi/id/sys_vendor 2>/dev/null && export LIBGL_ALWAYS_SOFTWARE=1; exec qs -c hyprshell")
end)

hl.on("hyprland.start", function()
	hl.exec_cmd("easyeffects -w")
end)
