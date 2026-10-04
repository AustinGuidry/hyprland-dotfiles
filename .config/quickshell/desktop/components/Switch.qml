import QtQuick
import qs

// On/off switch in the theme colors.
Rectangle {
    id: sw

    property bool checked: false
    signal toggled(bool checked)

    implicitWidth: 40
    implicitHeight: 22
    radius: height / 2
    color: checked ? Theme.primary : Qt.alpha(Theme.text, 0.15)

    Behavior on color { ColorAnimation { duration: 120 } }

    Rectangle {
        width: parent.height - 6
        height: width
        radius: width / 2
        y: 3
        x: sw.checked ? sw.width - width - 3 : 3
        color: sw.checked ? Theme.primaryContrast : Theme.text

        Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: sw.toggled(!sw.checked)
    }
}
