import QtQuick

Item {
    id: root
    // waybar clock: format "{:%H:%M}", format-alt "\uf073 {:%a,%b %d}", locale C
    property string format: "HH:mm"
    property string altFormat: "ddd, MMM d"

    implicitWidth: label.implicitWidth
    implicitHeight: 22

    property bool showAlt: false

    Timer {
        id: tick
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    property date now: new Date()

    Text {
        id: label
        anchors.verticalCenter: parent.verticalCenter
        text: {
            if (root.showAlt)
                return Theme.iconCalendar + " " + Qt.formatDate(root.now, root.altFormat).replace(",", ",");
            return Qt.formatTime(root.now, root.format);
        }
        color: Theme.foreground
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.showAlt = !root.showAlt
    }
}
