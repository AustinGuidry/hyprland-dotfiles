// Desktop shell: top bar, Super+D dashboard, Super+K keybind cheatsheet.
// Replaces waybar + the eww dashboard/cheatsheet. Run with `qs -c desktop`.

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.bar
import qs.cheatsheet
import qs.dashboard

ShellRoot {
    Variants {
        id: bars
        model: Quickshell.screens

        Bar {}
    }

    Dashboard {
        barWindows: bars.instances
    }

    Cheatsheet {}

    // Bound in keybinds.lua as hl.dsp.global("quickshell:<name>").
    GlobalShortcut {
        name: "dashboard"
        description: "Toggle the dashboard"
        onPressed: Overlays.dashboardOpen = !Overlays.dashboardOpen
    }

    GlobalShortcut {
        name: "cheatsheet"
        description: "Toggle the keybind cheatsheet"
        onPressed: Overlays.cheatsheetOpen = !Overlays.cheatsheetOpen
    }

    // For scripts: qs -c desktop ipc call dashboard toggle
    IpcHandler {
        target: "dashboard"

        function toggle(): void { Overlays.dashboardOpen = !Overlays.dashboardOpen; }
        function open(): void { Overlays.dashboardOpen = true; }
        function close(): void { Overlays.dashboardOpen = false; }
    }

    IpcHandler {
        target: "cheatsheet"

        function toggle(): void { Overlays.cheatsheetOpen = !Overlays.cheatsheetOpen; }
        function open(): void { Overlays.cheatsheetOpen = true; }
        function close(): void { Overlays.cheatsheetOpen = false; }
    }
}
