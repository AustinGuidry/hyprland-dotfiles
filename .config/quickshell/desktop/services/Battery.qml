pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Pack voltage and current, read from sysfs (polled -- sysfs doesn't notify).
// UPower's percentage is the gauge chip's estimate, and on a worn pack it reads
// high; voltage is what decides when the machine actually cuts out.
Singleton {
    id: root

    property string dir: ""
    property real volts: 0
    property real amps: 0
    readonly property real watts: volts * amps
    readonly property bool available: dir !== ""

    // Averaged over about half a minute, so a burst of load doesn't count.
    property real avgVolts: 0
    property int cells: 0
    // 3.5 V per cell under load, about where lithium cells start falling off
    // fast. Provisional: once the pack has been run flat, set this from the
    // last rows before the death in the log ~/scripts/battery-log.sh keeps.
    readonly property real lowVolts: 3.5 * cells
    readonly property bool low: cells > 0 && avgVolts > 0 && avgVolts < lowVolts

    Process {
        running: true
        command: ["sh", "-c", "grep -lx Battery /sys/class/power_supply/*/type | head -n1"]
        stdout: StdioCollector {
            onStreamFinished: root.dir = text.trim().replace(/\/type$/, "")
        }
    }

    Timer {
        interval: 5000
        running: root.available
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            voltage.reload();
            current.reload();
        }
    }

    FileView {
        id: voltage
        path: root.available ? `${root.dir}/voltage_now` : ""
        onLoaded: {
            root.volts = parseInt(text()) / 1e6;
            root.avgVolts = root.avgVolts > 0 ? 0.8 * root.avgVolts + 0.2 * root.volts : root.volts;
        }
    }

    // Batteries that report power_now instead simply show no wattage.
    FileView {
        id: current
        path: root.available ? `${root.dir}/current_now` : ""
        printErrors: false
        onLoaded: root.amps = Math.abs(parseInt(text())) / 1e6
    }

    // The design voltage is the pack's nominal one, 3.6-3.85 V per cell.
    FileView {
        path: root.available ? `${root.dir}/voltage_min_design` : ""
        printErrors: false
        onLoaded: root.cells = Math.round(parseInt(text()) / 3.7e6)
    }
}
