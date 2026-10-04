import QtQuick
import QtQuick.Layouts
import qs

// A clickable menu row: padding 4px 12px, primary@0.3 on hover.
Rectangle {
    id: item

    property string text: ""
    property string trailing: ""
    property color fg: Theme.text
    readonly property alias hovered: mouse.containsMouse

    signal activated()

    Layout.fillWidth: true
    implicitWidth: row.implicitWidth + 24
    implicitHeight: row.implicitHeight + 8
    radius: 4
    color: mouse.containsMouse && enabled ? Qt.alpha(Theme.primary, 0.3) : "transparent"
    opacity: enabled ? 1 : 0.5

    RowLayout {
        id: row
        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
            leftMargin: 12
            rightMargin: 12
        }
        spacing: 16

        Text {
            Layout.fillWidth: true
            text: item.text
            color: item.fg
            elide: Text.ElideRight
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
        }

        Text {
            visible: item.trailing !== ""
            text: item.trailing
            color: Theme.secondary
            font.family: Theme.font
            font.pixelSize: Theme.fontSize - 2
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: item.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: item.activated()
    }
}
