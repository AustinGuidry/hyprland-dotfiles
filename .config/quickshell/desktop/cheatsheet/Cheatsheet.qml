import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs

// Super+K keybind cheatsheet, centered over everything. Start typing to
// filter; Escape clears the filter, then closes.
PanelWindow {
    id: win

    readonly property bool open: Overlays.cheatsheetOpen
    readonly property string query: filter.text.trim().toLowerCase()

    function matches(bind) {
        return query === "" || `${bind[0]} ${bind[1]}`.toLowerCase().includes(query);
    }

    visible: open || card.opacity > 0
    exclusiveZone: 0
    implicitWidth: card.width
    implicitHeight: card.height
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-cheatsheet"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onOpenChanged: {
        if (open) {
            filter.text = "";
            filter.forceActiveFocus();
        }
    }

    HyprlandFocusGrab {
        active: win.open
        windows: [win]
        onCleared: Overlays.cheatsheetOpen = false
    }

    Rectangle {
        id: card

        width: 1040
        height: content.implicitHeight + 48
        color: Theme.surface
        border.width: 2
        border.color: Theme.primary
        radius: 18
        opacity: win.open ? 1 : 0

        Behavior on opacity { NumberAnimation { duration: 140 } }

        ColumnLayout {
            id: content

            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: 24
                leftMargin: 28
                rightMargin: 28
            }
            spacing: 16

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "Keybindings"
                color: Theme.primary
                font.family: Theme.font
                font.pixelSize: 25
                font.bold: true
            }

            // Filter: invisible until you type, so the sheet looks as before.
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: -10
                spacing: 8
                opacity: filter.text ? 1 : 0.35

                Text {
                    text: Icons.search
                    color: Theme.secondary
                    font.family: Theme.font
                    font.pixelSize: 13
                }

                TextInput {
                    id: filter

                    Layout.preferredWidth: 220
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: 14
                    Keys.onEscapePressed: {
                        if (text)
                            text = "";
                        else
                            Overlays.cheatsheetOpen = false;
                    }

                    Text {
                        visible: !filter.text
                        text: "type to filter"
                        color: Theme.secondary
                        font: filter.font
                    }
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 40

                Repeater {
                    model: Keybinds.columns

                    delegate: ColumnLayout {
                        id: column

                        required property var modelData

                        Layout.alignment: Qt.AlignTop
                        spacing: 16

                        Repeater {
                            model: column.modelData
                            delegate: Group {}
                        }
                    }
                }
            }

            Text {
                visible: win.query !== "" && !Keybinds.columns.flat().some(g => g.binds.some(win.matches))
                Layout.alignment: Qt.AlignHCenter
                text: "No binds match"
                color: Theme.secondary
                font.family: Theme.font
                font.pixelSize: 14
            }
        }
    }

    // A titled block of binds, e.g. "Windows".
    component Group: ColumnLayout {
        id: group

        required property var modelData

        visible: modelData.binds.some(win.matches)
        spacing: 0

        Text {
            id: title
            Layout.alignment: Qt.AlignHCenter
            text: group.modelData.title
            color: Theme.secondary
            font.family: Theme.font
            font.pixelSize: 15
            font.bold: true
        }

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 3
            Layout.bottomMargin: 9
            implicitWidth: title.implicitWidth
            implicitHeight: 1
            color: Theme.primaryContrast
        }

        ColumnLayout {
            spacing: 7

            Repeater {
                model: group.modelData.binds

                delegate: RowLayout {
                    required property var modelData

                    visible: win.matches(modelData)
                    spacing: 12

                    Rectangle {
                        implicitWidth: Math.max(124, key.implicitWidth + 18)
                        implicitHeight: 22
                        radius: 7
                        color: Theme.primaryContrast

                        Text {
                            id: key
                            anchors.centerIn: parent
                            text: modelData[0]
                            color: Theme.primary
                            font.family: Theme.font
                            font.pixelSize: 13
                            font.bold: true
                        }
                    }

                    Text {
                        text: modelData[1]
                        color: Theme.text
                        font.family: Theme.font
                        font.pixelSize: 14
                    }
                }
            }
        }
    }
}
