import Quickshell
import Quickshell.Wayland
import QtQuick

// Waybar idle_inhibitor: "{icon}", activated "\uf06e", deactivated "\uf070"
Item {
    id: root

    // Set by the parent bar to the PanelWindow this inhibitor should apply to.
    property var targetWindow: null

    property alias enabled: inhibitor.enabled

    implicitWidth: label.implicitWidth
    implicitHeight: 22

    IdleInhibitor {
        id: inhibitor
        enabled: false
        window: root.targetWindow
    }

    Text {
        id: label
        anchors.verticalCenter: parent.verticalCenter
        text: root.enabled ? Theme.iconEye : Theme.iconEyeSlash
        color: root.enabled ? Theme.primary : Theme.subtext
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.enabled = !root.enabled
    }
}
