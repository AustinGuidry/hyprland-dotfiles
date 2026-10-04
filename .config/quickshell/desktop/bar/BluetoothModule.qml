import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import qs
import qs.components

// "On" / "Off" (or the connected device) in the bar; click for paired devices.
// Pairing something new still goes through rofi-bluetooth, from the footer.
Pill {
    id: mod

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool powered: adapter?.enabled ?? false
    readonly property var connected: Bluetooth.devices.values.filter(d => d.connected)

    visible: adapter !== null
    text: !powered ? "Off" : connected.length > 0 ? connected[0].name : "On"
    fontSize: 16
    clickable: true
    onClicked: popup.toggle()

    Popout {
        id: popup

        anchorItem: mod

        RowLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 300
            Layout.margins: 6

            Text {
                Layout.fillWidth: true
                text: "Bluetooth"
                color: Theme.primary
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
                font.bold: true
            }

            Switch {
                checked: mod.powered
                onToggled: on => {
                    if (mod.adapter)
                        mod.adapter.enabled = on;
                }
            }
        }

        Repeater {
            model: ScriptModel {
                values: Bluetooth.devices.values
                    .filter(d => d.paired || d.connected)
                    .sort((a, b) => (b.connected - a.connected) || a.name.localeCompare(b.name))
            }

            delegate: MenuItem {
                id: entry

                required property BluetoothDevice modelData

                enabled: mod.powered
                text: `${modelData.connected ? Icons.bluetoothConnected : Icons.bluetooth}  ${modelData.name}`
                fg: modelData.connected ? Theme.primary : Theme.text
                trailing: modelData.state === BluetoothDeviceState.Connecting ? "Connecting…"
                    : modelData.state === BluetoothDeviceState.Disconnecting ? "…"
                    : !modelData.connected ? ""
                    : entry.hovered ? "Disconnect"
                    : modelData.batteryAvailable ? `${Math.round(modelData.battery * 100)}%`
                    : "Connected"
                onActivated: modelData.connected ? modelData.disconnect() : modelData.connect()
            }
        }

        Text {
            visible: !Bluetooth.devices.values.some(d => d.paired || d.connected)
            Layout.margins: 12
            text: "No paired devices"
            color: Theme.secondary
            font.family: Theme.font
            font.pixelSize: Theme.fontSize - 1
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: 4
            Layout.bottomMargin: 4
            implicitHeight: 1
            color: Qt.alpha(Theme.primary, 0.2)
        }

        MenuItem {
            text: "Pair a new device…"
            onActivated: {
                popup.close();
                Quickshell.execDetached(["rofi-bluetooth"]);
            }
        }
    }
}
