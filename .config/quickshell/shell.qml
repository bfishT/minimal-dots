//@ pragma IconTheme Tela-circle-grey

import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import Quickshell.Services.Pipewire
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

ShellRoot {
    id: root

    readonly property real barHeight: Theme.barHeight
    readonly property real barMargin: Theme.barMargin
    readonly property real barRadius: Theme.barRadius

    // Activate the idle manager (dpms-off + optional auto-lock). Tune the
    // timeouts and the lock command in Idle.qml. Referencing the singleton
    // here keeps it alive for the whole shell.
    readonly property var idle: Idle

    // Activate the power-profile toggle singleton (GlobalShortcut + IPC).
    // Bound to ALT+SHIFT+P via hyprland.lua.
    readonly property var power: Power

    // Spacing tokens. Left block is grouped (stats together, then network,
    // then media); right block uses one uniform gap. Tune these only.
    readonly property real moduleSpacing: 10   // gap inside a group
    readonly property real groupExtra: 12       // extra gap between groups (10 + 12 = 22)
    readonly property real rightSpacing: 14     // uniform gap on the right
    readonly property real edgePadding: 10      // first/last content to bar edge (waybar: 10)

    // One bar per connected monitor, like waybar.
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: barWindow

            required property ShellScreen modelData

            screen: modelData
            anchors.top: true
            anchors.left: true
            anchors.right: true
            implicitHeight: root.barHeight
            margins.top: root.barMargin
            margins.left: root.barMargin
            margins.right: root.barMargin
            exclusiveZone: root.barHeight
            color: "transparent"

            Rectangle {
                id: barBackground
                anchors.fill: parent
                radius: root.barRadius
                color: Theme.barBackground

                // Scroll anywhere on the bar to adjust volume; Shift for
                // brightness. Kept below the modules so their own click areas
                // stay on top.
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                    onWheel: (wheel) => {
                        const up = wheel.angleDelta.y > 0;
                        if (wheel.modifiers & Qt.ShiftModifier) {
                            if (up) Brightness.increase();
                            else Brightness.decrease();
                            return;
                        }
                        const sink = Pipewire.defaultAudioSink;
                        // Don't change volume while muted.
                        if (sink && sink.audio && !sink.audio.muted) {
                            const step = 0.05;
                            sink.audio.volume = Math.max(0, Math.min(1,
                                sink.audio.volume + (up ? step : -step)));
                        }
                    }
                }

                Item {
                    id: barContent
                    anchors.fill: parent

                    // Left block, pinned to the left edge.
                    // Group 1: Cpu + Memory. Group 2: NetworkStatus. Group 3: SPlayer.
                    RowLayout {
                        id: leftBlock
                        anchors.left: parent.left
                        anchors.leftMargin: root.edgePadding
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: root.moduleSpacing

                        Cpu {}
                        Memory {}
                        NetworkStatus { Layout.leftMargin: root.groupExtra }
                        SPlayer { Layout.leftMargin: root.groupExtra }
                    }

                    // Center block, pinned to the true horizontal center so
                    // wide left/right blocks cannot push it off-center.
                    Workspaces {
                        id: centerBlock
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        monitorName: barWindow.modelData.name
                    }

                    // Right block, pinned to the right edge, uniform spacing.
                    RowLayout {
                        id: rightBlock
                        anchors.right: parent.right
                        anchors.rightMargin: root.edgePadding
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: root.rightSpacing

                        Tray {}
                        IdleInhibitorBar { targetWindow: barWindow }
                        PulseAudio {}
                        Backlight {}
                        Battery {}
                        Clock {}
                    }
                }
            }
        }
    }

    // Session / power overlay, toggled by the "quickshell:power" global
    // shortcut (ALT+Escape in hyprland.lua).
    PowerMenu {}
}
