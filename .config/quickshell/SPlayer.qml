import Quickshell
import Quickshell.Io
import QtQuick

// Port of waybar/scripts/waybar-splayer.py: polls SPlayer's local control API
// and shows "artist - title" with play/pause state.
Item {
    id: root

    readonly property string baseUrl: "http://127.0.0.1:25884"

    property string title: ""
    property string artist: ""
    property bool playing: false
    property bool active: false
    property int currentMs: 0
    property int durationMs: 0

    implicitWidth: label.implicitWidth
    implicitHeight: 22

    function fmtTime(ms) {
        if (!ms || ms < 0)
            return "0:00";
        const s = Math.floor(ms / 1000);
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
    }

    property string displayText: {
        if (!active)
            return "";
        const icon = playing ? "\u25b6 " : "\u23f8 ";
        const body = artist.length > 0 ? artist + " - " + title : title;
        const line = icon + body;
        // waybar-splayer.c: MAX_LENGTH 40 (waybar-splayer.py uses 44)
        return line.length > 40 ? line.slice(0, 39) + "\u2026" : line;
    }

    function poll() {
        if (!poller.running)
            poller.running = true;
    }

    Process {
        id: poller
        command: ["curl", "-sf", "-m", "1", root.baseUrl + "/api/control/song-info"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                try {
                    const body = JSON.parse(text);
                    const d = body && body.code === 200 ? body.data : null;
                    if (!d) {
                        root.active = false;
                        return;
                    }
                    root.playing = !!d.playStatus;
                    root.title = (d.name || "").trim();
                    const artists = d.artists || [];
                    root.artist = artists.length > 0 ? (artists[0].name || "").trim() : "";
                    root.currentMs = d.currentTime || 0;
                    root.durationMs = d.duration || 0;
                    root.active = true;
                } catch (e) {
                    root.active = false;
                }
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.poll()
    }

    Text {
        id: label
        anchors.verticalCenter: parent.verticalCenter
        visible: root.active
        text: root.displayText
        color: root.playing ? Theme.accent : Theme.splayerPaused
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        font.bold: root.playing
        font.italic: !root.playing
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: (mouse) => {
            let path = "/api/control/toggle";
            if (mouse.button === Qt.RightButton)
                path = "/api/control/next";
            else if (mouse.button === Qt.MiddleButton)
                path = "/api/control/prev";

            // Optimistic feedback so the bar reacts instantly instead of
            // waiting for the next poll (the API round-trip can take ~1s).
            if (path === "/api/control/toggle")
                root.playing = !root.playing;

            control.command = ["curl", "-sf", "-m", "1", root.baseUrl + path];
            control.running = true;
        }
    }

    Process {
        id: control
        command: ["true"]
        // Reconcile with the server as soon as the action finishes.
        onExited: repoll.restart()
    }

    Timer {
        id: repoll
        interval: 250
        repeat: false
        onTriggered: root.poll()
    }
}
