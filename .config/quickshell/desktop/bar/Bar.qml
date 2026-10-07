import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs
import qs.components
import qs.services

// The top bar -- a module-for-module remake of the old waybar config.
PanelWindow {
    id: bar

    required property ShellScreen modelData

    screen: modelData
    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: Theme.barHeight
    color: Theme.surface
    WlrLayershell.namespace: "quickshell-bar"

    // waybar: border-bottom: 1px solid alpha(@primary, 0.3)
    Rectangle {
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        height: 1
        color: Qt.alpha(Theme.primary, 0.3)
    }

    // ── Left: launcher, dashboard, VPN, workspaces ────────────────────────
    RowLayout {
        id: left
        anchors {
            left: parent.left
            leftMargin: 2
            verticalCenter: parent.verticalCenter
        }
        spacing: 10

        Pill {
            text: Icons.launcher + " "
            fontSize: 16
            hpad: 10
            bg: Qt.alpha(Theme.primaryContrast, 0.3)
            hoverBg: Qt.alpha(Theme.primary, 0.3)
            clickable: true
            onClicked: Quickshell.execDetached(["nwg-menu", "-ha", "left", "-va", "top", "-mt", "44",
                "-wm", "hyprland", "-term", "kitty", "-fm", "nautilus", "-t", "-d"])
        }

        Pill {
            text: Icons.dashboard
            fontSize: 17
            hpad: 10
            fg: Overlays.dashboardOpen ? Theme.primary : Theme.text
            clickable: true
            onClicked: Overlays.dashboardOpen = !Overlays.dashboardOpen
        }

        VpnModule {}

        Workspaces {
            monitorName: bar.screen?.name ?? ""
        }
    }

    // ── Center: focused window title ──────────────────────────────────────
    Text {
        readonly property var window: Hyprland.activeToplevel
        // Room on both sides so a long title never runs under the modules.
        readonly property real room: 2 * Math.min(bar.width / 2 - left.x - left.width,
            right.x - bar.width / 2) - 24

        anchors.centerIn: parent
        width: Math.min(implicitWidth, Math.max(0, room))
        text: window && window.workspace === Hyprland.focusedWorkspace ? window.title : ""
        elide: Text.ElideRight
        color: Theme.text
        font.family: Theme.font
        font.pixelSize: Theme.fontSize
    }

    // ── Right: status modules ─────────────────────────────────────────────
    RowLayout {
        id: right
        anchors {
            right: parent.right
            rightMargin: 3
            verticalCenter: parent.verticalCenter
        }
        spacing: 10

        NetworkModule {}

        BluetoothModule {}

        Pill {
            text: `${SystemStats.cpu}% ${Icons.cpu}`
        }

        Pill {
            id: memory
            text: `${SystemStats.memory}% ${Icons.memory}`

            Tooltip {
                anchorItem: memory
                hovered: memory.hovered

                Text {
                    text: `${SystemStats.memUsedGiB.toFixed(1)} / ${SystemStats.memTotalGiB.toFixed(1)} GiB used`
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize - 1
                }
            }
        }

        Pill {
            readonly property bool hot: SystemStats.temperature >= 80
            text: `${SystemStats.temperature}°C ${Icons.thermometer}`
            fontSize: 14
            bg: hot ? Theme.critical : "transparent"
            fg: hot ? Theme.criticalText : Theme.text
        }

        Pill {
            visible: Brightness.available
            text: `${Brightness.percent}% ${Icons.sun}`
            onScrolled: steps => Brightness.step(5 * steps)
        }

        BatteryModule {}

        ClockModule {}

        PowerModule {
            Layout.leftMargin: 3
        }
    }
}
