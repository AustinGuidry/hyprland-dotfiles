import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import qs

// Month view for the clock tooltip, today highlighted.
ColumnLayout {
    id: cal

    property date today: new Date()

    spacing: 6

    Text {
        Layout.alignment: Qt.AlignHCenter
        text: Qt.formatDate(cal.today, "yyyy MMMM")
        color: Theme.primary
        font.family: Theme.font
        font.pixelSize: Theme.fontSize + 3
        font.bold: true
    }

    DayOfWeekRow {
        Layout.fillWidth: true
        locale: grid.locale

        delegate: Text {
            required property string shortName
            text: shortName.slice(0, 2)
            horizontalAlignment: Text.AlignHCenter
            color: Theme.secondary
            font.family: Theme.font
            font.pixelSize: Theme.fontSize - 2
            font.bold: true
        }
    }

    MonthGrid {
        id: grid

        Layout.fillWidth: true
        month: cal.today.getMonth()
        year: cal.today.getFullYear()
        locale: Qt.locale()
        spacing: 2

        delegate: Rectangle {
            required property int day
            required property int month
            required property bool today

            implicitWidth: 30
            implicitHeight: 24
            radius: 6
            color: today ? Theme.primary : "transparent"

            Text {
                anchors.centerIn: parent
                text: parent.day
                opacity: parent.month === grid.month ? 1 : 0.3
                color: parent.today ? Theme.primaryContrast : Theme.text
                font.family: Theme.font
                font.pixelSize: Theme.fontSize - 2
                font.bold: parent.today
            }
        }
    }
}
