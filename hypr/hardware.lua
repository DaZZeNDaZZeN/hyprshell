------------------
---- MONITORS ----
------------------

-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
hl.monitor({
	output = "eDP-1",
	mode = "1920x1080@60Hz",
	position = "auto",
	scale = "1.0",
})

hl.monitor({
	output = "DP-1",
	mode = "1920x1080@100.00Hz",
	position = "auto",
	scale = "1.0",
})

---------------
---- INPUT ----
---------------

hl.config({
	input = {
		kb_layout = "us, ru, kz",
		kb_variant = "",
		kb_model = "",
		kb_options = kb_layout_change_keybind,
		kb_rules = "",

		follow_mouse = 1,

		sensitivity = 0, -- -1.0 - 1.0, 0 means no modification.

		touchpad = {
			natural_scroll = true,
		},
	},
})

hl.gesture({
	fingers = 3,
	direction = "horizontal",
	action = "workspace",
})

hl.gesture({
	fingers = 3,
	mods = "SUPER",
	direction = "swipe",
	action = "move",
})

hl.gesture({
	fingers = 4,
	mods = "SUPER",
	direction = "swipe",
	action = "resize",
})

-- Example per-device config
-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Devices/ for more
hl.device({
	name = "logitech-g305-1",
	sensitivity = -0.8,
})
