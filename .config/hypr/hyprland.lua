-- Hyprland Lua config, migrated from hyprland.conf (hyprlang) for 0.55+ / 0.57.
-- Reference: https://wiki.hypr.land/Configuring/

--##################### environment ######################

hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
hl.env("XCURSOR_SIZE", "8")
hl.env("WLR_NO_HARDWARE_CURSORS", "1")
hl.env("GBM_BACKEND", "nvidia-drm")
hl.env("__GL_GSYNC_ALLOWED", "1")
hl.env("__GL_VRR_ALLOWED", "1")

--##################### autostart ######################

hl.on("hyprland.start", function()
	hl.exec_cmd("clash-party")
	hl.exec_cmd("fcitx5")
	hl.exec_cmd("swww-daemon")
	hl.exec_cmd("quickshell")
	hl.exec_cmd("mako")
	hl.exec_cmd("zsh ~/.tmp/pacman.serve")
	hl.exec_cmd("hyprctl setcursor Bibata-Modern-Classic 24")
	hl.exec_cmd("pulseaudio -k && pulseaudio --start")
	hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")
	hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
	hl.exec_cmd("echo 'Xft.dpi:110' | xrdb -merge")
end)

--##################### monitors ######################

hl.monitor({ output = "eDP-1", mode = "1920x1080@144", position = "0x0", scale = 1 })
hl.monitor({ output = "HDMI-A-1", mode = "1920x1080@120", position = "1920x0", scale = 1 })

--##################### variables ######################

hl.config({
	xwayland = { force_zero_scaling = true },

	input = {
		kb_layout = "us",
		kb_variant = "",
		kb_model = "",
		kb_options = "caps:swapescape",
		kb_rules = "",

		follow_mouse = 1,
		sensitivity = 0,

		touchpad = {
			natural_scroll = true,
			disable_while_typing = true,
			scroll_factor = 0.5,
		},
	},

	general = {
		gaps_in = 3,
		gaps_out = 8,
		border_size = 2,
		["col.active_border"] = { colors = { "rgba(c2c1ffee)", "rgba(f5b2e0aa)" }, angle = 45 },
		["col.inactive_border"] = "rgba(47464faa)",
		layout = "dwindle",
	},

	decoration = {
		rounding = 10,

		shadow = {
			enabled = true,
			range = 4,
			render_power = 3,
			color = "rgba(1a1a1aee)",
		},

		blur = {
			enabled = false,
			size = 3,
			passes = 3,
			new_optimizations = true,
			ignore_opacity = true,
		},
	},
})

-- Wake the displays on any input. Needed so the manual "熄屏" action (and the
-- Quickshell idle manager's resume path) can always be woken again.
hl.config({
	misc = {
		key_press_enables_dpms = true,
		mouse_move_enables_dpms = true,
	},
})

hl.device({
	name = "elan1203:00-04f3:307a-touchpad",
	sensitivity = 0.5,
	enabled = true,
})

--##################### animations ######################

hl.config({ animations = { enabled = true } })

hl.curve("myBezier", { type = "bezier", points = { { 0.05, 1 }, { 0.1, 1.05 } } })

hl.animation({ leaf = "windows", enabled = true, speed = 1, bezier = "myBezier" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 7, bezier = "default", style = "popin 80%" })
hl.animation({ leaf = "border", enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "borderangle", enabled = true, speed = 8, bezier = "default" })
hl.animation({ leaf = "fade", enabled = true, speed = 7, bezier = "default" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 6, bezier = "default" })

--##################### workspace rules ######################

for i = 1, 10 do
	hl.workspace_rule({ workspace = tostring(i), monitor = "HDMI-A-1" })
end
hl.workspace_rule({ workspace = "11", monitor = "eDP-1", persistent = true })

--##################### window rules ######################

hl.window_rule({
	name = "planify_transparency",
	match = { class = "^(.*)(planify)$" },
	opacity = "0.88 0.88",
})

hl.window_rule({
	name = "planify_workspace",
	match = { class = "^(.*)(planify)$" },
	workspace = "special:planner",
})

hl.window_rule({
	name = "maoduo",
	match = { class = "^(.*)(maoduo)(.*)$" },
	border_size = 0,
	no_blur = true,
	no_shadow = true,
	pin = true,
	float = true,
})

hl.window_rule({
	name = "gluqlo_no_anim",
	match = { class = "^(gluqlo)$" },
	no_anim = true,
})

--##################### keybinds ######################

local mainMod = "ALT"

hl.bind(mainMod .. " + return", hl.dsp.exec_cmd("/usr/bin/kitty --start-as=minimized"))
hl.bind(mainMod .. " + SHIFT + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd("alacritty"))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd("fuzzel --list-executables-in-path -p \" \" --fuzzy-max-distance 2"))
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd("fuzzel -p \" \" --fuzzy-max-distance 2"))
hl.bind(mainMod .. " + Y", hl.dsp.exec_cmd("swww img \"$(find ~/Pictures/Wallpapers -type f | shuf -n 1)\" --transition-type none"))
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen())
hl.bind(mainMod .. " + T", hl.dsp.window.float())

-- focus
hl.bind(mainMod .. " + H", hl.dsp.focus({ direction = "l" }))
hl.bind(mainMod .. " + L", hl.dsp.focus({ direction = "r" }))
hl.bind(mainMod .. " + K", hl.dsp.focus({ direction = "u" }))
hl.bind(mainMod .. " + J", hl.dsp.focus({ direction = "d" }))

-- move window
hl.bind(mainMod .. " + SHIFT + H", hl.dsp.window.move({ direction = "l" }))
hl.bind(mainMod .. " + SHIFT + L", hl.dsp.window.move({ direction = "r" }))
hl.bind(mainMod .. " + SHIFT + K", hl.dsp.window.move({ direction = "u" }))
hl.bind(mainMod .. " + SHIFT + J", hl.dsp.window.move({ direction = "d" }))

-- screenshots / clipboard / lock
hl.bind(mainMod .. " + A", hl.dsp.exec_cmd("~/.scripts/screenshot.sh"))
hl.bind(mainMod .. " + SHIFT + A", hl.dsp.exec_cmd(
	"grim - | satty --filename - --init-tool crop --fullscreen --copy-command wl-copy --output-filename /home/zxf/Pictures/Screenshots/$(date +%Y-%m-%d-%H-%M-%S).png --early-exit"
))
hl.bind(mainMod .. " + U", hl.dsp.exec_cmd("~/.scripts/lock-all.sh"))
-- session / power menu (lock / screen off / reboot / power off / logout)
hl.bind(mainMod .. " + Escape", hl.dsp.global("quickshell:power"))
-- power profile toggle (power-saver <-> performance; performance needs round DC)
hl.bind(mainMod .. " + SHIFT + P", hl.dsp.global("quickshell:powerprofile"))
hl.bind(mainMod .. " + SHIFT + C", hl.dsp.exec_cmd("/home/zxf/.local/bin/pushclipboard"))

-- workspaces
for i = 1, 9 do
	local key = tostring(i)
	hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = key }))
	hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = key }))
end
hl.bind(mainMod .. " + 0", hl.dsp.focus({ workspace = "10" }))
hl.bind(mainMod .. " + SHIFT + 0", hl.dsp.window.move({ workspace = "10" }))
hl.bind(mainMod .. " + backspace", hl.dsp.focus({ workspace = "11" }))
hl.bind(mainMod .. " + SHIFT + backspace", hl.dsp.window.move({ workspace = "11" }))

-- mouse
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

--##################### layout adjustment ######################
-- Delta is a percentage of the window's current size, so it behaves
-- consistently no matter how the window got its current dimensions.
local function resize_active(pctW, pctH)
	return function()
		local win = hl.get_active_window()
		if win and type(win.size) == "table" then
			hl.dispatch(hl.dsp.window.resize({
				x = math.floor(win.size.x * pctW / 100),
				y = math.floor(win.size.y * pctH / 100),
				relative = true,
			}))
		else
			hl.dispatch(hl.dsp.no_op())
		end
	end
end

hl.bind(mainMod .. " + minus", resize_active(-10, 0), { repeating = true })
hl.bind(mainMod .. " + equal", resize_active(10, 0), { repeating = true })
hl.bind(mainMod .. " + SHIFT + minus", resize_active(0, -10), { repeating = true })
hl.bind(mainMod .. " + SHIFT + equal", resize_active(0, 10), { repeating = true })

hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + O", hl.dsp.window.center())
hl.bind(mainMod .. " + backslash", hl.dsp.layout("togglesplit")) -- dwindle only
hl.bind(mainMod .. " + G", hl.dsp.group.toggle())
hl.bind(mainMod .. " + SHIFT + G", hl.dsp.group.lock_active())
hl.bind(mainMod .. " + TAB", hl.dsp.group.next(), { repeating = true })
hl.bind(mainMod .. " + SHIFT + TAB", hl.dsp.group.prev(), { repeating = true })
hl.bind(mainMod .. " + B", hl.dsp.window.bring_to_top())
hl.bind(mainMod .. " + Z", hl.dsp.window.swap({ direction = "right" }))

--##################### caelestia shell (SUPER is unused by the ALT layout) ######################

hl.bind("SUPER + SUPER_L", hl.dsp.global("caelestia:launcher"), { release = true })
hl.bind("SUPER + K", hl.dsp.global("caelestia:showall"))
hl.bind("SUPER + N", hl.dsp.global("caelestia:sidebar"))
hl.bind("CTRL + ALT + Delete", hl.dsp.global("caelestia:session"))
hl.bind("CTRL + ALT + C", hl.dsp.global("caelestia:clearNotifs"))
hl.bind("SUPER + L", hl.dsp.global("caelestia:lock"))
hl.bind("SUPER + SHIFT + S", hl.dsp.global("caelestia:screenshotFreeze"))
hl.bind("SUPER + SHIFT + ALT + S", hl.dsp.global("caelestia:screenshot"))
hl.bind("SUPER + V", hl.dsp.exec_cmd("caelestia clipboard"))
hl.bind("SUPER + ALT + V", hl.dsp.exec_cmd("caelestia clipboard -d"))
hl.bind("SUPER + period", hl.dsp.exec_cmd("caelestia emoji -p"))

-- Media / brightness: dispatched through the shell so its OSD stays in sync
hl.bind("CTRL + SUPER + Space", hl.dsp.global("caelestia:mediaToggle"), { locked = true })
hl.bind("CTRL + SUPER + equal", hl.dsp.global("caelestia:mediaNext"), { locked = true })
hl.bind("CTRL + SUPER + minus", hl.dsp.global("caelestia:mediaPrev"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.global("caelestia:mediaToggle"), { locked = true })
hl.bind("XF86AudioNext", hl.dsp.global("caelestia:mediaNext"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.global("caelestia:mediaPrev"), { locked = true })
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -c backlight set 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -c backlight set 5%-"), { locked = true, repeating = true })

--##################### submap ####################--

-- NOTE: in the old config there was no bind to enter the "words" submap
-- (the entry bind was commented out), so these binds are unreachable
-- unless something activates it. Kept as-is.
hl.define_submap("words", function()
	hl.bind("CONTROL + j", hl.dsp.exec_cmd("ydotool mousemove -a -- 200 475 && ydotool click 0xC0"))
	hl.bind("CONTROL + k", hl.dsp.exec_cmd("ydotool mousemove -a -- 500 475 && ydotool click 0xC0"))
	hl.bind("CONTROL + l", hl.dsp.exec_cmd("ydotool mousemove -a -- 800 475 && ydotool click 0xC0"))
	hl.bind("CONTROL + a", hl.dsp.exec_cmd("ydotool mousemove -a -- 500 200 && ydotool click 0xC0"))
	hl.bind("CONTROL + b", hl.dsp.exec_cmd("ydotool mousemove -a -- 500 275 && ydotool click 0xC0"))
	hl.bind("CONTROL + c", hl.dsp.exec_cmd("ydotool mousemove -a -- 500 325 && ydotool click 0xC0"))
	hl.bind("CONTROL + d", hl.dsp.exec_cmd("ydotool mousemove -a -- 500 400 && ydotool click 0xC0"))
	hl.bind("CONTROL + backspace", hl.dsp.exec_cmd("ydotool mousemove -a -- 920 25 && ydotool click -r 2 0xC0"))
	hl.bind("SUPER + backspace", hl.dsp.submap("reset"))
end)
