// Lock screen theme picker: waypaper, but for qylock. A grid of the preview
// GIFs qylock ships; click one and the lock screen uses it from the next lock.
// Run with `qs -n -c lockpicker`.

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets

ShellRoot {
    id: root

    // The same two places qylock's lock.sh reads.
    readonly property string lockDir: Quickshell.env("HOME") + "/.local/share/quickshell-lockscreen"
    readonly property string themeFile: Quickshell.env("HOME") + "/.config/qylock/theme"

    // The theme in use is whatever the file names, so a change made anywhere
    // else shows up here too. With no file, lock.sh falls back to nier-automata.
    readonly property string current: chosen.text().trim() || "nier-automata"

    // [{ name, preview }], from list-themes.sh.
    property var themes: []
    property bool listed: false

    readonly property string font: "JetBrainsMono Nerd Font"

    function use(name) {
        if (name)
            chosen.setText(name + "\n");
    }

    // Open a theme for real, in an ordinary window, without locking anything.
    function tryLive(name) {
        if (!name)
            return;
        if (live.running) {
            live.next = name;
            live.running = false;
        } else {
            live.theme = name;
            live.running = true;
        }
    }

    FileView {
        id: chosen
        path: root.themeFile
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
    }

    // The desktop shell's palette, which matugen rewrites on every wallpaper
    // change (see ../desktop/Theme.qml).
    FileView {
        path: Quickshell.shellPath("../desktop/colors.json")
        watchChanges: true
        onFileChanged: reload()

        JsonAdapter {
            id: colors

            property string primary: "#90d5ae"
            property string secondary: "#b4ccbc"
            property string surface: "#0f1511"
            property string on_primary: "#003823"
            property string on_surface: "#dee4de"
        }
    }

    Process {
        running: true
        command: ["bash", Quickshell.shellPath("list-themes.sh"), root.lockDir + "/themes_link"]

        stdout: StdioCollector {
            onStreamFinished: {
                root.themes = text.split("\n").filter(line => line).map(line => {
                    const [name, preview] = line.split("\t");
                    return { name, preview };
                });
                root.listed = true;
                grid.currentIndex = Math.max(0, root.themes.findIndex(t => t.name === root.current));
                grid.positionViewAtIndex(grid.currentIndex, GridView.Center);
            }
        }
    }

    // lock_shell.qml has a windowed test path, but only takes it when it thinks
    // the session is X11; QT_QPA_PLATFORM keeps Qt itself on Wayland.
    Process {
        id: live

        property string theme: ""
        property string next: ""    // asked for while another preview was still open

        command: ["env", "QS_TESTING=1", "XDG_SESSION_TYPE=x11", "QT_QPA_PLATFORM=wayland",
            root.lockDir + "/lock.sh", theme]

        onExited: {
            if (!next)
                return;
            theme = next;
            next = "";
            Qt.callLater(() => live.running = true);
        }
    }

    FloatingWindow {
        title: "Lock Screen Themes"
        color: colors.surface
        implicitWidth: 1120
        implicitHeight: 760
        minimumSize: Qt.size(340, 320)

        // Without this the shell would stay running with no window.
        onClosed: Qt.quit()

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 6
                Layout.rightMargin: 6
                spacing: 8

                Text {
                    Layout.fillWidth: true
                    text: "Lock screen themes"
                    color: colors.primary
                    font.family: root.font
                    font.pixelSize: 20
                    font.bold: true
                    elide: Text.ElideRight
                }

                Text {
                    text: "In use"
                    color: colors.secondary
                    font.family: root.font
                    font.pixelSize: 14
                }

                Text {
                    text: root.current
                    color: colors.on_surface
                    font.family: root.font
                    font.pixelSize: 14
                    font.bold: true
                }
            }

            GridView {
                id: grid

                readonly property int columns: Math.max(1, Math.floor(width / 280))

                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                focus: true
                model: root.themes
                cellWidth: Math.floor(width / columns)
                // 16:9 thumbnail plus the card's padding and name line.
                cellHeight: Math.round((cellWidth - 28) * 9 / 16) + 56
                boundsBehavior: Flickable.StopAtBounds

                // A resize reflows the grid (tiling does it whenever a window
                // opens next to this one), so bring the cursor back into view,
                // once the grid has taken up its new column count.
                onCellHeightChanged: Qt.callLater(reveal)

                function reveal() {
                    forceLayout();
                    positionViewAtIndex(currentIndex, GridView.Contain);
                }

                // Where the arrow keys are; "" until the list has loaded.
                readonly property string cursor: root.themes[currentIndex]?.name ?? ""

                Keys.onReturnPressed: root.use(cursor)
                Keys.onEnterPressed: root.use(cursor)
                Keys.onEscapePressed: Qt.quit()
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_P) {
                        root.tryLive(cursor);
                        event.accepted = true;
                    }
                }

                delegate: Tile {}

                Text {
                    anchors.centerIn: parent
                    visible: root.listed && root.themes.length === 0
                    text: "No qylock themes found in\n" + root.lockDir + "/themes_link"
                    horizontalAlignment: Text.AlignHCenter
                    color: Qt.alpha(colors.on_surface, 0.6)
                    font.family: root.font
                    font.pixelSize: 14
                }

                Rectangle {
                    visible: grid.visibleArea.heightRatio < 1
                    anchors.right: parent.right
                    y: grid.visibleArea.yPosition * grid.height
                    width: 4
                    height: grid.visibleArea.heightRatio * grid.height
                    radius: 2
                    color: Qt.alpha(colors.on_surface, 0.25)
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 6
                Layout.rightMargin: 6
                spacing: 10

                Text {
                    Layout.fillWidth: true
                    text: live.running
                        ? `Trying ${live.theme} live. Its reboot and shutdown buttons are real.`
                        : "Click a theme to use it  ·  hover to play it  ·  arrows, Enter, P to try live, Esc"
                    color: Qt.alpha(colors.on_surface, 0.6)
                    font.family: root.font
                    font.pixelSize: 13
                    wrapMode: Text.WordWrap
                }

                Chip {
                    visible: live.running
                    text: "Close preview"
                    onClicked: {
                        live.next = "";
                        live.running = false;
                    }
                }
            }
        }
    }

    // One theme: its preview, its name, and a button to open it live.
    component Tile: Item {
        id: tile

        required property var modelData
        required property int index

        readonly property string name: modelData.name
        readonly property string preview: modelData.preview
        readonly property bool animated: preview.endsWith(".gif")
        readonly property bool inUse: name === root.current
        // Hovered, or where the arrow keys are: this one plays.
        readonly property bool lit: hover.hovered || GridView.isCurrentItem

        width: grid.cellWidth
        height: grid.cellHeight

        HoverHandler { id: hover }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 6
            radius: 10
            color: tile.inUse ? Qt.alpha(colors.primary, 0.14)
                : tile.lit ? Qt.alpha(colors.on_surface, 0.07) : "transparent"
            border.width: 2
            border.color: tile.inUse ? colors.primary
                : tile.lit ? Qt.alpha(colors.primary, 0.45) : "transparent"

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    grid.currentIndex = tile.index;
                    root.use(tile.name);
                }
            }

            ClippingRectangle {
                id: thumb

                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    margins: 8
                }
                height: Math.round(width * 9 / 16)
                radius: 6
                color: "black"

                // Still on its first frame until lit, so only one or two of
                // the GIFs are ever decoding at once.
                AnimatedImage {
                    anchors.fill: parent
                    visible: tile.animated
                    source: tile.animated ? "file://" + tile.preview : ""
                    fillMode: Image.PreserveAspectCrop
                    cache: false
                    playing: tile.lit
                    onPlayingChanged: if (!playing) currentFrame = 0
                }

                Image {
                    anchors.fill: parent
                    visible: !tile.animated && tile.preview !== ""
                    source: visible ? "file://" + tile.preview : ""
                    sourceSize.width: 640
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }

                Text {
                    anchors.centerIn: parent
                    visible: tile.preview === ""
                    text: "No preview"
                    color: Qt.alpha(colors.on_surface, 0.5)
                    font.family: root.font
                    font.pixelSize: 13
                }

                Chip {
                    visible: tile.lit
                    anchors {
                        right: parent.right
                        bottom: parent.bottom
                        margins: 6
                    }
                    text: "Try live"
                    onClicked: {
                        grid.currentIndex = tile.index;
                        root.tryLive(tile.name);
                    }
                }
            }

            Text {
                id: label

                anchors {
                    left: parent.left
                    right: badge.visible ? badge.left : parent.right
                    top: thumb.bottom
                    bottom: parent.bottom
                    leftMargin: 10
                    rightMargin: 10
                }
                verticalAlignment: Text.AlignVCenter
                text: tile.name
                color: tile.inUse ? colors.primary : colors.on_surface
                font.family: root.font
                font.pixelSize: 14
                font.bold: tile.inUse
                elide: Text.ElideRight
            }

            Rectangle {
                id: badge

                visible: tile.inUse
                anchors {
                    right: parent.right
                    rightMargin: 10
                    verticalCenter: label.verticalCenter
                }
                width: badgeText.implicitWidth + 16
                height: 20
                radius: 10
                color: colors.primary

                Text {
                    id: badgeText
                    anchors.centerIn: parent
                    text: "In use"
                    color: colors.on_primary
                    font.family: root.font
                    font.pixelSize: 12
                    font.bold: true
                }
            }
        }
    }

    // A small pill button.
    component Chip: Rectangle {
        id: chip

        property alias text: label.text
        signal clicked

        implicitWidth: label.implicitWidth + 20
        implicitHeight: 24
        radius: 12
        color: over.hovered ? colors.primary : Qt.alpha(colors.surface, 0.85)
        border.width: 1
        border.color: Qt.alpha(colors.primary, 0.6)

        Text {
            id: label
            anchors.centerIn: parent
            color: over.hovered ? colors.on_primary : colors.on_surface
            font.family: root.font
            font.pixelSize: 12
            font.bold: true
        }

        HoverHandler {
            id: over
            cursorShape: Qt.PointingHandCursor
        }

        MouseArea {
            anchors.fill: parent
            onClicked: chip.clicked()
        }
    }
}
