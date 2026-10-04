import QtQuick
import QtQuick.Layouts
import Quickshell
import qs

// Hover tooltip under a bar module (no grab, appears after a short delay).
PopupWindow {
    id: tip

    required property Item anchorItem
    property bool hovered: false
    default property alias content: body.data
    property int padding: 10

    onHoveredChanged: {
        if (hovered) {
            const p = anchorItem.mapToItem(null, 0, 0);
            anchor.rect.x = p.x;
            anchor.rect.width = anchorItem.width;
            delay.restart();
        } else {
            delay.stop();
            visible = false;
        }
    }

    Timer {
        id: delay
        interval: 450
        onTriggered: tip.visible = true
    }

    anchor.window: anchorItem.QsWindow.window
    anchor.rect.y: 0
    anchor.rect.height: Theme.barHeight
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom
    color: "transparent"
    implicitWidth: card.width
    implicitHeight: card.height + 6

    Rectangle {
        id: card
        y: 6
        width: body.implicitWidth + 2 * tip.padding
        height: body.implicitHeight + 2 * tip.padding
        color: Theme.surface
        border.width: 1
        border.color: Qt.alpha(Theme.primary, 0.4)
        radius: 8

        ColumnLayout {
            id: body
            x: tip.padding
            y: tip.padding
            spacing: 4
        }
    }
}
