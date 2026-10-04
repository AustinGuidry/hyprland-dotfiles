import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Hyprland
import Quickshell.Wayland
import qs
import qs.components
import qs.services

// Super+D panel, top-left under the bar: a remake of the eww dashboard.
// Escape, Super+D, the bar button, or a click anywhere else closes it.
PanelWindow {
    id: win

    property var barWindows: []
    readonly property bool open: Overlays.dashboardOpen

    visible: open || card.opacity > 0
    anchors {
        top: true
        left: true
    }
    // Same spot as the eww window. exclusiveZone 0 keeps it below the bar.
    margins {
        top: 50
        left: 20
    }
    exclusiveZone: 0
    implicitWidth: card.width
    implicitHeight: card.height
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-dashboard"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onOpenChanged: {
        if (open) {
            Weather.refresh();
            Net.refreshPublicIp();
            card.forceActiveFocus();
        }
    }

    // The bars are part of the grab so their dashboard button can close the
    // panel, instead of the click first dismissing it and then reopening it.
    HyprlandFocusGrab {
        active: win.open
        windows: [win].concat(Array.from(win.barWindows))
        onCleared: Overlays.dashboardOpen = false
    }

    Timer {
        interval: 30000
        running: win.open
        repeat: true
        onTriggered: Net.refreshPublicIp()
    }

    SystemClock {
        id: clock
        enabled: win.visible
        precision: SystemClock.Seconds
    }

    Rectangle {
        id: card

        width: 300
        height: content.implicitHeight + 30
        color: Theme.surface
        border.width: 2
        border.color: Theme.primary
        radius: 16
        opacity: win.open ? 1 : 0
        focus: true
        Keys.onEscapePressed: Overlays.dashboardOpen = false

        Behavior on opacity { NumberAnimation { duration: 140 } }

        ColumnLayout {
            id: content

            anchors {
                fill: parent
                margins: 15
            }
            spacing: 10

            // Time and date
            ColumnLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 4

                Label {
                    Layout.alignment: Qt.AlignHCenter
                    text: Qt.formatDateTime(clock.date, "hh:mm AP")
                    color: Theme.primary
                    size: 42
                    bold: true
                }
                Label {
                    Layout.alignment: Qt.AlignHCenter
                    text: Qt.formatDateTime(clock.date, "dddd, MMMM dd")
                }
            }

            Label {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 8
                text: Weather.text
            }

            // Wi-Fi and Bluetooth
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Stat {
                    Layout.preferredWidth: 1
                    label: "WiFi"
                    value: Net.ssid || (Net.wired ? "Wired" : "Offline")
                }
                Stat {
                    Layout.preferredWidth: 1
                    label: "Bluetooth"
                    value: Bluetooth.defaultAdapter?.enabled ? "Enabled" : "Disabled"
                }
            }

            Stat {
                Layout.fillWidth: true
                Layout.topMargin: 6
                small: true
                label: "Public IP"
                value: Net.publicIp
            }

            Stat {
                Layout.fillWidth: true
                small: true
                label: "Disk Free"
                value: `${SystemStats.diskFree}  (${SystemStats.diskFreePct}%)`
            }

            // Brightness
            SliderRow {
                visible: Brightness.available
                lowIcon: Icons.bulb
                highIcon: Icons.sun
                from: 1
                value: Brightness.percent
                onMoved: v => Brightness.set(v)
            }

            // Volume
            SliderRow {
                lowIcon: Icons.volumeLow
                highIcon: Icons.volumeHigh
                value: Math.round(Audio.volume * 100)
                onMoved: v => Audio.setVolume(v / 100)
            }

            // App launchers
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 6
                spacing: 8

                AppButton {
                    icon: Icons.browser
                    command: ["brave-origin-beta"]
                }
                AppButton {
                    icon: Icons.terminal
                    command: ["kitty"]
                }
                AppButton {
                    icon: Icons.folder
                    command: ["nautilus"]
                }
                AppButton {
                    icon: Icons.code
                    command: ["code"]
                }
            }
        }
    }

    component Label: Text {
        property int size: 16
        property bool bold: false

        color: Theme.text
        font.family: Theme.font
        font.pixelSize: size
        font.bold: bold
    }

    // A caption over a bold value, centered.
    component Stat: ColumnLayout {
        id: stat

        property string label
        property string value
        property bool small: false

        Layout.fillWidth: true
        spacing: 2

        Label {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: stat.label
            size: stat.small ? 12 : 16
        }
        Label {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: stat.value
            elide: Text.ElideRight
            size: stat.small ? 14 : 16
            bold: true
            color: stat.small ? Theme.primary : Theme.text
        }
    }

    component SliderRow: ColumnLayout {
        id: sliderRow

        property string lowIcon
        property string highIcon
        property int from: 0
        property int value
        signal moved(int value)

        Layout.fillWidth: true
        Layout.topMargin: 8
        spacing: 2

        RowLayout {
            Layout.fillWidth: true

            Label {
                text: sliderRow.lowIcon
                size: 14
            }
            Item {
                Layout.fillWidth: true
            }
            Label {
                text: sliderRow.highIcon
                size: 14
            }
        }

        ThemedSlider {
            id: slider

            Layout.fillWidth: true
            from: sliderRow.from
            to: 100
            stepSize: 1
            wheelEnabled: false
            value: sliderRow.value
            onMoved: sliderRow.moved(value)

            WheelHandler {
                onWheel: e => sliderRow.moved(Math.max(sliderRow.from,
                    Math.min(100, slider.value + (e.angleDelta.y > 0 ? 5 : -5))))
            }
        }
    }

    component AppButton: Rectangle {
        id: btn

        property string icon
        property var command

        implicitWidth: 52
        implicitHeight: 52
        radius: 10
        color: hover.containsMouse ? Theme.surface : Theme.primaryContrast
        border.width: hover.containsMouse ? 1 : 0
        border.color: Qt.alpha(Theme.primary, 0.6)

        Text {
            anchors.centerIn: parent
            text: btn.icon
            color: Theme.primary
            font.family: Theme.font
            font.pixelSize: 24
        }

        MouseArea {
            id: hover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                // Close first: the panel holds the keyboard, and the new
                // window should get it.
                Overlays.dashboardOpen = false;
                Quickshell.execDetached(btn.command);
            }
        }
    }
}
