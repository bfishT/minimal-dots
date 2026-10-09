import Quickshell
import Quickshell.Services.Pipewire
import QtQuick

Item {
    id: root
    implicitWidth: label.implicitWidth
    implicitHeight: 22

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool muted: sink !== null && sink.audio !== null ? sink.audio.muted : false
    readonly property real volume: sink !== null && sink.audio !== null ? sink.audio.volume : 0

    // Required for the node's properties to stay live.
    PwObjectTracker {
        objects: root.sink !== null ? [root.sink] : []
    }

    // Two states only: on and muted. (Previously low volume reused the mute
    // glyph, which made it look muted while it was not.)
    function icon() {
        return root.muted ? Theme.iconVolumeMute : Theme.iconVolume;
    }

    Text {
        id: label
        anchors.verticalCenter: parent.verticalCenter
        text: root.icon() + " " + Math.round(root.volume * 100) + "%"
        color: root.muted ? Theme.subtext : Theme.foreground
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton) {
                if (root.sink && root.sink.audio)
                    root.sink.audio.muted = !root.sink.audio.muted;
            } else {
                Quickshell.execDetached(["pavucontrol"]);
            }
        }
        onWheel: (wheel) => {
            // Scrolling must not change volume while muted; left click unmutes.
            if (!root.sink || !root.sink.audio || root.sink.audio.muted)
                return;
            const up = wheel.angleDelta.y > 0;
            const step = 0.05;
            root.sink.audio.volume = Math.max(0, Math.min(1,
                root.sink.audio.volume + (up ? step : -step)));
        }
    }
}
