import Quickshell
import QtQuick

pragma Singleton

// Shared palette, mirroring waybar style.css.
Singleton {
    id: root

    readonly property color background: "#0b0b0e"
    readonly property color barBackground: Qt.rgba(11 / 255, 11 / 255, 14 / 255, 0.86)

    readonly property color foreground: "#e5e1e7"
    readonly property color subtext: "#8a8694"

    readonly property color surface0: "#1c1b1f"
    readonly property color surface1: "#45455c"

    readonly property color activeBg: "#595992"
    readonly property color activeFg: "#e2dfff"

    // waybar battery states: warning 30, critical 15.
    readonly property color warning: "#d8a657"
    readonly property color critical: "#ea6962"
    readonly property color accent: "#b9a8ff"
    readonly property color splayerPaused: "#8a8694"

    // Must be the Nerd Font variant: plain "JetBrainsMono" resolves to the
    // non-Nerd font on this system and drops several glyphs (e.g. U+F028).
    readonly property string fontFamily: "JetBrainsMono Nerd Font"
    readonly property int fontSize: 14

    // Bar metrics, shared so the OSD panel can align with the bar.
    readonly property int barHeight: 30
    readonly property int barMargin: 5
    readonly property int barRadius: 10

    // Icons taken verbatim from waybar config.jsonc.
    readonly property string iconCpu: "\uf2db"
    readonly property string iconMemory: "\uf0c9"
    readonly property string iconWifi: "\uf1eb"
    readonly property string iconEthernet: "\uf0c1"
    readonly property string iconDisconnected: "\uf071"
    readonly property string iconBatteryFull: "\uf578"   // battery-full
    readonly property string iconBattery90: "\uf579"     // battery-three-quarters
    readonly property string iconBattery70: "\uf57a"     // battery-half
    readonly property string iconBattery50: "\uf57b"     // battery-quarter
    readonly property string iconBattery30: "\uf57c"     // battery-empty
    readonly property string iconBatteryLow: "\uf57d"    // battery
    readonly property string iconBatteryEmpty: "\uf57e"  // battery
    readonly property string iconCharging: "\uf0e7"
    readonly property string iconVolume: "\uf028"
    readonly property string iconVolumeMid: "\uf027"
    readonly property string iconVolumeMute: "\uf466"
    readonly property string iconBrightness: "\uf0eb"
    readonly property string iconCalendar: "\uf073"
    readonly property string iconEye: "\uf06e"
    readonly property string iconEyeSlash: "\uf070"
}
