import Quickshell
import Quickshell.Io
import QtQuick

pragma Singleton

// Shared screen-backlight state. Watches sysfs so the OSD (and anything else)
// reflects brightness no matter who changed it (keys, wheel, brightnessctl).
Singleton {
    id: root

    readonly property string device: {
        const env = Quickshell.env ? Quickshell.env("QS_BACKLIGHT_DEVICE") : "";
        return env && env.length > 0 ? env : "nvidia_0";
    }
    readonly property string basePath: "/sys/class/backlight/" + root.device

    property int percent: 0
    property int step: 5

    FileView {
        id: brightnessFile
        path: root.basePath + "/brightness"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.recalc()
    }

    FileView {
        id: maxFile
        path: root.basePath + "/max_brightness"
        watchChanges: false
        onLoaded: root.recalc()
    }

    function recalc() {
        const cur = Number(brightnessFile.text());
        const max = Number(maxFile.text());
        if (max > 0)
            root.percent = Math.round(cur * 100 / max);
    }

    function setPercent(p) {
        const v = Math.max(0, Math.min(100, Math.round(p)));
        Quickshell.execDetached(["brightnessctl", "-c", "backlight", "set", v + "%"]);
    }

    function increase() {
        root.setPercent(root.percent + root.step);
    }

    function decrease() {
        root.setPercent(root.percent - root.step);
    }
}
