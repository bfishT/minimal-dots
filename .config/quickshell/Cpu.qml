import Quickshell.Io
import QtQuick

Item {
    id: root
    property int interval: 2000
    property real usage: 0

    implicitWidth: label.implicitWidth
    implicitHeight: 22

    Text {
        id: label
        anchors.verticalCenter: parent.verticalCenter
        text: Theme.iconCpu + " \u2009" + Math.round(root.usage) + "%"
        color: Theme.foreground
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
    }

    property real lastIdle: 0
    property real lastTotal: 0

    Process {
        id: proc
        command: ["cat", "/proc/stat"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                // Only the first "cpu ..." aggregate line matters.
                const first = text.trim().split("\n")[0];
                const f = first.trim().split(/\s+/).slice(1).map(Number);
                if (f.length < 5)
                    return;
                const idle = f[3] + (f[4] || 0);
                const total = f.reduce((a, b) => a + b, 0);
                if (root.lastTotal > 0) {
                    const dt = total - root.lastTotal;
                    if (dt > 0) {
                        const value = 100 * (1 - (idle - root.lastIdle) / dt);
                        root.usage = Math.max(0, Math.min(100, value));
                    }
                }
                root.lastIdle = idle;
                root.lastTotal = total;
            }
        }
    }

    // quickshell's Process has no exec(); re-run by toggling `running`.
    Timer {
        interval: root.interval
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!proc.running) proc.running = true
    }
}
