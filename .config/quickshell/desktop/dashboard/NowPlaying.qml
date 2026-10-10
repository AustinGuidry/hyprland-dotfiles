import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import Quickshell.Widgets
import qs
import qs.services

// "Now playing" island at the foot of the dashboard, after the iPhone's
// Dynamic Island: cover, title, a scrubber and transport buttons for the
// player Media picked. Takes up no room when nothing has a track loaded.
// It has no background of its own, so it sits on the card like the rows above.
Item {
    id: island

    // Whether the dashboard is open; nothing here animates or polls otherwise.
    property bool active: false

    readonly property MprisPlayer player: Media.player
    readonly property bool playing: player?.isPlaying ?? false
    readonly property real length: player?.lengthSupported ? player.length : 0
    readonly property real position: player?.positionSupported ? player.position : 0

    function clock(seconds) {
        const s = Math.max(0, Math.floor(seconds));
        const mm = Math.floor(s / 60) % 60;
        const ss = String(s % 60).padStart(2, "0");
        return s >= 3600 ? `${Math.floor(s / 3600)}:${String(mm).padStart(2, "0")}:${ss}` : `${mm}:${ss}`;
    }

    visible: player !== null && (playing || player.trackTitle !== "")
    implicitHeight: body.implicitHeight

    // MprisPlayer.position only moves when it is asked to.
    Timer {
        interval: 1000
        running: island.active && island.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: island.player.positionChanged()
    }

    ColumnLayout {
        id: body

        anchors.fill: parent
        spacing: 8

        // Cover, title over artist, equalizer
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            ClippingRectangle {
                implicitWidth: 44
                implicitHeight: 44
                radius: 10
                color: Theme.primaryContrast

                Text {
                    anchors.centerIn: parent
                    visible: cover.status !== Image.Ready
                    text: Icons.music
                    color: Theme.primary
                    font.family: Theme.font
                    font.pixelSize: 22
                }
                Image {
                    id: cover
                    anchors.fill: parent
                    source: island.player?.trackArtUrl ?? ""
                    sourceSize.width: 128
                    sourceSize.height: 128
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                // A title too long for the row scrolls to its end and back.
                Item {
                    id: marquee

                    readonly property real overflow: Math.max(0, title.implicitWidth - width)

                    Layout.fillWidth: true
                    implicitHeight: title.implicitHeight
                    clip: true

                    Text {
                        id: title

                        text: island.player?.trackTitle || "Unknown title"
                        color: Theme.text
                        font.family: Theme.font
                        font.pixelSize: 13
                        font.bold: true
                        // Distances are fixed when the animation starts, so a
                        // new title has to start it over.
                        onTextChanged: {
                            x = 0;
                            if (scroll.running)
                                scroll.restart();
                        }

                        SequentialAnimation on x {
                            id: scroll

                            running: island.active && marquee.overflow > 0
                            loops: Animation.Infinite
                            onStopped: title.x = 0

                            PauseAnimation { duration: 2000 }
                            NumberAnimation { to: -marquee.overflow; duration: marquee.overflow * 30 }
                            PauseAnimation { duration: 2000 }
                            NumberAnimation { to: 0; duration: marquee.overflow * 30 }
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: island.player?.trackArtist || island.player?.identity || ""
                    elide: Text.ElideRight
                    color: Qt.alpha(Theme.text, 0.6)
                    font.family: Theme.font
                    font.pixelSize: 12
                }
            }

            // Bars bounce while playing and sit flat while paused.
            Item {
                implicitWidth: 18
                implicitHeight: 16

                Repeater {
                    // Milliseconds per swing; uneven so the bars drift apart.
                    model: [520, 380, 610, 450]

                    Rectangle {
                        id: bar

                        required property int modelData
                        required property int index

                        x: index * 5
                        anchors.verticalCenter: parent.verticalCenter
                        width: 3
                        height: 4
                        radius: 1.5
                        color: Theme.primary

                        SequentialAnimation on height {
                            running: island.active && island.playing
                            loops: Animation.Infinite
                            onStopped: bar.height = 4

                            NumberAnimation { to: 16; duration: bar.modelData; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 4; duration: bar.modelData; easing.type: Easing.InOutSine }
                        }
                    }
                }
            }
        }

        // Elapsed, scrubber, remaining. Streams have no length and no row.
        RowLayout {
            Layout.fillWidth: true
            visible: island.length > 0
            spacing: 8

            Stamp {
                text: island.clock(island.position)
            }

            Item {
                Layout.fillWidth: true
                implicitHeight: 14

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 4
                    radius: 2
                    color: Qt.alpha(Theme.text, 0.15)

                    Rectangle {
                        width: parent.width * Math.min(1, island.position / island.length)
                        height: parent.height
                        radius: 2
                        color: Theme.primary
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: island.player?.canSeek ?? false
                    cursorShape: Qt.PointingHandCursor
                    onClicked: e => island.player.position = e.x / width * island.length
                }
            }

            Stamp {
                text: "-" + island.clock(island.length - island.position)
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 28

            Control {
                icon: Icons.skipPrevious
                enabled: island.player?.canGoPrevious ?? false
                onClicked: island.player.previous()
            }
            Control {
                icon: island.playing ? Icons.pause : Icons.play
                size: 28
                enabled: island.player?.canTogglePlaying ?? false
                onClicked: island.player.togglePlaying()
            }
            Control {
                icon: Icons.skipNext
                enabled: island.player?.canGoNext ?? false
                onClicked: island.player.next()
            }
        }
    }

    component Stamp: Text {
        color: Qt.alpha(Theme.text, 0.6)
        font.family: Theme.font
        font.pixelSize: 11
    }

    // A transport glyph; dimmed when the player can't do that.
    component Control: Text {
        id: control

        property string icon
        property int size: 22
        signal clicked()

        text: icon
        color: hover.containsMouse ? Theme.primary : Theme.text
        opacity: enabled ? 1 : 0.3
        font.family: Theme.font
        font.pixelSize: size

        MouseArea {
            id: hover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: control.clicked()
        }
    }
}
