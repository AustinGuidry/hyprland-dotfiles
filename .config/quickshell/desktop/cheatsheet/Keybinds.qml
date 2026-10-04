pragma Singleton

import Quickshell

// What the Super+K cheatsheet lists, column by column. Hand-curated, so keep
// it in step with ~/.config/hypr/config/keybinds.lua when binds change.
Singleton {
    readonly property var columns: [
        [
            {
                title: "Applications",
                binds: [
                    ["Super T", "Terminal"],
                    ["Super E", "File manager"],
                    ["Super B", "Browser"],
                    ["Super C", "VS Code"],
                    ["Super H", "App launcher"],
                    ["Super O", "qBittorrent"],
                    ["Super W", "Wallpaper picker"],
                    ["Super L", "Lock screen"],
                    ["Super D", "Dashboard"],
                    ["Super K", "This cheatsheet"],
                    ["Super Esc", "Exit / power menu"],
                ]
            },
        ],
        [
            {
                title: "Windows",
                binds: [
                    ["Super Q", "Close window"],
                    ["Super M", "Toggle floating"],
                    ["Super F", "Fullscreen"],
                    ["Super J", "Toggle split"],
                    ["Super P", "Kitty transparency"],
                    ["Super Shift P", "Pseudo-tile"],
                    ["Super G", "Fling mode"],
                ]
            },
            {
                title: "Screenshots",
                binds: [
                    ["Print", "Whole output"],
                    ["Super Print", "Active window"],
                    ["Super Shift Print", "Region"],
                ]
            },
        ],
        [
            {
                title: "Focus & Workspaces",
                binds: [
                    ["Super Arrows", "Move focus"],
                    ["Super 1 - 0", "Switch workspace"],
                    ["Super Shift 1-0", "Move window to WS"],
                    ["Super S", "Scratchpad"],
                    ["Super Shift S", "Send to scratchpad"],
                    ["Super Scroll", "Cycle workspaces"],
                ]
            },
            {
                title: "Media & Hardware",
                binds: [
                    ["Vol +/- Mute", "Audio volume"],
                    ["Mic Mute", "Toggle microphone"],
                    ["Brightness +/-", "Screen brightness"],
                    ["Play / Pause", "Media playback"],
                    ["Next / Prev", "Change track"],
                ]
            },
        ],
    ]
}
