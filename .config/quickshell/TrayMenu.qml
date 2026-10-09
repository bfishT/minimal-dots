import Quickshell
import Quickshell.Hyprland
import QtQuick

// Themed tray context menu, anchored to the tray icon. Uses an embedded
// QsMenuOpener instead of the platform menu, so it is fully stylable.
PopupWindow {
    id: root

    property var menuHandle: null
    property Item targetItem: null
    // The window the anchored item lives in (the bar), passed by Tray.qml.
    property var anchorWindow: null

    anchor.window: root.anchorWindow
    anchor.item: root.targetItem
    // Drop the menu just below the icon, growing down/right.
    anchor.edges: Edges.Bottom | Edges.Right
    anchor.gravity: Edges.Bottom | Edges.Right
    anchor.margins.top: 4

    grabFocus: true
    implicitWidth: card.width
    implicitHeight: card.height
    color: "transparent"

    // Close on any interaction outside the popup (reliable on Hyprland, where
    // a Qt popup grab alone is not enough).
    HyprlandFocusGrab {
        active: root.visible
        windows: [QsWindow.window]
        onCleared: root.visible = false
    }

    Rectangle {
        id: card

        width: 220
        height: column.implicitHeight + 12
        radius: 12
        color: Theme.surface0
        border.width: 1
        border.color: Theme.surface1

        focus: true
        Keys.onEscapePressed: root.visible = false

        TrayMenuList {
            id: column

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 6
            handle: root.menuHandle
            onTriggered: root.visible = false
        }
    }
}
