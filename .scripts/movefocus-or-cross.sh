#!/bin/bash
direction="$1"
cross_x="$2"
cross_y="$3"

# get cursor position and total workspace width
cursor_x=$(hyprctl cursorpos -j | jq -r '.x')
monitors=$(hyprctl -j monitors | jq '[.[] | .x + .width] | max - min')
# get min/max x of workspace
min_x=$(hyprctl -j monitors | jq '[.[] | .x] | min')
max_x=$(hyprctl -j monitors | jq '[.[] | .x + .width] | max')

edge_margin=50

if [[ "$direction" == "r" ]]; then
	if (( cursor_x >= max_x - edge_margin )); then
		hyprctl dispatch movecursor "$cross_x" "$cross_y"
	else
		hyprctl dispatch movefocus r
	fi
elif [[ "$direction" == "l" ]]; then
	if (( cursor_x <= min_x + edge_margin )); then
		hyprctl dispatch movecursor "$cross_x" "$cross_y"
	else
		hyprctl dispatch movefocus l
	fi
fi
