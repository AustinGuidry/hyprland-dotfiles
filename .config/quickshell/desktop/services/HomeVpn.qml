pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The WireGuard tunnel home (PiVPN on the Pi), for the bar's house
// (bar/HomeVpnModule.qml). It is the NetworkManager connection "gentoo-mac",
// a split tunnel: only 192.168.0.0/24 and the VPN's own 10.43.89.0/24 go
// through it. Brought up or down from a terminal, the house follows too.
Singleton {
    id: root

    readonly property string connection: "gentoo-mac"
    readonly property string piAddress: "10.43.89.1"
    // On this network the tunnel isn't needed, and its 192.168.0.0/24 route
    // would fight the LAN's own.
    readonly property string homeSsid: "Not_The_FBI"

    // NetworkManager's GENERAL.STATE: "", "activating", "activated", "deactivating".
    property string nmState: ""
    readonly property bool up: nmState === "activated"
    readonly property bool busy: nmState === "activating" || nmState === "deactivating" || toggleProc.running
    // WireGuard is "activated" as soon as the interface exists, whether or not
    // the Pi is out there, so the Pi is pinged through the tunnel to find out.
    // null until the first answer.
    property var reachable: null
    readonly property bool atHome: Net.ssid === homeSsid
    property string error: ""

    function toggle() {
        if (toggleProc.running || (atHome && !up))
            return;
        error = "";
        toggleProc.command = ["nmcli", "connection", up || nmState === "activating" ? "down" : "up", connection];
        toggleProc.running = true;
    }

    function refresh() {
        if (!stateProc.running)
            stateProc.running = true;
    }

    onUpChanged: {
        reachable = null;
        if (up)
            firstPing.restart();
    }

    Component.onCompleted: refresh()

    // Any NetworkManager change prints a line here; settle, then re-read the state.
    Process {
        id: monitor
        running: true
        command: ["nmcli", "monitor"]
        stdout: SplitParser {
            onRead: settle.restart()
        }
        onRunningChanged: if (!running) restartMonitor.start()
    }

    Timer {
        id: restartMonitor
        interval: 5000
        onTriggered: monitor.running = true
    }

    Timer {
        id: settle
        interval: 300
        onTriggered: root.refresh()
    }

    Process {
        id: stateProc
        command: ["nmcli", "-t", "-g", "GENERAL.STATE", "connection", "show", root.connection]
        stdout: StdioCollector {
            onStreamFinished: root.nmState = text.trim()
        }
    }

    Process {
        id: toggleProc
        stderr: StdioCollector {
            id: toggleErr
        }
        onExited: code => {
            if (code !== 0)
                root.error = toggleErr.text.trim().replace(/^Error: /, "") || `nmcli exited with ${code}`;
            root.refresh();
        }
    }

    // ── Is the Pi answering? ──────────────────────────────────────────────
    Timer {
        id: firstPing
        interval: 1000
        onTriggered: ping.running = true
    }

    Timer {
        interval: 20000
        running: root.up
        repeat: true
        onTriggered: if (!ping.running) ping.running = true
    }

    Process {
        id: ping
        command: ["ping", "-c", "1", "-W", "3", root.piAddress]
        onExited: code => {
            if (root.up)
                root.reachable = code === 0;
        }
    }
}
