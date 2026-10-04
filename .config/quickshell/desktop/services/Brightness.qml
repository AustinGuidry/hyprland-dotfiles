pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Screen backlight. Read from sysfs (polled -- sysfs doesn't notify), written
// through brightnessctl, which handles the permissions.
Singleton {
    id: root

    property string device: ""
    property int raw: 0
    property int max: 1
    readonly property int percent: Math.round(100 * raw / max)
    readonly property bool available: device !== ""

    // Set while a slider drag or scroll is in flight, so a poll landing
    // mid-gesture doesn't yank the slider back to the old value.
    property double holdUntil: 0
    property int pending: -1

    function set(pct) {
        pct = Math.max(1, Math.min(100, Math.round(pct)));
        raw = Math.round(pct * max / 100);
        holdUntil = Date.now() + 1500;
        pending = pct;
        if (!setter.running)
            flush();
    }

    function step(delta) { set(percent + delta); }

    function flush() {
        if (pending < 0)
            return;
        setter.command = ["brightnessctl", "-q", "set", pending + "%"];
        pending = -1;
        setter.running = true;
    }

    Process {
        id: setter
        onExited: root.flush()
    }

    Process {
        running: true
        command: ["sh", "-c", "ls /sys/class/backlight | head -n1"]
        stdout: StdioCollector {
            onStreamFinished: root.device = text.trim()
        }
    }

    Timer {
        interval: 1000
        running: root.available
        repeat: true
        triggeredOnStart: true
        onTriggered: if (Date.now() > root.holdUntil) current.reload()
    }

    FileView {
        id: current
        path: root.available ? `/sys/class/backlight/${root.device}/brightness` : ""
        onLoaded: if (Date.now() > root.holdUntil) root.raw = parseInt(text())
    }

    FileView {
        path: root.available ? `/sys/class/backlight/${root.device}/max_brightness` : ""
        onLoaded: root.max = Math.max(1, parseInt(text()))
    }
}
