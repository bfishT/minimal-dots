#!/bin/bash
ln -sf "$(swww query | grep 'HDMI-A-1' | sed "s/.*image: //")" ~/Pictures/current_wallpaper
hyprlock &
ssh zxf@192.168.100.1 'WAYLAND_DISPLAY=wayland-1 hyprlock' &
wait
