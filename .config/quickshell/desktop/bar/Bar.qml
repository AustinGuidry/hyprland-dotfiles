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
            fontSize: 15
            hpad: 10
            bg: Qt.alpha(Theme.primaryContrast, 0.3)
            hoverBg: Qt.alpha(Theme.primary, 0.3)
            clickable: true
            onClicked: Quickshell.execDetached(["nwg-menu", "-ha", "left", "-va", "top", "-mt", "44",
                "-wm", "hyprland", "-term", "kitty", "-fm", "pcmanfm-qt", "-t", "-d"])
        }

        Pill {
            text: Icons.dashboard
            fontSize: 16
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
        // The gap between the two rows of modules, less some air.
        readonly property real from: left.x + left.width + 12
        readonly property real to: right.x - 12

        anchors.verticalCenter: parent.verticalCenter
        // Mid-bar while it fits there. A title too long for that slides toward
        // the side with room instead of being cut short -- on a narrow screen
        // the right-hand row reaches nearly to the middle -- and only one
        // longer than the whole gap is elided, so it never runs under the modules.
        x: Math.max(from, Math.min((bar.width - width) / 2, to - width))
        // Never 0: a Text that wide draws its whole string instead of eliding.
        width: Math.min(implicitWidth, Math.max(1, to - from))
        visible: to - from >= 40
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
            fontSize: 13
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
