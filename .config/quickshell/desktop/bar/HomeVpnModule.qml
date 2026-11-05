import QtQuick
import qs
import qs.components
import qs.services

// A house beside the Surfshark shield: the WireGuard tunnel home. An outline
// while it's off, filled in the accent color while it's up and the Pi
// answers, filled in red if it's up but the Pi doesn't. Click to switch it.
// Dimmed and inert on the home Wi-Fi, where it isn't needed.
Pill {
    id: mod

    readonly property bool idleAtHome: HomeVpn.atHome && !HomeVpn.up && !HomeVpn.busy
    readonly property bool trouble: HomeVpn.up && HomeVpn.reachable === false

    text: HomeVpn.busy ? Icons.homeBusy : HomeVpn.up ? Icons.homeOn : Icons.homeOff
    fontSize: 22
    hpad: 10
    fg: HomeVpn.error || trouble ? Theme.criticalText
        : HomeVpn.up && !HomeVpn.busy ? Theme.primary
        : idleAtHome ? Qt.alpha(Theme.text, 0.4)
        : Theme.text
    clickable: !idleAtHome
    onClicked: HomeVpn.toggle()

    SequentialAnimation on opacity {
        running: HomeVpn.busy
        loops: Animation.Infinite
        alwaysRunToEnd: true

        NumberAnimation { to: 0.35; duration: 500 }
        NumberAnimation { to: 1; duration: 500 }
    }

    Tooltip {
        anchorItem: mod
        hovered: mod.hovered

        Text {
            text: "Home VPN"
            color: Theme.primary
            font.family: Theme.font
            font.pixelSize: Theme.fontSize - 1
            font.bold: true
        }

        Text {
            text: HomeVpn.error ? HomeVpn.error
                : HomeVpn.nmState === "activating" ? "Connecting…"
                : HomeVpn.nmState === "deactivating" ? "Disconnecting…"
                : HomeVpn.up && HomeVpn.reachable === true ? `Connected: the Pi answers at ${HomeVpn.piAddress}`
                : HomeVpn.up && HomeVpn.reachable === false ? "Up, but the Pi isn't answering.\nCheck the router's UDP 51820 forward."
                : HomeVpn.up ? "Connected, checking the Pi…"
                : idleAtHome ? "You're on the home network, so it isn't needed."
                : "Off"
            color: HomeVpn.error || mod.trouble ? Theme.criticalText : Theme.text
            font.family: Theme.font
            font.pixelSize: Theme.fontSize - 2
        }

        Text {
            visible: !mod.idleAtHome
            text: HomeVpn.up || HomeVpn.nmState === "activating" ? "Click to disconnect" : "Click to connect"
            color: Theme.secondary
            font.family: Theme.font
            font.pixelSize: Theme.fontSize - 2
        }
    }
}
