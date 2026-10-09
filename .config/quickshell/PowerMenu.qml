import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

// Session / power overlay, shown on the focused monitor.
//
// Triggered by the Hyprland global shortcut "quickshell:power", which
// hyprland.lua binds to ALT+Escape:
//     hl.bind("ALT + Escape", hl.dsp.global("quickshell:power"))
//
// Can also be driven from a terminal:
//     qs ipc call power toggle
Scope {
    id: menu

    property bool shown: false

    // ---- 尺寸调节：改这几个值即可 ----
    property int buttonWidth: 120           // 单个按钮宽
    property int buttonHeight: 120          // 单个按钮高
    property int buttonSpacing: 25         // 按钮之间的间距
    property int cardPadding: 25           // 卡片内边距（每边）
    property int iconSize: 40              // 图标字号
    property int labelSize: Theme.fontSize // 文字字号
    property int iconLabelSpacing: 8       // 图标与文字间距

    function toggle() {
        menu.shown = !menu.shown;
    }

    function close() {
        menu.shown = false;
    }

    // Detach the action and hide the menu first, so the UI feels instant.
    function run(argv) {
        menu.close();
        Quickshell.execDetached(argv);
    }

    GlobalShortcut {
        appid: "quickshell"
        name: "power"
        description: "Toggle power menu"
        onPressed: menu.toggle()
    }

    IpcHandler {
        target: "power"

        function toggle(): void { menu.toggle(); }
        function open(): void { menu.shown = true; }
        function close(): void { menu.shown = false; }
    }

    readonly property var items: [
        {
            icon: "\uf023", label: "锁屏",
            action: () => menu.run(["sh", "-c", "~/.scripts/lock-all.sh"]),
        },
        {
            icon: "\uf186", label: "熄屏",
            action: () => menu.run(["hyprctl", "dispatch", 'hl.dsp.dpms("disable")']),
        },
        {
            icon: "\uf021", label: "重启",
            action: () => menu.run(["systemctl", "reboot"]),
        },
        {
            icon: "\uf011", label: "关机",
            action: () => menu.run(["systemctl", "poweroff"]),
        },
        {
            icon: "\uf08b", label: "注销",
            action: () => menu.run(["hyprctl", "dispatch", "hl.dsp.exit()"]),
        },
    ]

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win

            required property ShellScreen modelData

            readonly property bool onFocusedMonitor:
                Hyprland.focusedMonitor !== null
                && Hyprland.focusedMonitor.name === modelData.name

            screen: modelData
            visible: menu.shown && onFocusedMonitor
            color: "transparent"

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusiveZone: 0

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "quickshell:power"
            WlrLayershell.keyboardFocus:
                visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            // Dim backdrop; click outside the card to dismiss, Escape too.
            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0, 0, 0, 0.45)
                focus: true
                Keys.onEscapePressed: menu.close()

                MouseArea {
                    anchors.fill: parent
                    onClicked: menu.close()
                }
            }

            Rectangle {
                id: card
                anchors.centerIn: parent
                width: row.implicitWidth + menu.cardPadding * 2
                height: row.implicitHeight + menu.cardPadding * 2
                radius: Theme.barRadius + 6
                color: Theme.barBackground
                border.width: 6
                border.color: Theme.surface1

                RowLayout {
                    id: row
                    anchors.centerIn: parent
                    spacing: menu.buttonSpacing

                    Repeater {
                        model: menu.items

                        Rectangle {
                            id: button
                            required property var modelData

                            implicitWidth: menu.buttonWidth
                            implicitHeight: menu.buttonHeight
                            radius: Theme.barRadius
                            color: hover.hovered ? Theme.surface1 : Theme.surface0
                            border.width: 1
                            border.color: hover.hovered ? Theme.accent : "transparent"

                            Column {
                                anchors.centerIn: parent
                                spacing: menu.iconLabelSpacing

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: button.modelData.icon
                                    color: hover.hovered ? Theme.accent : Theme.foreground
                                    font.family: Theme.fontFamily
                                    font.pixelSize: menu.iconSize
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: button.modelData.label
                                    color: Theme.foreground
                                    font.family: Theme.fontFamily
                                    font.pixelSize: menu.labelSize
                                }
                            }

                            HoverHandler {
                                id: hover
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: button.modelData.action()
                            }
                        }
                    }
                }
            }
        }
    }
}
