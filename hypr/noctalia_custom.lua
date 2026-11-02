hl.layer_rule({
	name = "hyprshell",
	match = {
		namespace = "^hyprshell-(bar|dock|widgets|notifications|osd|launcher|controlcenter|session|workspaces|clipboard|wallhaven|settings|polkit)$",
	},
	no_anim = true,
	ignore_alpha = 0.3,
	blur = true,
	blur_popups = true,
})

hl.workspace_rule({ workspace = "1", monitor = "", persistent = true })
hl.workspace_rule({ workspace = "2", monitor = "", persistent = true })
hl.workspace_rule({ workspace = "3", monitor = "", persistent = true })
hl.workspace_rule({ workspace = "4", monitor = "", persistent = true })
hl.workspace_rule({ workspace = "5", monitor = "", persistent = true })
hl.workspace_rule({ workspace = "6", monitor = "", persistent = true })
hl.workspace_rule({ workspace = "7", monitor = "", persistent = true })
hl.workspace_rule({ workspace = "8", monitor = "", persistent = true })
hl.workspace_rule({ workspace = "9", monitor = "", persistent = true })
hl.workspace_rule({ workspace = "10", monitor = "", persistent = true })
