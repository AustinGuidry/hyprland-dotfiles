import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking
import qs
import qs.components
import qs.services

// "SSID (82%)" in the bar; click for a Wi-Fi picker. Replaces the
// networkmanager_dmenu click action (still one click away in the footer).
Pill {
    id: mod

    text: Net.active ? `${Net.ssid} (${Net.signal}%) ${Icons.wifiFor(Net.signal)}`
        : Net.wired ? `Wired ${Icons.ethernet}`
        : `Disconnected ${Icons.wifiOff}`
    bg: Net.online ? "transparent" : Theme.critical
    fg: Net.online ? Theme.text : Theme.criticalText
    clickable: true
    onClicked: popup.toggle()

    Popout {
        id: popup

        anchorItem: mod
        onVisibleChanged: if (Net.wifi) Net.wifi.scannerEnabled = visible

        RowLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 320
            Layout.margins: 6

            Text {
                Layout.fillWidth: true
                text: "Wi-Fi"
                color: Theme.primary
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
                font.bold: true
            }

            Switch {
                checked: Networking.wifiEnabled
                onToggled: on => Networking.wifiEnabled = on
            }
        }

        Repeater {
            model: ScriptModel {
                // Bucket the signal so rows don't reshuffle under the pointer
                // every time a strength reading wobbles.
                values: [...Net.networks]
                    .sort((a, b) => (b.connected - a.connected) || (b.known - a.known)
                        || (Math.round(b.signalStrength * 4) - Math.round(a.signalStrength * 4))
                        || a.name.localeCompare(b.name))
                    .slice(0, 12)
            }

            delegate: NetworkRow {}
        }

        Text {
            visible: Net.networks.length === 0
            Layout.margins: 12
            text: Networking.wifiEnabled ? "Scanning…" : "Wi-Fi is off"
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
            text: "More network settings…"
            onActivated: {
                popup.close();
                Quickshell.execDetached(["networkmanager_dmenu"]);
            }
        }
    }

    component NetworkRow: ColumnLayout {
        id: row

        required property var modelData
        readonly property bool secured: modelData.security !== WifiSecurityType.Open
        property bool askPassword: false
        property string error: ""

        Layout.fillWidth: true
        spacing: 2

        Connections {
            target: row.modelData
            function onConnectionFailed(reason) {
                row.error = "Couldn't connect: " + ConnectionFailReason.toString(reason);
            }
            function onConnectedChanged() {
                if (row.modelData.connected)
                    row.error = "";
            }
        }

        MenuItem {
            id: entry
            text: `${Icons.wifiFor(row.modelData.signalStrength * 100)}  ${row.modelData.name}`
            fg: row.modelData.connected ? Theme.primary : Theme.text
            trailing: row.modelData.stateChanging ? "…"
                : row.modelData.connected ? (entry.hovered ? "Disconnect" : "Connected")
                : row.secured && !row.modelData.known ? Icons.lock : ""
            onActivated: {
                row.error = "";
                if (row.modelData.connected)
                    row.modelData.disconnect();
                else if (row.modelData.known || !row.secured)
                    row.modelData.connect();
                else
                    row.askPassword = !row.askPassword;
            }
        }

        Rectangle {
            visible: row.askPassword
            Layout.fillWidth: true
            Layout.leftMargin: 12
            Layout.rightMargin: 12
            Layout.bottomMargin: 4
            implicitHeight: 30
            radius: 6
            color: Qt.alpha(Theme.primaryContrast, 0.5)
            border.width: 1
            border.color: password.activeFocus ? Theme.primary : Qt.alpha(Theme.primary, 0.3)

            TextInput {
                id: password
                anchors {
                    fill: parent
                    leftMargin: 8
                    rightMargin: 8
                }
                verticalAlignment: TextInput.AlignVCenter
                echoMode: TextInput.Password
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: Theme.fontSize - 1
                onVisibleChanged: if (visible) forceActiveFocus()
                onAccepted: {
                    row.modelData.connectWithPsk(text);
                    text = "";
                    row.askPassword = false;
                }
                Keys.onEscapePressed: row.askPassword = false

                Text {
                    visible: !password.text
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Password, then Enter"
                    color: Qt.alpha(Theme.text, 0.4)
                    font: password.font
                }
            }
        }

        Text {
            visible: row.error !== ""
            Layout.leftMargin: 12
            Layout.bottomMargin: 4
            text: row.error
            color: Theme.criticalText
            font.family: Theme.font
            font.pixelSize: Theme.fontSize - 3
        }
    }
}
