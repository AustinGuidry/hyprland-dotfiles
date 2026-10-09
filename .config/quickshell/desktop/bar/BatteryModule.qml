import QtQuick
import Quickshell
import Quickshell.Services.UPower
import qs
import qs.components
import qs.services

// "51% 󰁿" -- click to show time remaining instead (waybar's format-alt).
// Goes critical on low pack voltage as well as low percentage: the percentage
// can still read high when a worn pack is about to give out.
Pill {
    id: mod

    readonly property UPowerDevice dev: UPower.displayDevice
    readonly property int pct: Math.round(dev.percentage * 100)
    readonly property bool charging: dev.state === UPowerDeviceState.Charging
    readonly property bool plugged: !UPower.onBattery
    readonly property bool critical: (pct <= 15 || Battery.low) && !charging
    readonly property string icon: charging ? Icons.charging
        : plugged ? Icons.plugged
        : Icons.battery[Math.max(0, Math.min(9, Math.floor(pct / 10)))]
    readonly property double seconds: charging ? dev.timeToFull : dev.timeToEmpty
    readonly property string timeLeft: seconds > 0
        ? `${Math.floor(seconds / 3600)} h ${Math.floor(seconds % 3600 / 60)} min` : ""
    property bool showTime: false
    property real blink: 0

    visible: dev.isLaptopBattery
    text: showTime && timeLeft ? `${timeLeft} ${icon}` : `${pct}% ${icon}`
    clickable: true
    onClicked: showTime = !showTime

    // waybar's `blink` keyframes: alternate critical red <-> primary, 0.5s.
    bg: critical ? Qt.tint(Theme.critical, Qt.alpha(Theme.primary, blink))
        : charging || plugged ? Qt.alpha(Theme.secondary, 0.4)
        : Qt.alpha(Theme.primaryContrast, 0.3)
    fg: critical ? Qt.tint(Theme.criticalText, Qt.alpha(Theme.primaryContrast, blink)) : Theme.text

    SequentialAnimation on blink {
        running: mod.critical
        loops: Animation.Infinite
        NumberAnimation { to: 1; duration: 500 }
        NumberAnimation { to: 0; duration: 500 }
        onStopped: mod.blink = 0
    }

    Tooltip {
        anchorItem: mod
        hovered: mod.hovered

        Text {
            text: (mod.charging ? "Charging" : mod.plugged ? "Plugged in" : "On battery")
                + (mod.timeLeft ? ` · ${mod.timeLeft} ${mod.charging ? "to full" : "left"}` : "")
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: Theme.fontSize - 1
        }

        Text {
            visible: Battery.volts > 0
            text: `${Battery.volts.toFixed(2)} V`
                + (Battery.low && !mod.charging ? " (low)" : "")
                + (Battery.watts >= 0.05 ? ` · ${Battery.watts.toFixed(1)} W` : "")
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: Theme.fontSize - 1
        }
    }
}
