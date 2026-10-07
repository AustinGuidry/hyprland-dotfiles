pragma Singleton

import Quickshell

// Nerd Font glyphs, by codepoint so the source stays readable. The bar ones
// are the exact glyphs the waybar config used.
Singleton {
    function glyph(cp) { return String.fromCodePoint(cp); }

    readonly property string launcher: glyph(0xF003B)
    readonly property string dashboard: glyph(0xF1104)
    readonly property string cpu: glyph(0xF4BC)
    readonly property string memory: glyph(0xEFC5)
    readonly property string thermometer: glyph(0xF2C9)
    readonly property string sun: glyph(0xF522)
    readonly property string bulb: glyph(0xF0EB)
    readonly property string volumeLow: glyph(0xF026)
    readonly property string volumeHigh: glyph(0xF028)
    readonly property string power: "⏻"

    readonly property string charging: glyph(0xF0084)
    readonly property string plugged: glyph(0xF06A5)
    // Empty to full, ten steps -- waybar's format-icons for the battery.
    readonly property var battery: [0xF007A, 0xF007B, 0xF007C, 0xF007D, 0xF007E,
        0xF007F, 0xF0080, 0xF0081, 0xF0082, 0xF0079].map(glyph)

    // No signal to full signal.
    readonly property var wifi: [0xF092F, 0xF091F, 0xF0922, 0xF0925, 0xF0928].map(glyph)
    readonly property string wifiOff: glyph(0xF092E)
    readonly property string ethernet: glyph(0xF0200)
    readonly property string lock: glyph(0xF033E)

    readonly property string bluetooth: glyph(0xF00AF)
    readonly property string bluetoothConnected: glyph(0xF00B1)
    readonly property string bluetoothOff: glyph(0xF00B2)

    readonly property string browser: glyph(0xF269)
    readonly property string terminal: glyph(0xF120)
    readonly property string folder: glyph(0xF07B)
    readonly property string code: glyph(0xE70C)

    // VPN down, up, and mid-change.
    readonly property string shieldOff: glyph(0xF0499)
    readonly property string shieldOn: glyph(0xF0565)
    readonly property string shieldBusy: glyph(0xF0780)
    readonly property string bolt: glyph(0xF0E7)

    readonly property string search: glyph(0xF002)
    readonly property string chevronLeft: glyph(0xF0141)
    readonly property string chevronRight: glyph(0xF0142)

    function wifiFor(strength) {   // strength: 0..100
        return wifi[Math.max(0, Math.min(4, Math.round(strength / 25)))];
    }
}
