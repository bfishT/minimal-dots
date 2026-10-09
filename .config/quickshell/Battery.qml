import Quickshell
import Quickshell.Services.UPower
import QtQuick

Item {
    id: root

    // Prefer the aggregated display device, but it is unpopulated on some
    // systems, so fall back to the first real laptop battery.
    readonly property var battery: {
        const display = UPower.displayDevice;
        if (display !== null && display.isLaptopBattery)
            return display;
        const devs = UPower.devices.values;
        for (let i = 0; i < devs.length; ++i)
            if (devs[i].isLaptopBattery)
                return devs[i];
        return null;
    }

    readonly property bool hasBattery: battery !== null
    // quickshell normalizes UPower's 0..100 wire value to 0..1
    // (device.cpp: wire * 0.01), so scale back up before displaying.
    readonly property real percent: hasBattery ? battery.percentage * 100 : 0
    readonly property bool charging: hasBattery
        && (battery.state === UPowerDeviceState.Charging
            || battery.state === UPowerDeviceState.FullyCharged)
    readonly property bool plugged: hasBattery
        && battery.state === UPowerDeviceState.PendingCharge

    // waybar format-icons list, lowest first: \uf579 \uf57a \uf57b \uf57c \uf57d \uf57e \uf578
    function icon() {
        if (root.charging || root.plugged)
            return Theme.iconCharging;
        const p = root.percent;
        if (p >= 90) return Theme.iconBatteryFull;
        if (p >= 70) return Theme.iconBattery90;
        if (p >= 50) return Theme.iconBattery70;
        if (p >= 30) return Theme.iconBattery50;
        if (p >= 15) return Theme.iconBattery30;
        return Theme.iconBatteryLow;
    }

    readonly property color fg: {
        if (root.charging || root.plugged)
            return Theme.foreground;
        if (root.percent <= 15) return Theme.critical;
        if (root.percent <= 30) return Theme.warning;
        return Theme.foreground;
    }

    implicitWidth: label.implicitWidth
    implicitHeight: 22

    Text {
        id: label
        anchors.verticalCenter: parent.verticalCenter
        visible: root.hasBattery
        // waybar format "{icon}&#8239;{capacity}%"
        text: root.icon() + "\u202f" + Math.round(root.percent) + "%"
        color: root.fg
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
    }
}
