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
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.local/share/quickshell-lockscreen/lock.sh"))
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd("waypaper"))

-- Screenshots. `-m active` on output/window mode makes the grab instant
-- (current monitor / focused window) instead of waiting for a mouse click to
-- pick one -- which is what you want from a hotkey, and the only thing that
-- works while an overlay has a keyboard grab. Region stays interactive on
-- purpose.
hl.bind("PRINT", hl.dsp.exec_cmd("hyprshot -m output -m active"))
hl.bind(mainMod .. " + PRINT", hl.dsp.exec_cmd("hyprshot -m window -m active"))
hl.bind(mainMod .. " + SHIFT + PRINT", hl.dsp.exec_cmd("hyprshot -m region"))
-- The same on P, for a keyboard with no Print key (a MacBook's, say).
hl.bind(mainMod .. " + P", hl.dsp.exec_cmd("hyprshot -m output -m active"))
hl.bind(mainMod .. " + SHIFT + P", hl.dsp.exec_cmd("hyprshot -m region"))

-- Dashboard (mainMod + D) and keybind cheatsheet (mainMod + K) are Quickshell
-- overlays (~/.config/quickshell/desktop), bound as global shortcuts the shell
-- registers. Each overlay closes itself on Escape or a click outside, so there
-- is no submap juggling: Escape is only theirs while one is open, and every
-- other bind keeps working meanwhile.
hl.bind(mainMod .. " + D", hl.dsp.global("quickshell:dashboard"))
hl.bind(mainMod .. " + K", hl.dsp.global("quickshell:cheatsheet"))

-- Window management
hl.bind(mainMod .. " + Q", hl.dsp.window.kill())
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen())
hl.bind(mainMod .. " + SHIFT + M", hl.dsp.window.pseudo())

-- Toggle kitty background transparency on/off (text stays opaque either way)
hl.bind(mainMod .. " + SHIFT + T", hl.dsp.exec_cmd(os.getenv("HOME") .. "/scripts/toggle-kitty-opacity.sh"))

-- Focus movement
hl.bind(mainMod .. " + left", hl.dsp.focus({ direction = "l" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "r" }))
hl.bind(mainMod .. " + up", hl.dsp.focus({ direction = "u" }))
hl.bind(mainMod .. " + down", hl.dsp.focus({ direction = "d" }))

-- Workspace switching + window moving. The number is a position, not an id:
-- SUPER+3 is the third workspace that exists, and anything past the end opens
-- a new one after the last. Hyprland's own ids are sticky (close everything on
-- 1-6 and the survivor is still 7), so the bar numbers workspaces by position
-- too (quickshell/desktop/bar/Workspaces.qml) and the keys match what it shows.
local function nth_workspace(n)
    local ids = {}
    for _, ws in ipairs(hl.get_workspaces()) do
        if ws.id > 0 then -- special and named workspaces have negative ids
            ids[#ids + 1] = ws.id
        end
    end
    table.sort(ids)
    return ids[n] or (ids[#ids] or 0) + 1
end

for i = 1, 10 do
    local key = tostring(i % 10) -- "0" is the tenth
    hl.bind(mainMod .. " + " .. key, function()
        hl.dispatch(hl.dsp.focus({ workspace = nth_workspace(i) }))
    end)
    hl.bind(mainMod .. " + SHIFT + " .. key, function()
        hl.dispatch(hl.dsp.window.move({ workspace = nth_workspace(i) }))
    end)
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
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { repeating = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { repeating = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), { repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), { repeating = true })
hl.bind("XF86KbdBrightnessUp", hl.dsp.exec_cmd("brightnessctl -d smc::kbd_backlight set 10%+"), { repeating = true })
hl.bind("XF86KbdBrightnessDown", hl.dsp.exec_cmd("brightnessctl -d smc::kbd_backlight set 10%-"), { repeating = true })

-- Media playback (locked = works on lockscreen)
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
