import Quickshell.Io
import QtQuick

Item {
    id: root
    // waybar memory config: interval 30, format "\uf0c9  {used:0.2f}GB"
    property int interval: 30000
    property string current: "--"

    implicitWidth: label.implicitWidth
    implicitHeight: 22

    Text {
        id: label
        anchors.verticalCenter: parent.verticalCenter
        text: root.current
        color: Theme.foreground
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
    }

    Process {
        id: proc
        command: ["cat", "/proc/meminfo"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                const total = text.match(/^MemTotal:\s+(\d+) kB/m);
                const avail = text.match(/^MemAvailable:\s+(\d+) kB/m);
                if (!total || !avail)
                    return;
                const usedKb = Number(total[1]) - Number(avail[1]);
                root.current = Theme.iconMemory + "  " + (usedKb / 1048576).toFixed(2) + "GB";
            }
        }
    }

    Timer {
        interval: root.interval
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!proc.running) proc.running = true
    }
}
