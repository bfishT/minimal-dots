import Quickshell
import QtQuick

// Backlight value comes from the shared Brightness singleton, which watches
// sysfs (so keybinds and terminal brightnessctl are reflected too).
Item {
    id: root
    implicitWidth: label.implicitWidth
    implicitHeight: 22

    Text {
        id: label
        anchors.verticalCenter: parent.verticalCenter
        text: Theme.iconBrightness + "\u202f" + Brightness.percent + "%"
        color: Theme.foreground
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
    }

    MouseArea {
        anchors.fill: parent
        onWheel: (wheel) => {
            const up = wheel.angleDelta.y > 0;
            Brightness.setPercent(Brightness.percent + (up ? 2 : -2));
        }
    }
}
