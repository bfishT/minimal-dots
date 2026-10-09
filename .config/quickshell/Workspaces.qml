import Quickshell.Hyprland
import QtQuick

// Waybar "ext/workspaces" equivalent, but per-monitor like Hyprland itself:
//
// - Only workspaces that exist (a window is on them, or they are the empty
//   workspace the monitor currently shows) get a pill.
// - Each monitor shows the workspaces bound to it. The laptop panel keeps
//   its persistent workspace 11; external monitors never show 11.
// - The active workspace for this monitor renders highlighted; pills for
//   workspaces that are active on another monitor render dimmed.
Item {
    id: root

    // Hyprland monitor this bar belongs to (from PanelWindow.screen.name).
    property string monitorName: ""
    property real spacing: 10

    readonly property var allWorkspaces: Hyprland.workspaces.values
    readonly property var monitor: {
        const list = Hyprland.monitors.values;
        for (let i = 0; i < list.length; ++i)
            if (list[i].name === root.monitorName)
                return list[i];
        return null;
    }

    function workspaceOnMonitor(ws) {
        if (ws === null || ws.monitor === null)
            return false;
        // Laptop panel keeps workspace 11 even when the lid is closed and
        // the panel is disabled; hide it on any other monitor regardless.
        if (ws.id === 11)
            return root.isLaptopPanel;
        return ws.monitor.name === root.monitorName;
    }

    readonly property bool isLaptopPanel: {
        const m = root.monitor;
        if (m === null || m.name === undefined)
            return false;
        // eDP-* is the conventional name for built-in panels.
        return /^eDP/.test(m.name);
    }

    // Sort by id for stable ordering, like sort-by-name in waybar.
    readonly property var visibleWorkspaces: {
        const list = [];
        for (let i = 0; i < root.allWorkspaces.length; ++i) {
            const ws = root.allWorkspaces[i];
            if (root.workspaceOnMonitor(ws))
                list.push(ws);
        }
        list.sort((a, b) => a.id - b.id);
        return list;
    }

    function workspaceById(id) {
        const list = root.allWorkspaces;
        for (let i = 0; i < list.length; ++i)
            if (list[i].id === id)
                return list[i];
        return null;
    }

    implicitWidth: content.implicitWidth
    implicitHeight: 24

    Row {
        id: content
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.spacing

        Repeater {
            model: root.visibleWorkspaces

            Rectangle {
                required property var modelData
                readonly property int wsId: modelData.id
                readonly property bool isActive: modelData.active
                readonly property bool focused: modelData.focused
                readonly property bool isOtherMonitorActive: isActive && !focused

                width: isActive ? 58 : 44
                height: 24
                radius: 15
                color: isActive ? Theme.activeBg : Theme.surface0
                opacity: root.isLaptopPanel && wsId === 11 ? 1.0 : (isOtherMonitorActive ? 0.55 : 1.0)

                Behavior on width { NumberAnimation { duration: 120 } }

                Text {
                    anchors.centerIn: parent
                    text: String(parent.wsId)
                    color: parent.isActive ? Theme.activeFg : Theme.foreground
                    font.family: Theme.fontFamily
                    font.weight: Font.Bold
                    font.pixelSize: 13
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    onClicked: {
                        if (Hyprland.usingLua)
                            Hyprland.dispatch("hl.dsp.focus({ workspace = \"" + parent.wsId + "\" })");
                        else
                            Hyprland.dispatch("workspace " + parent.wsId);
                    }
                }
            }
        }
    }
}
