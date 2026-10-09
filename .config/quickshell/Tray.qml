import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import QtQuick

Item {
    id: root
    // waybar tray: icon-size 16, spacing 6
    readonly property int iconSize: 16
    readonly property int spacing: 8

    // Hide entirely when there are no tray items, otherwise the layout still
    // reserves the surrounding gaps and leaves a phantom hole in the bar.
    visible: SystemTray.items.values.length > 0

    implicitWidth: row.implicitWidth
    implicitHeight: root.iconSize

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.spacing

        Repeater {
            model: SystemTray.items

            Item {
                id: trayDelegate
                required property SystemTrayItem modelData
                width: root.iconSize
                height: root.iconSize

                IconImage {
                    anchors.fill: parent
                    source: trayDelegate.modelData.icon
                    asynchronous: true
                }

                TrayMenu {
                    id: contextMenu
                    menuHandle: trayDelegate.modelData.menu
                    targetItem: trayDelegate
                    // Resolved here, in the bar window's scope.
                    anchorWindow: QsWindow.window
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: (event) => {
                        if (event.button === Qt.RightButton || trayDelegate.modelData.onlyMenu) {
                            if (trayDelegate.modelData.hasMenu)
                                contextMenu.visible = !contextMenu.visible;
                            else
                                trayDelegate.modelData.secondaryActivate();
                        } else {
                            trayDelegate.modelData.activate();
                        }
                    }
                }
            }
        }
    }
}
