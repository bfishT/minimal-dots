#!/bin/bash
# 截取当前活动显示器
monitor=$(hyprctl -j monitors | jq -r '.[] | select(.focused) | .name')
grim -o "$monitor" - | satty --filename - --init-tool crop --fullscreen --copy-command wl-copy --output-filename /home/zxf/Pictures/Screenshots/$(date +%Y-%m-%d-%H-%M-%S).png --early-exit
