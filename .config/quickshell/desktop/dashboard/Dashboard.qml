import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Wayland
import qs
import qs.components
import qs.services

// Super+D panel, top-left under the bar: a remake of the eww dashboard.
// Escape, Super+D, the bar button, or a click anywhere else closes it.
//
// The window covers the whole screen, bar included, with the card sitting in
// one corner of it; the transparent rest is what catches "anywhere else".
// (HyprlandFocusGrab was meant to do that, but while it was active neither
// clicks outside nor clicks on the bar button reached us.) The bar button
// needs no special case: a click on it lands on this window, and closes it.
PanelWindow {
    id: win

    readonly property bool open: Overlays.dashboardOpen

    visible: open || card.opacity > 0
    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }
    exclusionMode: ExclusionMode.Ignore
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

    MouseArea {
        anchors.fill: parent
        enabled: win.open
        acceptedButtons: Qt.AllButtons
        onPressed: Overlays.dashboardOpen = false
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

        // Same spot as the eww window: under the bar, 20px in.
        x: 20
        y: 50
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

        // So a click on the card's own background isn't a click outside it.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
        }

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
                    command: ["brave-browser-stable"]
                }
                AppButton {
                    icon: Icons.terminal
                    command: ["kitty"]
                }
                AppButton {
                    icon: Icons.folder
                    command: ["pcmanfm-qt"]
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
