-------------------
--- KEYBINDINGS ---
-------------------

-- Applications

hl.bind(mainMod .. " + T", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + Escape", hl.dsp.exec_cmd(
    "command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch exit"
))

hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + M", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + H", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + O", hl.dsp.exec_cmd("qbittorrent"))
hl.bind(mainMod .. " + C", hl.dsp.exec_cmd("code"))
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd(browser))
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("/home/rguidry/qylock/quickshell-lockscreen/lock.sh"))
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd("waypaper"))

-- Screenshots. Declared as a helper because a submap replaces the whole
-- keymap: without re-binding these inside every submap, Print does nothing
-- while the dashboard or cheatsheet overlay is open.
--
-- `-m active` on output/window mode makes the grab instant (current monitor /
-- focused window) instead of waiting for a mouse click to pick one -- which is
-- what you want from a hotkey, and the only thing that works while an overlay
-- has a keyboard grab. Region stays interactive on purpose.
local function screenshotBinds()
    hl.bind("PRINT", hl.dsp.exec_cmd("hyprshot -m output -m active"))
    hl.bind(mainMod .. " + PRINT", hl.dsp.exec_cmd("hyprshot -m window -m active"))
    hl.bind(mainMod .. " + SHIFT + PRINT", hl.dsp.exec_cmd("hyprshot -m region"))
end

screenshotBinds()

-- Dashboard: mainMod + D toggles it open/closed. Toggling also enters/exits
-- the "dashboard" submap below, so Escape only closes the dashboard while
-- it's actually open -- a bare "Escape" bind would otherwise grab the key
-- compositor-wide and break Escape everywhere else (rofi, vim, browser
-- fullscreen, dialogs...).
local function dashboardToggle()
    return hl.dsp.exec_cmd(os.getenv("HOME") .. "/scripts/toggle-dashboard.sh")
end

hl.bind(mainMod .. " + D", dashboardToggle())

hl.define_submap("dashboard", function()
    hl.bind("Escape", dashboardToggle())
    hl.bind(mainMod .. " + D", dashboardToggle())
    screenshotBinds()
end)

-- Keybind cheatsheet: mainMod + K toggles a centered eww overlay listing every
-- custom bind. Same submap trick as the dashboard so Escape closes it without
-- grabbing Escape compositor-wide.
local function cheatsheetToggle()
    return hl.dsp.exec_cmd(os.getenv("HOME") .. "/scripts/toggle-cheatsheet.sh")
end

hl.bind(mainMod .. " + K", cheatsheetToggle())

hl.define_submap("cheatsheet", function()
    hl.bind("Escape", cheatsheetToggle())
    hl.bind(mainMod .. " + K", cheatsheetToggle())
    screenshotBinds()
end)

-- Window management
hl.bind(mainMod .. " + Q", hl.dsp.window.kill())
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen())
hl.bind(mainMod .. " + SHIFT + P", hl.dsp.window.pseudo())

-- Toggle kitty background transparency on/off (text stays opaque either way)
hl.bind(mainMod .. " + P", hl.dsp.exec_cmd(os.getenv("HOME") .. "/scripts/toggle-kitty-opacity.sh"))

-- Screenshots: bound globally via screenshotBinds() near the top, and again
-- inside each submap so Print keeps working while an overlay is open.

-- Focus movement
hl.bind(mainMod .. " + left", hl.dsp.focus({ direction = "l" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "r" }))
hl.bind(mainMod .. " + up", hl.dsp.focus({ direction = "u" }))
hl.bind(mainMod .. " + down", hl.dsp.focus({ direction = "d" }))

-- Workspace switching + window moving (loop replaces 20 lines)
for i = 1, 10 do
    local key = tostring(i % 10) -- "0" maps to workspace 10
    hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- Special workspace (scratchpad)
hl.bind(mainMod .. " + S", hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

-- Scroll through workspaces with mouse wheel
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

-- Move/resize windows with mouse
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Media / volume keys
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { repeat_key = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { repeat_key = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { repeat_key = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { repeat_key = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), { repeat_key = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), { repeat_key = true })

-- Media playback (locked = works on lockscreen)
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
