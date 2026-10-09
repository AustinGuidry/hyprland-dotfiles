import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs
import qs.components

// ⏻ with the same five entries as waybar's power_menu.xml.
Pill {
    id: mod

    function run(command) {
        menu.close();
        Quickshell.execDetached(command);
    }

    text: Icons.power + " "
    fontSize: 15
    radius: 8
    bg: Qt.alpha(Theme.primaryContrast, 0.3)
    clickable: true
    onClicked: menu.toggle()

    Popout {
        id: menu

        anchorItem: mod

        // waybar ran a bare `shutdown`, which schedules a poweroff a minute
        // out rather than doing it now.
        MenuItem {
            text: "⏻  Shutdown"
            onActivated: mod.run(["loginctl", "poweroff"])
        }
        MenuItem {
            text: "↺  Reboot"
            onActivated: mod.run(["loginctl", "reboot"])
        }
        MenuItem {
            text: "⏾  Suspend"
            onActivated: mod.run(["loginctl", "suspend"])
        }
        MenuItem {
            text: Icons.glyph(0xF04B2) + "  Hibernate"
            onActivated: mod.run(["loginctl", "hibernate"])
        }
        MenuItem {
            text: "⇠  Log Out"
            onActivated: {
                menu.close();
                Hyprland.dispatch("hl.dsp.exit()");
            }
        }
    }
}
