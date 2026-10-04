pragma Singleton

import QtQuick
import Quickshell

// Which full-size overlay is open. At most one at a time: each takes the
// keyboard and a Hyprland focus grab, and two grabs would fight over
// click-outside-to-close.
Singleton {
    property bool dashboardOpen: false
    property bool cheatsheetOpen: false

    onDashboardOpenChanged: if (dashboardOpen) cheatsheetOpen = false
    onCheatsheetOpenChanged: if (cheatsheetOpen) dashboardOpen = false
}
