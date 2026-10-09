import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick

pragma Singleton

// Power profiles on this laptop are controlled by the EC hotkey (Fn+K), which
// cycles 静谧/均衡/极速. This singleton gives that a UI feedback channel: it
// watches the EC profile (read-only) and pops a notification whenever it
// changes, so Fn+K is no longer silent.
//
// It also still exposes the ppd toggle (power-saver <-> performance) via the
// Hyprland global shortcut "quickshell:powerprofile" / `qs ipc call powerprofile
// toggle`. Note: on this machine the driver rejects `performance`, so that
// direction falls back with a notification (see ~/.scripts/power-profile.sh).
//
// Triggered by the Hyprland global shortcut "quickshell:powerprofile":
//     hl.bind("ALT + SHIFT + P", hl.dsp.global("quickshell:powerprofile"))
// Or from a terminal:
//     qs ipc call powerprofile toggle
Singleton {
    id: root

    readonly property string script: Quickshell.env("HOME") + "/.scripts/power-profile.sh"

    function toggle() {
        Quickshell.execDetached([root.script]);
    }

    function set(name) {
        Quickshell.execDetached([root.script, name]);
    }

    // ---- EC 档位只读监听（给 Fn+K 一个反馈）----
    readonly property string ecPath: "/sys/class/platform-profile/platform-profile-0/profile"

    // 原始 EC 值：low-power / balanced-performance / performance ...
    property string ecProfile: ""

    // 上一次已公告的值，用来抑制首次加载时的通知
    property string announced: ""

    function friendly(name) {
        if (name === "low-power")
            return "静谧";
        if (name === "balanced" || name === "balanced-performance")
            return "均衡";
        if (name === "performance")
            return "极速";
        return name.length > 0 ? name : "未知";
    }

    function announce(name) {
        name = name.trim();
        if (name.length === 0)
            return;
        root.ecProfile = name;
        if (root.announced === "") {
            root.announced = name;   // 首次读取，不弹
            return;
        }
        if (name === root.announced)
            return;
        root.announced = name;
        Quickshell.execDetached(["notify-send", "-a", "电源模式", "-u", "low",
            "电源模式", "当前: " + root.friendly(name)]);
    }

    FileView {
        id: ecFile
        path: root.ecPath
        onTextChanged: root.announce(ecFile.text().trim())
    }

    // sysfs 属性不一定发 inotify，轮询兜底
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: ecFile.reload()
    }

    GlobalShortcut {
        appid: "quickshell"
        name: "powerprofile"
        description: "Toggle power profile"
        onPressed: root.toggle()
    }

    IpcHandler {
        target: "powerprofile"

        function toggle(): void { root.toggle(); }
        function performance(): void { root.set("performance"); }
        function saver(): void { root.set("power-saver"); }
        function ec(): string { return root.friendly(root.ecProfile); }
    }
}
