import QtQuick
import qs

// One bar module: a rounded label, optionally clickable. Matches waybar's
// per-module box -- margin 3px 2px, padding 0 5px, radius 6px.
Rectangle {
    id: pill

    property string text: ""
    property int fontSize: Theme.fontSize
    property color fg: Theme.text
    property color bg: "transparent"
    property color hoverBg: bg
    property int hpad: 5
    property bool clickable: false
    // waybar's `button:hover { box-shadow: inset 0 -3px primary }`
    property bool underline: false
    readonly property bool hovered: mouse.containsMouse

    signal clicked(var mouse)
    signal scrolled(int steps)

    implicitHeight: Theme.barHeight - 6
    implicitWidth: label.implicitWidth + 2 * hpad
    radius: Theme.radius
    color: hovered && clickable ? hoverBg : bg

    Text {
        id: label
        anchors.centerIn: parent
        text: pill.text
        color: pill.fg
        font.family: Theme.font
        font.pixelSize: pill.fontSize
    }

    Rectangle {
        visible: pill.underline
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            leftMargin: pill.radius - 2
            rightMargin: pill.radius - 2
        }
        height: 3
        radius: 1.5
        color: Theme.primary
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: pill.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: m => pill.clicked(m)
        onWheel: w => pill.scrolled(w.angleDelta.y > 0 ? 1 : -1)
    }
}
