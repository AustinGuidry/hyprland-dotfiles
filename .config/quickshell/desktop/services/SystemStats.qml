pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// CPU, memory, temperature and disk, read straight from /proc and /sys.
Singleton {
    id: root

    property int cpu: 0              // % busy since the previous sample
    property int memory: 0           // % used (total - available)
    property real memUsedGiB: 0
    property real memTotalGiB: 0
    property int temperature: 0      // °C, CPU package
    property string diskFree: "…"    // as `df -h` prints it, e.g. "80G"
    property int diskFreePct: 0

    property var prevCpu: null
    property string tempPath: ""

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            stat.reload();
            meminfo.reload();
            if (root.tempPath)
                temp.reload();
        }
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: df.running = true
    }

    FileView {
        id: stat
        path: "/proc/stat"
        onLoaded: {
            const f = text().split("\n")[0].trim().split(/\s+/).slice(1).map(Number);
            const idle = f[3] + f[4];  // idle + iowait
            const total = f.reduce((a, b) => a + b, 0);
            if (root.prevCpu && total > root.prevCpu.total)
                root.cpu = Math.round(100 * (1 - (idle - root.prevCpu.idle) / (total - root.prevCpu.total)));
            root.prevCpu = { total, idle };
        }
    }

    FileView {
        id: meminfo
        path: "/proc/meminfo"
        onLoaded: {
            const kb = key => Number(text().match(new RegExp(`^${key}:\\s+(\\d+)`, "m"))?.[1] ?? 0);
            const total = kb("MemTotal");
            const used = total - kb("MemAvailable");
            if (total > 0) {
                root.memory = Math.round(100 * used / total);
                root.memUsedGiB = used / 1048576;
                root.memTotalGiB = total / 1048576;
            }
        }
    }

    FileView {
        id: temp
        path: root.tempPath
        onLoaded: root.temperature = Math.round(parseInt(text()) / 1000)
    }

    // Thermal zone numbering isn't stable across boots, so find the CPU
    // package sensor by type once at startup.
    Process {
        running: true
        command: ["sh", "-c", "for z in /sys/class/thermal/thermal_zone*; do "
            + "[ \"$(cat $z/type)\" = x86_pkg_temp ] && { echo $z/temp; exit; }; done; "
            + "echo /sys/class/thermal/thermal_zone0/temp"]
        stdout: StdioCollector {
            onStreamFinished: root.tempPath = text.trim()
        }
    }

    Process {
        id: df
        command: ["df", "-h", "--output=avail,pcent", "/"]
        stdout: StdioCollector {
            onStreamFinished: {
                const cols = text.trim().split("\n").pop().trim().split(/\s+/);
                root.diskFree = cols[0];
                root.diskFreePct = 100 - parseInt(cols[1]);
            }
        }
    }
}
