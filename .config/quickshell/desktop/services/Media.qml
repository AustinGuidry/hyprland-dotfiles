pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// The MPRIS player worth showing. Whatever is playing wins; once it pauses it
// stays picked, so pausing one player doesn't hand the controls to another.
Singleton {
    readonly property MprisPlayer playing: Mpris.players.values.find(p => p.isPlaying) ?? null
    property MprisPlayer last: null

    readonly property MprisPlayer player: playing
        ?? (Mpris.players.values.includes(last) ? last : Mpris.players.values[0] ?? null)

    onPlayingChanged: if (playing) last = playing
}
