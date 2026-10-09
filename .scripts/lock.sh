#!/bin/bash
ln -sf "$(swww query | grep 'HDMI-A-1' | sed "s/.*image: //")" ~/Pictures/current_wallpaper
hyprlock
