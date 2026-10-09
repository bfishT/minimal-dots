import QtQuick

// Waybar config has no active "sway/mode" equivalent in Hyprland, and the
// original quickshell Mode.qml had a bogus implementation (treated any
// existing workspace as "resize"). Waybar only renders the pill when a mode
// is actually active, so this module is kept but disabled by default.
Item {
    id: root
    property bool active: false
    property string mode: ""

    implicitWidth: root.active ? label.implicitWidth : 0
    implicitHeight: 22

    Text {
        id: label
        anchors.verticalCenter: parent.verticalCenter
        visible: root.active && root.mode.length > 0
        text: root.mode
        color: Theme.warning
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        font.italic: true
    }
}
