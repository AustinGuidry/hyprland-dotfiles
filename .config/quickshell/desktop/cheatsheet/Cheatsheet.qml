import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs

// Super+K keybind cheatsheet, centered over everything. Escape, Super+K
// again, or a click anywhere else closes it.
PanelWindow {
    id: win

    readonly property bool open: Overlays.cheatsheetOpen

    visible: open || card.opacity > 0
    exclusiveZone: 0
    implicitWidth: card.width
    implicitHeight: card.height
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-cheatsheet"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onOpenChanged: if (open) card.forceActiveFocus()

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
        focus: true
        Keys.onEscapePressed: Overlays.cheatsheetOpen = false

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
        }
    }

    // A titled block of binds, e.g. "Windows".
    component Group: ColumnLayout {
        id: group

        required property var modelData

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
