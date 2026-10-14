// Lock screen theme picker: waypaper, but for qylock. A grid of the preview
// GIFs qylock ships; click one and the lock screen uses it from the next lock.
// A second tab does the same for the SDDM login screen, which takes the same
// themes. Run with `qs -n -c lockpicker`.

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
    readonly property string themesDir: lockDir + "/themes_link"

    // What the grid is choosing for: "lock" or "sddm".
    property string tab: "lock"
    readonly property bool sddm: tab === "sddm"

    // The theme in use is whatever the file names, so a change made anywhere
    // else shows up here too. With no file, lock.sh falls back to nier-automata.
    readonly property string lockCurrent: chosen.text().trim() || "nier-automata"

    // SDDM's is the Current= line of the one config file that sets it here.
    readonly property string sddmCurrent: (sddmConf.text().match(/^Current=(.*)$/m)?.[1] ?? "").trim()

    // The theme in use on the tab showing, by the grid's name for it. SDDM
    // knows a clockwork variant by its last part alone (see sddm-theme.sh).
    readonly property string current: {
        if (!sddm)
            return lockCurrent;
        const match = themes.find(t => t.name.split("/").pop() === sddmCurrent);
        return match?.name ?? (sddmCurrent || "SDDM's own");
    }

    // [{ name, preview }], from list-themes.sh.
    property var themes: []
    property bool listed: false

    readonly property string font: "JetBrainsMono Nerd Font"

    function use(name) {
        if (!name)
            return;
        if (!sddm) {
            chosen.setText(name + "\n");
        } else if (!install.running) {
            install.theme = name;
            install.result = -1;
            install.running = true;
        }
    }

    // Open a theme for real without locking or logging out: the lock screen
    // in an ordinary window, the login screen full screen as SDDM shows it.
    function tryLive(name) {
        if (!name)
            return;
        const what = { theme: name, login: sddm };
        if (live.running) {
            live.next = what;
            live.running = false;
        } else {
            live.open(what);
        }
    }

    // The line under the grid.
    readonly property string status: {
        if (install.running)
            return `Making ${install.theme} the login screen, once you give your password.`;
        if (live.running)
            return live.login
                ? `Trying ${live.theme} as the login screen. Nothing on it is connected; Super+Q closes it.`
                : `Trying ${live.theme} live. Its reboot and shutdown buttons are real.`;
        if (!sddm)
            return "Click a theme to use it  ·  hover to play it  ·  arrows, Enter, P to try live, Tab, Esc";
        if (install.result === 0)
            return `${install.theme} is the login screen from the next logout.`;
        // pkexec's two ways of saying no: dialog cancelled, and not authorized.
        if (install.result === 126 || install.result === 127)
            return "Login screen not changed: that takes your password.";
        if (install.result > 0)
            return "Login screen not changed: "
                + (complaint.text.trim().split("\n")[0] || `sddm-theme.sh failed (${install.result})`);
        return "Click a theme to log in with it (asks for your password)  ·  hover to play it  ·  arrows, Enter, P to try live, Tab, Esc";
    }

    onTabChanged: {
        install.result = -1;
        Qt.callLater(grid.showCurrent);
    }

    FileView {
        id: chosen
        path: root.themeFile
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
    }

    // Where sddm-theme.sh and qylock's own sddm.sh both write the theme.
    FileView {
        id: sddmConf
        path: "/etc/sddm.conf.d/theme.conf"
        blockLoading: true
        watchChanges: true
        printErrors: false
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
        command: ["bash", Quickshell.shellPath("list-themes.sh"), root.themesDir]

        stdout: StdioCollector {
            onStreamFinished: {
                root.themes = text.split("\n").filter(line => line).map(line => {
                    const [name, preview] = line.split("\t");
                    return { name, preview };
                });
                root.listed = true;
                grid.showCurrent();
            }
        }
    }

    // The one live preview. lock_shell.qml has a windowed test path, but only
    // takes it when it thinks the session is X11; QT_QPA_PLATFORM keeps Qt
    // itself on Wayland. SDDM's greeter has a test mode of its own, and reads
    // the theme from where it is.
    Process {
        id: live

        property string theme: ""
        property bool login: false  // the login screen rather than the lock screen
        property var next: null     // asked for while another preview was still open

        command: login
            ? ["sddm-greeter-qt6", "--test-mode", "--theme", root.themesDir + "/" + theme]
            : ["env", "QS_TESTING=1", "XDG_SESSION_TYPE=x11", "QT_QPA_PLATFORM=wayland",
                root.lockDir + "/lock.sh", theme]

        function open(what) {
            theme = what.theme;
            login = what.login;
            running = true;
        }

        onExited: {
            if (!next)
                return;
            const what = next;
            next = null;
            Qt.callLater(() => live.open(what));
        }
    }

    // Root's share of picking a login theme, behind polkit's password dialog.
    Process {
        id: install

        property string theme: ""
        property int result: -1     // exit code of the last run, -1 before one

        command: ["pkexec", "bash", Quickshell.shellPath("sddm-theme.sh"), root.themesDir, theme]

        stderr: StdioCollector { id: complaint }

        onExited: code => {
            result = code;
            sddmConf.reload();
        }
    }

    FloatingWindow {
        title: root.sddm ? "SDDM Themes" : "Lock Screen Themes"
        color: colors.surface
        implicitWidth: 1120
        implicitHeight: 760
        minimumSize: Qt.size(420, 320)

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

                TabTitle {
                    name: "lock"
                    text: "Lock screen themes"
                }

                TabTitle {
                    Layout.leftMargin: 14
                    name: "sddm"
                    text: "SDDM themes"
                }

                Item {
                    Layout.fillWidth: true
                }

                Text {
                    text: "In use"
                    color: colors.secondary
                    font.family: root.font
                    font.pixelSize: 14
                }

                // Gives way before the tabs do when the window is narrow. The
                // layout deals in whole pixels, and one short would elide it.
                Text {
                    Layout.fillWidth: true
                    Layout.preferredWidth: Math.ceil(implicitWidth)
                    Layout.maximumWidth: Math.ceil(implicitWidth)
                    text: root.current
                    color: colors.on_surface
                    font.family: root.font
                    font.pixelSize: 14
                    font.bold: true
                    elide: Text.ElideRight
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

                // Start from the theme in use, on opening and on changing tab.
                function showCurrent() {
                    currentIndex = Math.max(0, root.themes.findIndex(t => t.name === root.current));
                    positionViewAtIndex(currentIndex, GridView.Center);
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
                    } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                        root.tab = root.sddm ? "lock" : "sddm";
                        event.accepted = true;
                    }
                }

                delegate: Tile {}

                Text {
                    anchors.centerIn: parent
                    visible: root.listed && root.themes.length === 0
                    text: "No qylock themes found in\n" + root.themesDir
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
                    text: root.status
                    color: Qt.alpha(colors.on_surface, 0.6)
                    font.family: root.font
                    font.pixelSize: 13
                    wrapMode: Text.WordWrap
                }

                Chip {
                    visible: live.running
                    text: "Close preview"
                    onClicked: {
                        live.next = null;
                        live.running = false;
                    }
                }
            }
        }
    }

    // One of the header's two titles; the grid chooses for the lit one.
    component TabTitle: Item {
        id: heading

        required property string name
        property alias text: label.text
        readonly property bool shown: root.tab === name

        implicitWidth: label.implicitWidth
        implicitHeight: label.implicitHeight + 6

        // Bold either way, so the pair does not shift as the tab changes.
        Text {
            id: label
            color: heading.shown ? colors.primary
                : over.hovered ? colors.on_surface : Qt.alpha(colors.on_surface, 0.45)
            font.family: root.font
            font.pixelSize: 20
            font.bold: true
        }

        Rectangle {
            visible: heading.shown
            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
            }
            height: 2
            radius: 1
            color: colors.primary
        }

        HoverHandler {
            id: over
            cursorShape: Qt.PointingHandCursor
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.tab = heading.name
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
