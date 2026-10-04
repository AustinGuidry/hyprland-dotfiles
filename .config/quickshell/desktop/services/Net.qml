pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking

// NetworkManager state via Quickshell.Networking, plus the public IP.
// (Not named Network: Quickshell.Networking exports a type by that name.)
Singleton {
    id: root

    readonly property var wifi: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wired: Networking.devices.values.find(d => d.type === DeviceType.Wired && d.connected) ?? null
    readonly property var active: wifi?.networks.values.find(n => n.connected) ?? null

    readonly property string ssid: active?.name ?? ""
    readonly property int signal: active ? Math.round(active.signalStrength * 100) : 0
    readonly property bool online: active !== null || wired !== null

    // Strongest first, the connected network always on top.
    readonly property var networks: (wifi?.networks.values ?? [])
        .filter(n => n.name)
        .sort((a, b) => (b.connected - a.connected) || (b.signalStrength - a.signalStrength))

    property string publicIp: "…"


    function refreshPublicIp() {
        if (!ipProc.running)
            ipProc.running = true;
    }

    Process {
        id: ipProc
        command: ["curl", "-s", "--max-time", "5", "-4", "ifconfig.me"]
        stdout: StdioCollector {
            onStreamFinished: root.publicIp = text.trim() || "No connection"
        }
    }
}
