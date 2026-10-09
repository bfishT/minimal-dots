#!/bin/bash
# 联动锁屏：本机 + （可选）内网另一台机器
# 内网主机从 ~/.config/dotfiles-private/env.sh 的 LOCK_HOST 读取（不入公开仓库）
[ -r "$HOME/.config/dotfiles-private/env.sh" ] && . "$HOME/.config/dotfiles-private/env.sh"

ln -sf "$(swww query | grep 'HDMI-A-1' | sed "s/.*image: //")" ~/Pictures/current_wallpaper
hyprlock &
if [[ -n "${LOCK_HOST:-}" ]]; then
	ssh "${LOCK_HOST}" 'WAYLAND_DISPLAY=wayland-1 hyprlock' &
fi
wait
