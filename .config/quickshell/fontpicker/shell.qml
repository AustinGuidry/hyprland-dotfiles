// Font picker: one place to change fonts across the desktop. Every font that
// can set English text, each drawing a sample line; click one and tick where
// it should go: the bar, the terminal, the launcher and the rest, each at a
// size of its own. "Sizes" changes only the sizes. fonts.py reads and writes
// each program's own setting. Run with `qs -n -c fontpicker`.

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

ShellRoot {
    id: root

    // From `fonts.py list`: [{ family, mono, icons }], and the places that
    // take a font as [{ id, name, app, note, mono, now, shows, size, unit,
    // min, max }], where `shows` is the family actually drawn there and
    // `unit` is "" for a place with no size of its own.
    property var fonts: []
    property var places: []
    property bool listed: false

    property string query: ""
    property bool monoOnly: false
    property int sampleSize: 26
    readonly property string defaultSample: "The quick brown fox jumps over the lazy dog"
    readonly property string codeSample: "0123456789  {}[]()<>  -> => != <= &&  @#$%&*"

    readonly property var shown: {
        const q = query.trim().toLowerCase();
        return fonts.filter(f => (!monoOnly || f.mono) && f.family.toLowerCase().includes(q));
    }

    // The dialog is open for a family ("Where do you want to use it?") or,
    // with `sizing`, for sizes alone. `ticked` holds the ids of the places
    // ticked in it, `sizes` the size each place is set to there.
    property string choosing: ""
    property bool sizing: false
    readonly property bool asking: choosing !== "" || sizing
    readonly property bool choosingMono: fonts.find(f => f.family === choosing)?.mono ?? false
    property var ticked: []
    property var sizes: ({})

    // A place with no size of its own has nothing to show when sizing.
    readonly property var asked: sizing ? places.filter(p => p.unit) : places
    readonly property var resized: places.filter(p => p.unit && sizes[p.id] !== undefined && sizes[p.id] !== p.size)

    // What the last change replaced, { id: setting }, for Undo.
    property var undo: null
    property string status: ""

    readonly property string font: "JetBrainsMono Nerd Font"

    function usedBy(family) {
        return places.filter(p => p.shows === family);
    }

    // Sizing keeps each place's font, so anything goes.
    function fits(place) {
        return sizing || !place.mono || choosingMono;
    }

    // Open the dialog: for a family, or with "" for sizes alone.
    function choose(family) {
        if (worker.running || !listed)
            return;
        choosing = family;
        sizing = !family;
        ticked = [];
        // No Object.fromEntries in Qt's JavaScript.
        const start = {};
        for (const p of places.filter(p => p.unit))
            start[p.id] = p.size;
        sizes = start;
        dialog.cursor = 0;
        dialog.forceActiveFocus();
    }

    function closeDialog() {
        choosing = "";
        sizing = false;
        search.input.forceActiveFocus();
    }

    function toggle(place) {
        if (sizing || !fits(place))
            return;
        ticked = ticked.includes(place.id) ? ticked.filter(id => id !== place.id) : ticked.concat([place.id]);
    }

    // Changing a place's size ticks it: that is a change to make there.
    function resize(place, by) {
        if (!place?.unit)
            return;
        const size = Math.max(place.min, Math.min(place.max, sizes[place.id] + by));
        sizes = Object.assign({}, sizes, { [place.id]: size });
        if (!sizing && fits(place) && !ticked.includes(place.id))
            ticked = ticked.concat([place.id]);
    }

    readonly property bool ready: sizing ? resized.length > 0 : ticked.length > 0

    function apply() {
        if (!ready)
            return;
        const chosen = sizing ? resized : places.filter(p => ticked.includes(p.id));
        const changes = {};
        const parts = [];
        for (const p of chosen) {
            const change = sizing ? {} : { family: choosing };
            let part = p.name;
            if (resized.includes(p)) {
                change.size = sizes[p.id];
                part += sizing ? ` to ${sizes[p.id]} ${p.unit}` : ` (${sizes[p.id]} ${p.unit})`;
            }
            changes[p.id] = change;
            parts.push(part);
        }
        worker.start(["apply", JSON.stringify(changes)], { family: choosing, parts });
        closeDialog();
    }

    function revert() {
        if (undo && !worker.running)
            worker.start(["restore", JSON.stringify(undo)], null);
    }

    // "a", "a and b", "a, b and c".
    function sentence(names) {
        return names.length < 2 ? names.join("") : names.slice(0, -1).join(", ") + " and " + names[names.length - 1];
    }

    function finished(job, result) {
        const failed = result.errors ?? [];
        undo = job && Object.keys(result.before ?? {}).length ? result.before : null;
        if (failed.length)
            status = (job ? "Not changed everywhere: " : "Undo failed: ") + failed.join("; ");
        else if (job?.family)
            status = `${job.family} is now the font for ${sentence(job.parts)}.`;
        else if (job)
            status = `Resized ${sentence(job.parts)}.`;
        else
            status = "Put back as it was.";
        lister.running = true;
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

    // Run again after every change, for what each place now shows.
    Process {
        id: lister
        running: true
        command: ["python3", Quickshell.shellPath("fonts.py"), "list"]

        stdout: StdioCollector {
            onStreamFinished: {
                const data = JSON.parse(text);
                // The fonts themselves don't change, and a new model would
                // throw the list back to the top.
                if (!root.listed)
                    root.fonts = data.fonts;
                root.places = data.places;
                root.listed = true;
            }
        }
    }

    // One apply or undo at a time. Results come back on stdout, errors and
    // all, so nothing waits on the exit code.
    Process {
        id: worker

        property var job: null      // { family, parts } for an apply, null for an undo

        function start(args, what) {
            job = what;
            command = ["python3", Quickshell.shellPath("fonts.py"), ...args];
            running = true;
        }

        stdout: StdioCollector {
            onStreamFinished: {
                let result;
                try {
                    result = JSON.parse(text);
                } catch (e) {
                    result = { before: {}, errors: ["fonts.py failed (see qs log -c fontpicker)"] };
                }
                root.finished(worker.job, result);
            }
        }
    }

    FloatingWindow {
        title: "Fonts"
        color: colors.surface
        implicitWidth: 1000
        implicitHeight: 780
        minimumSize: Qt.size(480, 360)

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
                spacing: 10

                Text {
                    Layout.rightMargin: 8
                    text: "Fonts"
                    color: colors.primary
                    font.family: root.font
                    font.pixelSize: 20
                    font.bold: true
                }

                Field {
                    id: search

                    Layout.fillWidth: true
                    placeholder: root.listed ? `Search ${root.fonts.length} fonts` : "Looking for fonts..."
                    onEdited: root.query = text
                    Component.onCompleted: input.forceActiveFocus()

                    onKey: event => {
                        switch (event.key) {
                        case Qt.Key_Down:
                            list.step(1);
                            break;
                        case Qt.Key_Up:
                            list.step(-1);
                            break;
                        case Qt.Key_PageDown:
                            list.step(5);
                            break;
                        case Qt.Key_PageUp:
                            list.step(-5);
                            break;
                        case Qt.Key_Return:
                        case Qt.Key_Enter:
                            // "" would open the sizes instead.
                            if (list.cursor)
                                root.choose(list.cursor);
                            break;
                        case Qt.Key_Escape:
                            if (search.text)
                                search.text = "";
                            else
                                Qt.quit();
                            break;
                        default:
                            return;
                        }
                        event.accepted = true;
                    }
                }

                Chip {
                    text: "Monospace only"
                    on: root.monoOnly
                    onClicked: root.monoOnly = !root.monoOnly
                }

                Chip {
                    text: "Sizes"
                    onClicked: root.choose("")
                }

                // How big the samples below are drawn, and nothing more.
                Text {
                    Layout.leftMargin: 6
                    text: "Preview"
                    color: Qt.alpha(colors.on_surface, 0.5)
                    font.family: root.font
                    font.pixelSize: 13
                }

                Chip {
                    text: "A−"
                    onClicked: root.sampleSize = Math.max(12, root.sampleSize - 2)
                }

                Text {
                    Layout.preferredWidth: 44
                    horizontalAlignment: Text.AlignHCenter
                    text: root.sampleSize + " px"
                    color: colors.secondary
                    font.family: root.font
                    font.pixelSize: 13
                }

                Chip {
                    text: "A+"
                    onClicked: root.sampleSize = Math.min(72, root.sampleSize + 2)
                }
            }

            Field {
                id: sample

                Layout.fillWidth: true
                Layout.leftMargin: 6
                Layout.rightMargin: 6
                placeholder: "Sample text: type your own"

                onKey: event => {
                    if (event.key === Qt.Key_Escape || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        search.input.forceActiveFocus();
                        event.accepted = true;
                    }
                }
            }

            ListView {
                id: list

                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 8
                model: root.shown
                boundsBehavior: Flickable.StopAtBounds

                // Where the arrow keys are; "" while nothing is listed.
                readonly property string cursor: root.shown[currentIndex]?.family ?? ""

                function step(by) {
                    currentIndex = Math.max(0, Math.min(count - 1, currentIndex + by));
                    positionViewAtIndex(currentIndex, ListView.Contain);
                }

                delegate: FontRow {}

                Text {
                    anchors.centerIn: parent
                    visible: root.listed && root.shown.length === 0
                    text: root.query ? `No font matches "${root.query}"` : "No fonts found"
                    color: Qt.alpha(colors.on_surface, 0.6)
                    font.family: root.font
                    font.pixelSize: 14
                }

                Rectangle {
                    visible: list.visibleArea.heightRatio < 1
                    anchors.right: parent.right
                    y: list.visibleArea.yPosition * list.height
                    width: 4
                    height: list.visibleArea.heightRatio * list.height
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
                    text: worker.running ? "Changing fonts..."
                        : root.status || "Click a font to choose where to use it  ·  type to search  ·  arrows, Enter, Esc"
                    color: Qt.alpha(colors.on_surface, 0.6)
                    font.family: root.font
                    font.pixelSize: 13
                    wrapMode: Text.WordWrap
                }

                Chip {
                    visible: root.undo !== null && !worker.running
                    text: "Undo"
                    onClicked: root.revert()
                }
            }
        }

        // "Where do you want to use it?", or the sizes alone, over the list.
        Rectangle {
            id: dialog

            property int cursor: 0      // the place the arrow keys are on

            anchors.fill: parent
            visible: root.asking
            color: Qt.alpha("black", 0.55)

            Keys.onPressed: event => {
                const place = root.asked[cursor];
                switch (event.key) {
                case Qt.Key_Down:
                    cursor = Math.min(root.asked.length - 1, cursor + 1);
                    break;
                case Qt.Key_Up:
                    cursor = Math.max(0, cursor - 1);
                    break;
                case Qt.Key_Space:
                    if (place)
                        root.toggle(place);
                    break;
                case Qt.Key_Left:
                case Qt.Key_Minus:
                    root.resize(place, -1);
                    break;
                case Qt.Key_Right:
                case Qt.Key_Plus:
                case Qt.Key_Equal:
                    root.resize(place, 1);
                    break;
                case Qt.Key_Return:
                case Qt.Key_Enter:
                    root.apply();
                    break;
                case Qt.Key_Escape:
                    root.closeDialog();
                    break;
                default:
                    return;
                }
                event.accepted = true;
            }

            // A click beside the panel cancels.
            MouseArea {
                anchors.fill: parent
                onClicked: root.closeDialog()
            }

            Rectangle {
                anchors.centerIn: parent
                width: Math.min(720, parent.width - 32)
                height: Math.min(parent.height - 32, panel.implicitHeight + 40)
                radius: 14
                color: colors.surface
                border.width: 1
                border.color: Qt.alpha(colors.primary, 0.5)
                clip: true

                // Clicks on the panel itself stay here.
                MouseArea {
                    anchors.fill: parent
                }

                ColumnLayout {
                    id: panel

                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        margins: 20
                    }
                    spacing: 6

                    Text {
                        text: root.sizing ? "Change sizes, keeping each font" : "Where do you want to use"
                        color: colors.secondary
                        font.family: root.font
                        font.pixelSize: 14
                    }

                    Text {
                        Layout.fillWidth: true
                        Layout.bottomMargin: 10
                        text: root.sizing ? "Font sizes" : root.choosing
                        color: colors.on_surface
                        font.family: root.sizing ? root.font : root.choosing
                        font.pixelSize: 30
                        elide: Text.ElideRight
                    }

                    Repeater {
                        model: root.asked
                        delegate: PlaceRow {}
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 12
                        spacing: 10

                        Text {
                            Layout.fillWidth: true
                            text: (root.sizing ? "" : "Space ticks  ·  ") + "← → size  ·  Enter applies  ·  Esc cancels"
                            color: Qt.alpha(colors.on_surface, 0.5)
                            font.family: root.font
                            font.pixelSize: 12
                            elide: Text.ElideRight
                        }

                        Chip {
                            text: "Cancel"
                            onClicked: root.closeDialog()
                        }

                        Chip {
                            readonly property int count: root.sizing ? root.resized.length : root.ticked.length

                            text: root.sizing ? (count > 1 ? `Resize ${count} places` : "Resize")
                                : count > 1 ? `Use in ${count} places` : "Use it"
                            on: root.ready
                            enabled: root.ready
                            onClicked: root.apply()
                        }
                    }
                }
            }
        }
    }

    // One font: its name, what it is, where it is in use, and the sample.
    component FontRow: Item {
        id: row

        required property var modelData
        required property int index

        readonly property string family: modelData.family
        readonly property var usedIn: root.usedBy(family)
        readonly property bool current: ListView.isCurrentItem
        readonly property bool lit: hover.hovered || current

        width: ListView.view.width
        height: card.height

        HoverHandler { id: hover }

        Rectangle {
            id: card

            width: parent.width - 10    // clear of the scrollbar
            height: body.implicitHeight + 24
            radius: 10
            color: row.lit ? Qt.alpha(colors.on_surface, 0.07) : Qt.alpha(colors.on_surface, 0.03)
            border.width: 2
            border.color: row.current ? Qt.alpha(colors.primary, 0.6) : "transparent"

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    list.currentIndex = row.index;
                    root.choose(row.family);
                }
            }

            ColumnLayout {
                id: body

                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    margins: 12
                    leftMargin: 16
                    rightMargin: 16
                }
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        Layout.fillWidth: true
                        Layout.maximumWidth: Math.ceil(implicitWidth)
                        Layout.rightMargin: 4
                        text: row.family
                        color: Qt.alpha(colors.on_surface, 0.7)
                        font.family: root.font
                        font.pixelSize: 13
                        elide: Text.ElideRight
                    }

                    Tag {
                        visible: row.modelData.mono
                        text: "Mono"
                    }

                    Tag {
                        visible: row.modelData.icons
                        text: "Nerd Font icons"
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    Repeater {
                        model: row.usedIn

                        Tag {
                            required property var modelData
                            text: modelData.name
                            on: true
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: sample.text || root.defaultSample
                    color: colors.on_surface
                    font.family: row.family
                    font.pixelSize: root.sampleSize
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    text: root.codeSample
                    color: Qt.alpha(colors.on_surface, 0.55)
                    font.family: row.family
                    font.pixelSize: Math.round(root.sampleSize * 0.6)
                    elide: Text.ElideRight
                }
            }
        }
    }

    // One place in the dialog: a tick box (not when sizing), what it is, what
    // it uses now, its size, and when a change shows.
    component PlaceRow: Rectangle {
        id: entry

        required property var modelData
        required property int index

        readonly property bool fits: root.fits(modelData)
        readonly property bool ticked: root.ticked.includes(modelData.id)
        readonly property bool already: !root.sizing && modelData.shows === root.choosing

        Layout.fillWidth: true
        implicitHeight: Math.max(50, line.implicitHeight + 12)
        radius: 8
        color: dialog.cursor === index || over.hovered ? Qt.alpha(colors.on_surface, 0.07) : "transparent"
        opacity: fits ? 1 : 0.4

        HoverHandler {
            id: over
            cursorShape: entry.fits && !root.sizing ? Qt.PointingHandCursor : Qt.ArrowCursor
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                dialog.cursor = entry.index;
                root.toggle(entry.modelData);
            }
        }

        RowLayout {
            id: line

            anchors {
                left: parent.left
                right: parent.right
                leftMargin: 10
                rightMargin: 10
                verticalCenter: parent.verticalCenter
            }
            spacing: 12

            Rectangle {
                visible: !root.sizing
                implicitWidth: 20
                implicitHeight: 20
                radius: 5
                color: entry.ticked ? colors.primary : "transparent"
                border.width: 2
                border.color: entry.ticked ? colors.primary : Qt.alpha(colors.on_surface, 0.4)

                Text {
                    anchors.centerIn: parent
                    visible: entry.ticked
                    text: "✓"
                    color: colors.on_primary
                    font.family: root.font
                    font.pixelSize: 14
                    font.bold: true
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    Layout.fillWidth: true
                    text: `${entry.modelData.name}  <font color="${Qt.alpha(colors.on_surface, 0.5)}">${entry.modelData.app}</font>`
                    textFormat: Text.StyledText
                    color: colors.on_surface
                    font.family: root.font
                    font.pixelSize: 14
                    font.bold: true
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    text: !entry.fits ? "Needs a monospaced font"
                        : entry.already ? "Already uses it" : "Now: " + entry.modelData.now
                    color: entry.already ? colors.primary : Qt.alpha(colors.on_surface, 0.6)
                    font.family: root.font
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }
            }

            Stepper {
                place: entry.modelData
                enabled: entry.fits
            }

            Text {
                Layout.preferredWidth: 150
                horizontalAlignment: Text.AlignRight
                text: entry.modelData.note
                color: Qt.alpha(colors.on_surface, 0.45)
                font.family: root.font
                font.pixelSize: 12
                wrapMode: Text.WordWrap
            }
        }
    }

    // A place's size in the dialog, between − and +, lit once changed. The
    // defaults have no size of their own: each program picks it.
    component Stepper: Item {
        id: stepper

        required property var place
        readonly property var size: root.sizes[place.id]
        readonly property bool changed: size !== undefined && size !== place.size

        implicitWidth: 130
        implicitHeight: 26

        RowLayout {
            anchors.fill: parent
            visible: stepper.place.unit !== ""
            spacing: 4

            Chip {
                text: "−"
                enabled: stepper.enabled && stepper.size > stepper.place.min
                onClicked: root.resize(stepper.place, -1)
            }

            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: `${stepper.size} ${stepper.place.unit}`
                color: stepper.changed ? colors.primary : colors.on_surface
                font.family: root.font
                font.pixelSize: 13
                font.bold: stepper.changed
            }

            Chip {
                text: "+"
                enabled: stepper.enabled && stepper.size < stepper.place.max
                onClicked: root.resize(stepper.place, 1)
            }
        }

        Text {
            anchors.centerIn: parent
            visible: stepper.place.unit === ""
            text: "Font only"
            color: Qt.alpha(colors.on_surface, 0.35)
            font.family: root.font
            font.pixelSize: 12
        }
    }

    // A text box with a hint in it while empty. `key` comes before the box's
    // own handling, so accepting it there keeps a key from the text.
    component Field: Rectangle {
        id: field

        property alias text: input.text
        property alias input: input
        property string placeholder
        signal key(var event)
        signal edited

        implicitHeight: 34
        radius: 8
        color: Qt.alpha(colors.on_surface, 0.06)
        border.width: 1
        border.color: input.activeFocus ? Qt.alpha(colors.primary, 0.7) : Qt.alpha(colors.on_surface, 0.15)

        TextInput {
            id: input

            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            verticalAlignment: TextInput.AlignVCenter
            color: colors.on_surface
            selectionColor: Qt.alpha(colors.primary, 0.45)
            selectedTextColor: colors.on_surface
            font.family: root.font
            font.pixelSize: 14
            selectByMouse: true
            clip: true

            Keys.onPressed: event => field.key(event)
            onTextChanged: field.edited()
        }

        Text {
            anchors.fill: input
            verticalAlignment: Text.AlignVCenter
            visible: !input.text
            text: field.placeholder
            color: Qt.alpha(colors.on_surface, 0.4)
            font: input.font
            elide: Text.ElideRight
        }
    }

    // A small label on a font row.
    component Tag: Rectangle {
        property alias text: label.text
        property bool on: false     // a place using this font, not a property of it

        implicitWidth: label.implicitWidth + 14
        implicitHeight: 20
        radius: 10
        color: on ? colors.primary : Qt.alpha(colors.on_surface, 0.1)

        Text {
            id: label
            anchors.centerIn: parent
            color: parent.on ? colors.on_primary : Qt.alpha(colors.on_surface, 0.75)
            font.family: root.font
            font.pixelSize: 11
            font.bold: true
        }
    }

    // A small pill button; `on` fills it, as for a toggle that is set.
    component Chip: Rectangle {
        id: chip

        property alias text: label.text
        property bool on: false
        signal clicked

        readonly property bool filled: enabled && (on || over.hovered)

        implicitWidth: label.implicitWidth + 20
        implicitHeight: 26
        radius: 13
        opacity: enabled ? 1 : 0.4
        color: filled ? colors.primary : Qt.alpha(colors.surface, 0.85)
        border.width: 1
        border.color: Qt.alpha(colors.primary, 0.6)

        Text {
            id: label
            anchors.centerIn: parent
            color: chip.filled ? colors.on_primary : colors.on_surface
            font.family: root.font
            font.pixelSize: 12
            font.bold: true
        }

        HoverHandler {
            id: over
            cursorShape: chip.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        }

        MouseArea {
            anchors.fill: parent
            enabled: chip.enabled
            onClicked: chip.clicked()
        }
    }
}
