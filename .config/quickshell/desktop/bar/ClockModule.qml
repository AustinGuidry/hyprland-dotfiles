import QtQuick
import Quickshell
import qs
import qs.components

// "05:23 PM"; click for the date, hover for a calendar -- as waybar did.
Pill {
    id: mod

    property bool showDate: false

    text: Qt.formatDateTime(clock.date, showDate ? "yyyy-MM-dd" : "hh:mm AP")
    bg: Qt.alpha(Theme.primaryContrast, 0.3)
    clickable: true
    onClicked: showDate = !showDate

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Tooltip {
        anchorItem: mod
        hovered: mod.hovered

        Calendar {
            today: clock.date
        }
    }
}
