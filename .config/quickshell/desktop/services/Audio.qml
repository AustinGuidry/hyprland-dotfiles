pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// Default output device, straight from PipeWire -- no wpctl polling.
Singleton {
    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property bool ready: sink?.audio != null
    readonly property real volume: sink?.audio?.volume ?? 0    // 1.0 = 100%
    readonly property bool muted: sink?.audio?.muted ?? false

    function setVolume(v) {
        if (ready)
            sink.audio.volume = Math.max(0, Math.min(1, v));
    }

    // Node properties (volume, mute) are only live while something tracks them.
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }
}
