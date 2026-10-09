import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.components
import qs.services

// A shield beside the dashboard button: an outline while the VPN is down, a
// ticked shield in the accent color while it's up. Click for the on/off
// switch, UDP or TCP, and Surfshark's locations.
Pill {
    id: mod

    readonly property bool working: Surfshark.busy === "connecting" || Surfshark.busy === "disconnecting"
    // The list loading in the background doesn't hold anything up.
    readonly property bool usable: Surfshark.ready && (!Surfshark.busy || Surfshark.busy === "listing")
    readonly property string query: filter.text.trim().toLowerCase()
    // Recently used first; a search just shows its matches.
    readonly property var shown: {
        const all = Surfshark.locations;
        if (query)
            return all.filter(name => name.toLowerCase().includes(query));
        const recent = Surfshark.recent.filter(name => all.includes(name));
        return recent.concat(all.filter(name => !recent.includes(name)));
    }

    // A row moving to the top as "recent" would otherwise land above the view.
    onShownChanged: Qt.callLater(() => list.positionViewAtBeginning())

    function pick(name) {
        if (Surfshark.connected && Surfshark.owned && Surfshark.location === name)
            Surfshark.disconnect();
        else
            Surfshark.connect(name);
    }

    text: working ? Icons.shieldBusy : Surfshark.connected ? Icons.shieldOn : Icons.shieldOff
    fontSize: 16
    hpad: 10
    fg: Surfshark.connected && !working ? Theme.primary : Theme.text
    clickable: true
    onClicked: popup.toggle()

    SequentialAnimation on opacity {
        running: mod.working
        loops: Animation.Infinite
        alwaysRunToEnd: true

        NumberAnimation { to: 0.35; duration: 500 }
        NumberAnimation { to: 1; duration: 500 }
    }

    Popout {
        id: popup

        anchorItem: mod
        onVisibleChanged: {
            if (!visible)
                return;
            filter.text = "";
            list.positionViewAtBeginning();
            Surfshark.opened();
            // After the Popout has taken focus for its own Escape handling.
            Qt.callLater(() => filter.forceActiveFocus());
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 300
            Layout.margins: 6
            Layout.bottomMargin: 0

            Text {
                Layout.fillWidth: true
                text: "Surfshark"
                color: Theme.primary
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
                font.bold: true
            }

            // Stays live while connecting: off again cancels.
            Switch {
                enabled: mod.usable || (Surfshark.busy === "connecting" && !Surfshark.cancelling)
                opacity: Surfshark.ready ? 1 : 0.4
                checked: (Surfshark.busy === "connecting" && !Surfshark.cancelling)
                    || (Surfshark.connected && Surfshark.busy !== "disconnecting" && !Surfshark.cancelling)
                onToggled: on => on ? Surfshark.connect(Surfshark.location) : Surfshark.disconnect()
            }
        }

        Text {
            Layout.leftMargin: 6
            Layout.rightMargin: 6
            Layout.bottomMargin: 6
            Layout.preferredWidth: 288
            text: Surfshark.error || Surfshark.summary
            color: Surfshark.error ? Theme.criticalText : Theme.secondary
            wrapMode: Text.Wrap
            font.family: Theme.font
            font.pixelSize: Theme.fontSize - 2
        }

        // ── Not set up yet, or the root copy is stale ────────────────────────
        Text {
            visible: !Surfshark.ready || !Surfshark.upToDate
            Layout.leftMargin: 6
            Layout.rightMargin: 6
            Layout.bottomMargin: 4
            Layout.preferredWidth: 288
            text: !Surfshark.installed ? "Surfshark only runs as root. A one-time setup lets this menu switch it without asking for your password."
                : !Surfshark.allowed ? "sudo won't run the menu's helper without a password. Running the setup again fixes that."
                : "The installed helper is older than the one in this config."
            color: Theme.text
            wrapMode: Text.Wrap
            font.family: Theme.font
            font.pixelSize: Theme.fontSize - 2
        }

        MenuItem {
            visible: !Surfshark.ready || !Surfshark.upToDate
            text: Surfshark.ready ? "Update it in a terminal…" : "Run setup in a terminal…"
            onActivated: {
                popup.close();
                Quickshell.execDetached(["kitty", "--title", "Surfshark menu setup", "sh", "-c",
                    "sudo \"$0\"; printf '\\nPress Enter to close. '; read _", Surfshark.installer]);
            }
        }

        // ── Protocol ─────────────────────────────────────────────────────────
        RowLayout {
            visible: Surfshark.ready
            Layout.fillWidth: true
            Layout.leftMargin: 6
            Layout.rightMargin: 6
            spacing: 6

            Text {
                Layout.fillWidth: true
                text: "Protocol"
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: Theme.fontSize - 1
            }

            Choice { value: "udp" }
            Choice { value: "tcp" }
        }

        Rectangle {
            visible: Surfshark.ready
            Layout.fillWidth: true
            Layout.topMargin: 6
            Layout.bottomMargin: 4
            implicitHeight: 1
            color: Qt.alpha(Theme.primary, 0.2)
        }

        // ── Locations ────────────────────────────────────────────────────────
        Rectangle {
            visible: Surfshark.ready && Surfshark.locations.length > 0
            Layout.fillWidth: true
            Layout.leftMargin: 6
            Layout.rightMargin: 6
            Layout.bottomMargin: 4
            implicitHeight: 30
            radius: 6
            color: Qt.alpha(Theme.primaryContrast, 0.5)
            border.width: 1
            border.color: filter.activeFocus ? Theme.primary : Qt.alpha(Theme.primary, 0.3)

            Text {
                id: glass
                anchors {
                    left: parent.left
                    leftMargin: 9
                    verticalCenter: parent.verticalCenter
                }
                text: Icons.search
                color: Qt.alpha(Theme.text, 0.5)
                font.family: Theme.font
                font.pixelSize: Theme.fontSize - 2
            }

            TextInput {
                id: filter
                anchors {
                    left: glass.right
                    right: parent.right
                    top: parent.top
                    bottom: parent.bottom
                    leftMargin: 8
                    rightMargin: 8
                }
                verticalAlignment: TextInput.AlignVCenter
                clip: true
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: Theme.fontSize - 1
                // Enter takes the top match.
                onAccepted: {
                    if (mod.usable && mod.query && mod.shown.length > 0)
                        mod.pick(mod.shown[0]);
                }

                Text {
                    visible: !filter.text
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Search locations"
                    color: Qt.alpha(Theme.text, 0.4)
                    font: filter.font
                }
            }
        }

        MenuItem {
            readonly property bool live: Surfshark.connected && Surfshark.owned && Surfshark.location === ""

            visible: Surfshark.ready && !mod.query
            enabled: mod.usable
            text: `${Icons.bolt}  Nearest server`
            fg: live ? Theme.primary : Theme.text
            trailing: Surfshark.busy === "connecting" && Surfshark.target === "" ? "Connecting…"
                : live ? (hovered ? "Disconnect" : "Connected") : ""
            onActivated: mod.pick("")
        }

        ListView {
            id: list

            visible: Surfshark.ready && count > 0
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, 252)   // nine rows
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: ScriptModel {
                values: mod.shown
            }

            delegate: MenuItem {
                required property string modelData
                readonly property bool live: Surfshark.connected && Surfshark.owned && Surfshark.location === modelData

                width: list.width - (thumb.visible ? 8 : 0)
                enabled: mod.usable
                text: modelData
                fg: live ? Theme.primary : Theme.text
                trailing: Surfshark.busy === "connecting" && Surfshark.target === modelData ? "Connecting…"
                    : live ? (hovered ? "Disconnect" : "Connected")
                    : !mod.query && Surfshark.recent.includes(modelData) ? "Recent" : ""
                onActivated: mod.pick(modelData)
            }

            Rectangle {
                id: thumb
                visible: list.visibleArea.heightRatio < 1
                anchors.right: parent.right
                y: list.visibleArea.yPosition * list.height
                width: 3
                height: list.visibleArea.heightRatio * list.height
                radius: 1.5
                color: Qt.alpha(Theme.primary, 0.5)
            }
        }

        Text {
            visible: Surfshark.ready && list.count === 0
            Layout.margins: 12
            Layout.preferredWidth: 270
            text: mod.query ? "No location matches"
                : Surfshark.busy === "listing" ? "Loading locations…"
                : Surfshark.connected ? "The location list loads while the VPN is off."
                : "No locations yet"
            color: Theme.secondary
            wrapMode: Text.Wrap
            font.family: Theme.font
            font.pixelSize: Theme.fontSize - 1
        }
    }

    component Choice: Rectangle {
        id: choice

        required property string value
        readonly property bool chosen: Surfshark.protocol === value

        implicitWidth: label.implicitWidth + 24
        implicitHeight: 24
        radius: 4
        opacity: mod.usable || chosen ? 1 : 0.5
        color: chosen ? Theme.primary
            : hover.containsMouse && mod.usable ? Qt.alpha(Theme.primary, 0.3) : "transparent"
        border.width: chosen ? 0 : 1
        border.color: Qt.alpha(Theme.primary, 0.3)

        Text {
            id: label
            anchors.centerIn: parent
            text: choice.value.toUpperCase()
            color: choice.chosen ? Theme.primaryContrast : Theme.text
            font.family: Theme.font
            font.pixelSize: Theme.fontSize - 2
        }

        MouseArea {
            id: hover
            anchors.fill: parent
            hoverEnabled: true
            enabled: mod.usable
            cursorShape: Qt.PointingHandCursor
            onClicked: Surfshark.setProtocol(choice.value)
        }
    }
}
