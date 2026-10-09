#!/usr/bin/env bash
# Power-profile toggle for this laptop (Redmi/TIMI A7S, bitland-mifs-wmi EC).
#
#   power-profile.sh              # cycle: performance <-> power-saver
#   power-profile.sh performance  # force performance
#   power-profile.sh power-saver  # force power-saver (a.k.a. quiet)
#
# Only two real states are used: `balanced` is deliberately skipped because on
# this EC it does not stick (the driver reads it back as `performance`).
#
# NOTE: switching to `performance` requires the round DC barrel charger; on
# USB-C PD or battery the driver rejects it with EOPNOTSUPP. We detect that and
# notify instead of failing silently.

set -u

notify() {
    # $1 = summary, $2 = body, $3 = urgency (optional, default normal)
    command -v notify-send >/dev/null 2>&1 || return 0
    notify-send -a "电源模式" -u "${3:-normal}" "$1" "$2" 2>/dev/null || true
}

if ! command -v powerprofilesctl >/dev/null 2>&1; then
    notify "电源模式" "找不到 powerprofilesctl" critical
    exit 1
fi

# Trim whitespace/newlines from powerprofilesctl output.
trim() { printf '%s' "$1" | tr -d '[:space:]'; }

current="$(trim "$(powerprofilesctl get 2>/dev/null || true)")"

case "${1:-}" in
    performance|perf)
        target=performance
        ;;
    power-saver|powersaver|saver|quiet)
        target=power-saver
        ;;
    "")
        if [ "$current" = "performance" ]; then
            target=power-saver
        else
            target=performance
        fi
        ;;
    *)
        echo "usage: $0 [performance|power-saver]" >&2
        exit 2
        ;;
esac

if [ "$current" = "$target" ]; then
    notify "电源模式" "已经是 $( [ "$target" = performance ] && echo 性能 || echo 省电 )"
    exit 0
fi

if ! powerprofilesctl set "$target" 2>/dev/null; then
    if [ "$target" = "performance" ]; then
        notify "切换失败" "需要圆孔 DC 电源才能用性能模式" critical
    else
        notify "切换失败" "无法切换到 ${target}" critical
    fi
    exit 1
fi

# Verify: the call may "succeed" while the EC keeps the previous mode.
new="$(trim "$(powerprofilesctl get 2>/dev/null || true)")"
if [ "$new" != "$target" ]; then
    if [ "$target" = "performance" ]; then
        notify "切换失败" "需要圆孔 DC 电源才能用性能模式" critical
    else
        notify "切换失败" "切换未生效(当前 ${new:-未知})" critical
    fi
    exit 1
fi

if [ "$target" = "performance" ]; then
    notify "电源模式" "已切换到 性能"
else
    notify "电源模式" "已切换到 省电"
fi
