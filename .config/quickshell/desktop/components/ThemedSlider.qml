import QtQuick
import QtQuick.Controls.Basic
import qs

// Horizontal slider in the theme colors (the eww one fell back to GTK blue).
Slider {
    id: s

    wheelEnabled: true

    background: Rectangle {
        x: s.leftPadding
        y: s.topPadding + s.availableHeight / 2 - height / 2
        width: s.availableWidth
        height: 6
        radius: 3
        color: Qt.alpha(Theme.text, 0.15)

        Rectangle {
            width: s.visualPosition * parent.width
            height: parent.height
            radius: 3
            color: Theme.primary
        }
    }

    handle: Rectangle {
        x: s.leftPadding + s.visualPosition * (s.availableWidth - width)
        y: s.topPadding + s.availableHeight / 2 - height / 2
        width: 18
        height: 18
        radius: 9
        color: s.pressed ? Theme.primary : Theme.text
        border.width: 2
        border.color: Theme.primary
    }
}
