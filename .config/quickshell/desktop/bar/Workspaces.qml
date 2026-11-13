pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs
import qs.components

// Workspace buttons for one monitor. Click to switch, scroll to cycle, drop a
// SUPER-dragged window on one to send the window there.
RowLayout {
    id: root

    required property string monitorName

    // Every regular workspace, across monitors, in order. A workspace is
    // labelled by its place in this list rather than its Hyprland id: ids are
    // sticky, so with 1-6 closed the one left would still read "7". SUPER+<n>
    // counts the same way (nth_workspace in hypr/config/keybinds.lua).
    readonly property var ordered: Hyprland.workspaces.values
        .filter(w => w.id > 0)
        .sort((a, b) => a.id - b.id)

    spacing: 4

    // hypr/config/keybinds.lua reports a drag that ends on the bar as
    // `custom>>bardrop,<monitor>,<x>,<y>,<window>`, x and y in bar coordinates.
    // The window stays put unless it landed on a number.
    Connections {
        target: Hyprland

        function onRawEvent(event: HyprlandEvent): void {
            if (event.name !== "custom")
                return;
            const [tag, monitor, x, y, window] = event.data.split(",");
            if (tag !== "bardrop" || monitor !== root.monitorName)
                return;
            for (let i = 0; i < buttons.count; i++) {
                const pill = buttons.itemAt(i);
                if (pill.contains(pill.mapFromItem(null, Number(x), Number(y)))) {
                    Hyprland.dispatch(`hl.dsp.window.move({ workspace = ${pill.modelData.id}, follow = false, window = "${window}" })`);
                    return;
                }
            }
        }
    }

    Repeater {
        id: buttons

        model: ScriptModel {
            values: root.ordered.filter(w => !w.monitor || w.monitor.name === root.monitorName)
        }

        delegate: Pill {
            required property HyprlandWorkspace modelData
            readonly property bool current: modelData.active

            text: root.ordered.indexOf(modelData) + 1
            clickable: true
            // The waybar CSS styled `.focused`, a class hyprland/workspaces never
            // sets, so the current workspace was never actually highlighted.
            // Here it gets the look that stylesheet meant to give it.
            underline: hovered || current
            border.width: current ? 1 : 0
            border.color: Theme.primary
            bg: modelData.urgent ? Theme.urgent
                : current ? Qt.alpha(Theme.primary, 0.4)
                : Qt.alpha(Theme.primaryContrast, 0.3)
            hoverBg: current || modelData.urgent ? bg : Qt.alpha(Theme.primary, 0.2)
            onClicked: modelData.activate()
            onScrolled: steps => Hyprland.dispatch(`hl.dsp.focus({ workspace = "e${steps > 0 ? "-" : "+"}1" })`)
        }
    }
}
