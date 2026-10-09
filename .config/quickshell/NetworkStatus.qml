import Quickshell
import Quickshell.Networking
import QtQuick

Item {
    id: root

    readonly property var wifi: findWifi()
    readonly property var wired: findWired()
    readonly property var activeWifi: wifi !== null ? findActiveWifi(wifi.networks.values) : null

    function findWifi() {
        const devices = Networking.devices.values;
        for (let i = 0; i < devices.length; ++i) {
            const d = devices[i];
            if (d.type === DeviceType.Wifi) return d;
        }
        return null;
    }

    function findWired() {
        const devices = Networking.devices.values;
        for (let i = 0; i < devices.length; ++i) {
            const d = devices[i];
            if (d.type === DeviceType.Wired) return d;
        }
        return null;
    }

    function findActiveWifi(nets) {
        for (let i = 0; i < nets.length; ++i)
            if (nets[i].connected)
                return nets[i];
        return null;
    }

    // waybar: format-wifi "\uf1eb  {signalStrength}%", format-ethernet "\uf0c1",
    // format-disconnected "\uf071  Disconnected"
    readonly property string text: {
        if (root.activeWifi)
            return Theme.iconWifi + "  " + Math.round(root.activeWifi.signalStrength || 0) + "%";
        if (root.wired && root.wired.connected)
            return Theme.iconEthernet;
        return Theme.iconDisconnected + "  Disconnected";
    }

    implicitWidth: label.implicitWidth
    implicitHeight: 22

    Text {
        id: label
        anchors.verticalCenter: parent.verticalCenter
        text: root.text
        color: Theme.foreground
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
    }
}
