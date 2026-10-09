import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

pragma Singleton

// Idle handling, backed by the wlr-idle-notify protocol (the same mechanism
// hypridle/swayidle use). Turns the displays off after a period of inactivity
// and wakes them again on input.
//
// On this laptop the NVIDIA dGPU drives the panel, so DPMS-off only drops GPU
// draw by ~2W (12W -> 10W); it is NOT a low-power state and the fan keeps
// spinning. Only the suspend stage actually powers the machine down. Enable it
// by setting suspendTimeout below.
//
// NOTE: this Hyprland (0.56+, Lua config) does not accept the classic
// `hyprctl dispatch dpms off`; the dispatcher must be a Lua expression, so we
// send `hl.dsp.dpms("disable" / "enable")`.
Singleton {
    id: root

    // Seconds of inactivity before the displays are turned off. <= 0 disables.
    property int screenOffTimeout: 300

    // Seconds of inactivity before auto-locking. <= 0 disables.
    // For "lock, then screen off shortly after", set lockTimeout below
    // screenOffTimeout (e.g. lock 300 / screenOff 360).
    property int lockTimeout: 0

    // Command run for auto-lock. Matches the SUPER+U bind.
    property string lockCommand: "~/.scripts/lock-all.sh"

    // Seconds of inactivity before suspending (s2idle). <= 0 disables.
    // This is the only stage that actually powers down the dGPU and quiets
    // the fan. Set e.g. 1800 (30 min) to enable. Inhibitors are respected.
    property int suspendTimeout: 0

    // Tracks whether *we* put the panel to sleep, so resume only wakes a
    // display we turned off and never clobbers a manual DPMS state.
    property bool screenOff: false

    function dpms(on) {
        Quickshell.execDetached(["hyprctl", "dispatch",
            on ? 'hl.dsp.dpms("enable")' : 'hl.dsp.dpms("disable")']);
    }

    // Screen off on idle, back on at resume.
    IdleMonitor {
        id: screenOffMonitor
        enabled: root.screenOffTimeout > 0
        timeout: root.screenOffTimeout
        respectInhibitors: true

        onIsIdleChanged: {
            if (isIdle) {
                root.screenOff = true;
                root.dpms(false);
            } else if (root.screenOff) {
                root.screenOff = false;
                root.dpms(true);
            }
        }
    }

    // Optional auto-lock. Inhibitors (fullscreen video, games, ...) are
    // respected here too, so playback will not lock the session.
    IdleMonitor {
        id: lockMonitor
        enabled: root.lockTimeout > 0
        timeout: root.lockTimeout
        respectInhibitors: true

        onIsIdleChanged: {
            if (isIdle)
                Quickshell.execDetached(["sh", "-c", root.lockCommand]);
        }
    }

    // Optional suspend. If auto-lock is off, lock first so the session is never
    // resumed unlocked; if it already fired, hyprlock is running, just suspend.
    IdleMonitor {
        id: suspendMonitor
        enabled: root.suspendTimeout > 0
        timeout: root.suspendTimeout
        respectInhibitors: true

        onIsIdleChanged: {
            if (!isIdle)
                return;
            if (root.lockTimeout > 0)
                Quickshell.execDetached(["systemctl", "suspend"]);
            else
                Quickshell.execDetached(["sh", "-c",
                    root.lockCommand + " & sleep 0.4; systemctl suspend"]);
        }
    }
}
