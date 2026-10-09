import Quickshell.Io
import QtQuick

Item {
    id: root
    property string command: ""
    property string title: ""
    property int interval: 2000
    property bool compact: false

    signal result(string text)

    implicitWidth: label.implicitWidth
    implicitHeight: 22

    property string text: ""

    Text {
        id: label
        anchors.verticalCenter: parent.verticalCenter
        text: root.text
        color: Theme.foreground
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
    }

    Process {
        id: process
        command: [ "/bin/sh", "-lc", root.command ]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                const out = text.trim();
                if (out.length > 0)
                    root.text = out;
            }
        }
    }

    Timer {
        interval: root.interval
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!process.running) process.running = true
    }
}
