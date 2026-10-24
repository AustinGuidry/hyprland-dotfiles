pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.services

// macOS-style HUD for volume, screen brightness and keyboard backlight: a
// rounded square near the bottom of the screen with an icon and a 16-step
// bar, fading out shortly after the last change. Click-through, and never
// takes focus.
//
// Volume comes straight from PipeWire, so any change shows it (the keys,
// wpctl, another app). sysfs can't be watched for backlight changes, so the
// brightness keys call in once brightnessctl is done:
//   qs -c desktop ipc call osd screen|keyboard
PanelWindow {
    id: win

    // Startup and sink switches report a "change" from 0 to the real volume,
    // so only react once the sink has been around for a moment.
    property bool armed: false
    property bool shown: false
    property string kind: "volume"    // volume | screen | keyboard
    property real screenLevel: 0
    property real keyboardLevel: 0
    property int keyboardMax: 1
    // Set by the IPC calls, so only those reloads (not the first load at
    // startup) pop the HUD.
    property bool screenAsked: false
    property bool keyboardAsked: false

    readonly property real level: kind === "screen" ? screenLevel
        : kind === "keyboard" ? keyboardLevel
        : Audio.volume
    readonly property bool dimmed: kind === "volume" && Audio.muted
    readonly property string icon: {
        if (kind === "screen")
            return Icons.brightness;
        if (kind === "keyboard")
            return keyboardLevel > 0 ? Icons.keyboard : Icons.keyboardOff;
        if (Audio.muted)
            return Icons.volumeMuted;
        return Icons.speaker[Audio.volume < 0.005 ? 0 : Audio.volume <= 0.5 ? 1 : 2];
    }

    function flash(what) {
        // The dashboard has its own sliders; don't stack a HUD on them.
        if (Overlays.dashboardOpen)
            return;
        kind = what;
        shown = true;
        hideTimer.restart();
    }

    visible: shown || card.opacity > 0
    anchors.bottom: true
    margins.bottom: 140
    implicitWidth: 190
    implicitHeight: 190
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    mask: Region {}
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-osd"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Timer {
        running: Audio.ready && !win.armed
        interval: 1500
        onTriggered: win.armed = true
    }

    Timer {
        id: hideTimer

        interval: 1500
        onTriggered: win.shown = false
    }

    Connections {
        target: Audio

        function onVolumeChanged() { if (win.armed) win.flash("volume"); }
        function onMutedChanged() { if (win.armed) win.flash("volume"); }
    }

    IpcHandler {
        target: "osd"

        function screen(): void {
            win.screenAsked = true;
            screenFile.reload();
        }
        function keyboard(): void {
            win.keyboardAsked = true;
            keyboardFile.reload();
        }
    }

    // The screen keys step along brightnessctl's -e4 curve, so the bar uses
    // that curve too: every press then moves it by the same amount.
    FileView {
        id: screenFile

        path: Brightness.available ? `/sys/class/backlight/${Brightness.device}/brightness` : ""
        onLoaded: {
            win.screenLevel = Math.pow(parseInt(text()) / Brightness.max, 0.25);
            if (win.screenAsked) {
                win.screenAsked = false;
                win.flash("screen");
            }
        }
    }

    FileView {
        id: keyboardFile

        path: "/sys/class/leds/smc::kbd_backlight/brightness"
        onLoaded: {
            win.keyboardLevel = parseInt(text()) / win.keyboardMax;
            if (win.keyboardAsked) {
                win.keyboardAsked = false;
                win.flash("keyboard");
            }
        }
    }

    FileView {
        path: "/sys/class/leds/smc::kbd_backlight/max_brightness"
        onLoaded: win.keyboardMax = Math.max(1, parseInt(text()))
    }

    Rectangle {
        id: card

        anchors.fill: parent
        radius: 22
        color: Qt.alpha(Theme.surface, 0.96)
        border.width: 1
        border.color: Qt.alpha(Theme.text, 0.08)
        opacity: 0
        scale: 0.92

        // Pops in quickly with a little overshoot, fades out slowly.
        states: State {
            name: "shown"
            when: win.shown

            PropertyChanges {
                card.opacity: 1
                card.scale: 1
            }
        }
        transitions: [
            Transition {
                to: "shown"

                NumberAnimation { property: "opacity"; duration: 120 }
                NumberAnimation { property: "scale"; duration: 220; easing.type: Easing.OutBack }
            },
            Transition {
                from: "shown"

                NumberAnimation { properties: "opacity,scale"; duration: 400; easing.type: Easing.InCubic }
            }
        ]

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 18

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: win.icon
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: 84
            }

            // Each step fills partially, so the 5% key steps land between
            // notches instead of rounding to them.
            Row {
                Layout.alignment: Qt.AlignHCenter
                spacing: 2
                opacity: win.dimmed ? 0.35 : 1

                Repeater {
                    model: 16

                    Rectangle {
                        required property int index

                        width: 7
                        height: 8
                        radius: 1
                        color: Qt.alpha(Theme.text, 0.2)

                        Rectangle {
                            width: parent.width * Math.max(0, Math.min(1, win.level * 16 - parent.index))
                            height: parent.height
                            radius: 1
                            color: Theme.text

                            Behavior on width {
                                NumberAnimation { duration: 90 }
                            }
                        }
                    }
                }
            }
        }
    }
}
