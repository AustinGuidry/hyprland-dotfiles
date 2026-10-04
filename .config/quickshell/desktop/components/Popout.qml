import QtQuick
import QtQuick.Layouts
import Quickshell
import qs

// A dropdown hanging under a bar module, styled like waybar's GTK menus
// (surface, 1px primary@0.4 border, radius 8). It holds an xdg-popup grab, so
// clicking anywhere outside closes it; so does Escape.
PopupWindow {
    id: popup

    required property Item anchorItem
    default property alias content: body.data
    property int padding: 8
    property int gap: 6
    property double closedAt: 0

    function toggle() {
        if (visible) {
            visible = false;
            return;
        }
        // The click that broke the grab can also land on the module that
        // opened the popup -- don't let that same click reopen it.
        if (Date.now() - closedAt < 300)
            return;
        const p = anchorItem.mapToItem(null, 0, 0);
        anchor.rect.x = p.x;
        anchor.rect.width = anchorItem.width;
        visible = true;
    }

    function close() { visible = false; }

    onVisibleChanged: {
        if (visible) {
            fadeIn.restart();
            card.forceActiveFocus();
        } else {
            closedAt = Date.now();
        }
    }

    anchor.window: anchorItem.QsWindow.window
    anchor.rect.y: 0
    anchor.rect.height: Theme.barHeight
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom
    grabFocus: true
    color: "transparent"
    implicitWidth: card.width
    implicitHeight: card.height + gap

    Rectangle {
        id: card

        y: popup.gap
        width: body.implicitWidth + 2 * popup.padding
        height: body.implicitHeight + 2 * popup.padding
        color: Theme.surface
        border.width: 1
        border.color: Qt.alpha(Theme.primary, 0.4)
        radius: 8
        focus: true
        Keys.onEscapePressed: popup.close()

        NumberAnimation on opacity {
            id: fadeIn
            from: 0
            to: 1
            duration: 120
        }

        ColumnLayout {
            id: body
            x: popup.padding
            y: popup.padding
            spacing: 2
        }
    }
}
