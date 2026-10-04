pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Palette and metrics for the whole shell.
//
// Colors come from colors.json, which matugen regenerates on every wallpaper
// change (template: ~/.config/matugen/templates/quickshell/colors.json). The
// file is watched, so the shell recolors in place -- unlike waybar, nothing
// has to be restarted.
Singleton {
    id: root

    // A new palette fades in over this long rather than snapping.
    readonly property int recolorDuration: 900

    // False until colors.json has loaded once, so startup takes the palette as
    // it is instead of fading in from the fallback values below.
    property bool live: false

    // Not readonly: a Behavior can't be attached to a readonly property.
    property color primary: json.primary
    property color secondary: json.secondary
    property color surface: json.surface
    property color primaryContrast: json.on_primary
    property color text: json.on_surface

    Behavior on primary { enabled: root.live; ColorAnimation { duration: root.recolorDuration } }
    Behavior on secondary { enabled: root.live; ColorAnimation { duration: root.recolorDuration } }
    Behavior on surface { enabled: root.live; ColorAnimation { duration: root.recolorDuration } }
    Behavior on primaryContrast { enabled: root.live; ColorAnimation { duration: root.recolorDuration } }
    Behavior on text { enabled: root.live; ColorAnimation { duration: root.recolorDuration } }

    // Fixed alert colors, carried over from the waybar stylesheet.
    readonly property color critical: "#6b1a1a"
    readonly property color criticalText: "#ffaaaa"
    readonly property color urgent: "#8b2020"

    readonly property string font: "JetBrainsMono Nerd Font"
    readonly property int fontSize: 15
    readonly property int barHeight: 44
    readonly property int radius: 6

    FileView {
        path: Quickshell.shellPath("colors.json")
        watchChanges: true
        onFileChanged: reload()
        onLoaded: Qt.callLater(() => root.live = true)

        JsonAdapter {
            id: json

            property string primary: "#90d5ae"
            property string secondary: "#b4ccbc"
            property string surface: "#0f1511"
            property string on_primary: "#003823"
            property string on_surface: "#dee4de"
        }
    }
}
