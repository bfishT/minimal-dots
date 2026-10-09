import Quickshell
import QtQuick
import QtQuick.Layouts

// One level of a DBusMenu, rendered with the bar's theme. Recurses into
// itself (via the Loader below) to expand submenus inline.
Column {
    id: root

    property var handle: null

    signal triggered()

    spacing: 0

    QsMenuOpener {
        id: opener
        menu: root.handle
    }

    Repeater {
        model: opener.children

        Column {
            id: entry
            required property QsMenuEntry modelData

            readonly property bool isSep: modelData.isSeparator
            readonly property bool hasChildren: modelData.hasChildren
            property bool expanded: false

            width: root.width

            // ---- separator ----
            Item {
                width: parent.width
                implicitHeight: 9
                visible: entry.isSep

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 4
                    anchors.rightMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    height: 1
                    color: Theme.surface1
                }
            }

            // ---- normal entry ----
            Item {
                id: rowItem
                width: parent.width
                implicitHeight: 30
                visible: !entry.isSep

                Rectangle {
                    id: bg
                    anchors.fill: parent
                    radius: 8
                    color: hover.containsMouse ? Theme.activeBg : "transparent"
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 8

                    // Check / radio indicator
                    Text {
                        Layout.preferredWidth: visible ? 14 : 0
                        Layout.alignment: Qt.AlignVCenter
                        visible: text.length > 0
                        text: {
                            if (entry.modelData.buttonType === QsMenuButtonType.RadioButton)
                                return entry.modelData.checkState === Qt.Checked ? "\u25cf" : "";
                            if (entry.modelData.buttonType === QsMenuButtonType.CheckBox)
                                return entry.modelData.checkState === Qt.Checked ? "\u2713" : "";
                            return "";
                        }
                        color: hover.containsMouse ? Theme.activeFg : Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }

                    Image {
                        Layout.preferredWidth: 16
                        Layout.preferredHeight: 16
                        Layout.alignment: Qt.AlignVCenter
                        visible: entry.modelData.icon !== "" && status === Image.Ready
                        source: entry.modelData.icon
                        sourceSize.width: 16
                        sourceSize.height: 16
                    }

                    Text {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        text: entry.modelData.text
                        color: !entry.modelData.enabled ? Theme.subtext
                            : hover.containsMouse ? Theme.activeFg
                            : Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.alignment: Qt.AlignVCenter
                        visible: entry.hasChildren
                        text: entry.expanded ? "\u25be" : "\u25b8"
                        color: Theme.subtext
                        font.pixelSize: 11
                    }
                }

                MouseArea {
                    id: hover
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton
                    onClicked: {
                        if (!entry.modelData.enabled)
                            return;
                        if (entry.hasChildren) {
                            entry.expanded = !entry.expanded;
                        } else {
                            entry.modelData.triggered();
                            root.triggered();
                        }
                    }
                }
            }

            // ---- inline submenu ----
            Loader {
                width: parent.width
                active: entry.expanded
                visible: active
                // Loading by URL avoids QML's compile-time self-recursion check.
                source: active ? "TrayMenuList.qml" : ""
                onLoaded: {
                    item.handle = entry.modelData;
                    item.triggered.connect(root.triggered);
                }
            }
        }
    }
}
