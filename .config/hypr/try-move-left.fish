set wid (hyprctl activeworkspace -j | jq '.id')
set nr_w (hyprctl clients | grep "workspace: $wid " | grep -v "Window" | grep -v "title" | wc -l)

if test $nr_w -eq 0
    hyprctl dispatch movecursor 500 1000
    return
end


if is_edge_window right
    hyprctl dispatch movecursor 500 1000
else
    hyprctl dispatch movefocus right
end
