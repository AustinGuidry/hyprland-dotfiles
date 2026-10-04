-- =============================================================================
-- look_feel.lua — Full Lua config (Hyprland 0.55+)
-- https://wiki.hypr.land/Configuring/Start/
-- =============================================================================

-----------------
--- LOOK & FEEL ---
-----------------

require("config.colors")

hl.config({
    general = {
        gaps_in      = 5,
        gaps_out     = 20,
        border_size  = 3,
        col = {
            active_border   = { colors = {primary .. "ee", secondary .. "ee"}, angle = 45 },
            inactive_border = surface .. "aa",
        },
        resize_on_border = false,
        allow_tearing    = false,
        layout           = "dwindle",
    },

    decoration = {
        rounding         = 10,
        rounding_power   = 2,
        active_opacity   = 1.0,
        inactive_opacity = 1.0,
        shadow = {
            enabled      = true,
            range        = 4,
            render_power = 3,
            color        = "rgba(1a1a1aee)",
        },
        blur = {
            enabled  = true,
            size     = 3,
            passes   = 1,
            vibrancy = 0.1696,
        },
    },

    dwindle = {
        preserve_split = true,
    },

    master = {
        new_status = "master",
    },

    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo   = true,
    },
})

-- Bezier curves
hl.curve("easeOutQuint",   { type = "bezier", points = { {0.23, 1},    {0.32, 1}   } })
hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1}   } })
hl.curve("linear",         { type = "bezier", points = { {0, 0},       {1, 1}      } })
hl.curve("almostLinear",   { type = "bezier", points = { {0.5, 0.5},   {0.75, 1}   } })
hl.curve("quick",          { type = "bezier", points = { {0.15, 0},    {0.1, 1}    } })

-- Animations
hl.animation({ leaf = "global",        enabled = true,  speed = 10,   bezier = "default"       })
hl.animation({ leaf = "border",        enabled = true,  speed = 5.39, bezier = "easeOutQuint"  })
hl.animation({ leaf = "windows",       enabled = true,  speed = 4.79, bezier = "easeOutQuint"  })
hl.animation({ leaf = "windowsIn",     enabled = true,  speed = 4.1,  bezier = "easeOutQuint", style = "popin 87%" })
hl.animation({ leaf = "windowsOut",    enabled = true,  speed = 1.49, bezier = "linear",       style = "popin 87%" })
hl.animation({ leaf = "fadeIn",        enabled = true,  speed = 1.73, bezier = "almostLinear"  })
hl.animation({ leaf = "fadeOut",       enabled = true,  speed = 1.46, bezier = "almostLinear"  })
hl.animation({ leaf = "fade",          enabled = true,  speed = 3.03, bezier = "quick"         })
hl.animation({ leaf = "layers",        enabled = true,  speed = 3.81, bezier = "easeOutQuint"  })
hl.animation({ leaf = "layersIn",      enabled = true,  speed = 4,    bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true,  speed = 1.5,  bezier = "linear",       style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true,  speed = 1.79, bezier = "almostLinear"  })
hl.animation({ leaf = "fadeLayersOut", enabled = true,  speed = 1.39, bezier = "almostLinear"  })
hl.animation({ leaf = "workspaces",    enabled = true,  speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesIn",  enabled = true,  speed = 1.21, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true,  speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "zoomFactor",    enabled = true,  speed = 7,    bezier = "quick"         })

-- Wallpaper-change ripple: a stone dropped in a pond where you clicked to pick
-- a wallpaper. It is a screen shader (shaders/ripple.frag), so it bends what
-- is on screen rather than drawing over it, and it times each ripple off the
-- click itself. The job here is telling a wallpaper click from any other:
--
--   * The picker runs its hook a quarter-second after the click, too late to
--     answer it. But it writes the wallpaper it was told to set into its
--     config file at once, so while it has focus that file is read fifty
--     times a second.
--   * When the wallpaper named there changes, the shader goes on for a few
--     seconds with the spot the cursor was on baked in, and ripples the click
--     made there. Other clicks -- the picker's buttons, other windows -- match
--     nothing and do nothing.
--
-- The shader needs Hyprland to redraw every frame and to be told about clicks,
-- both of which only happen with damage tracking off -- so that is off for as
-- long as the shader is on, and put back after.
local ripple_picker = "waypaper" -- window class of the wallpaper picker
local ripple_config = os.getenv("HOME") .. "/.config/waypaper/config.ini"
local ripple_window = 3.8 -- seconds the shader stays on per pick: its DELAY and LIFE plus most of a second
local ripple_note = os.getenv("XDG_RUNTIME_DIR") .. "/hypr-ripple.note"
local ripple_runs = 0
local ripple_saved -- config to put back afterwards; nil while the shader is off
local ripple_watch -- timer that reads the picker's config while it has focus
local ripple_chosen -- the wallpaper named there at the last look
local ripple_trail = {} -- where the cursor was at the last few looks
local ripple_till = 0 -- uptime at which the shader goes off
local ripple_picks = {} -- picks still rippling: { at = uptime, monitor = id, x = px, y = px }

-- Seconds since boot, to the hundredth; os.time() only counts whole seconds.
local function uptime()
    local f = io.open("/proc/uptime")
    local seconds = f:read("n")
    f:close()
    return seconds
end

local function picking()
    local win = hl.get_active_window()
    return win ~= nil and win.class == ripple_picker
end

-- The wallpaper the picker has on record, or nil if its config is missing or
-- caught half-written.
local function chosen()
    local f = io.open(ripple_config)
    if not f then
        return nil
    end
    local text = f:read("a")
    f:close()
    return text:match("\nwallpaper = (.-)\n%S")
end

-- Switch the shader on, or on again, for the picks on record.
local function show_ripple()
    local now = uptime()
    local newest = ripple_picks[#ripple_picks]
    local template = newest and now < ripple_till and io.open(os.getenv("HOME") .. "/.config/hypr/shaders/ripple.frag")
    if not template then
        return
    end
    local picks = {}
    for i = #ripple_picks, 1, -1 do
        local pick = ripple_picks[i]
        if pick.monitor == newest.monitor and #picks < 4 then
            picks[#picks + 1] = string.format("vec3(%.1f, %.1f, %.2f)", pick.x, pick.y, now - pick.at)
        end
    end
    while #picks < 4 do
        picks[#picks + 1] = "vec3(0.0, 0.0, 1e6)" -- matches no click
    end
    local source = template:read("a"):gsub("@(%u+)@", {
        MONITOR = newest.monitor,
        LEFT    = string.format("%.2f", ripple_till - now),
        PICKS   = table.concat(picks, ", "),
    })
    template:close()

    -- A new path each time: setting the same one again would not reload it.
    ripple_runs = ripple_runs + 1
    local run = ripple_runs
    local path = string.format("%s/hypr-ripple-%d.frag", os.getenv("XDG_RUNTIME_DIR"), run % 2)
    local out = io.open(path, "w")
    out:write(source)
    out:close()

    -- A config reload wipes the shader and this state with it, and one lands in
    -- the middle of every ripple: matugen rewrites colors.lua, which Hyprland
    -- reloads on. This note is how the fresh config carries on.
    local note = io.open(ripple_note, "w")
    note:write(string.format("%.2f", ripple_till))
    for _, pick in ipairs(ripple_picks) do
        note:write(string.format(" %.2f,%d,%.1f,%.1f", pick.at, pick.monitor, pick.x, pick.y))
    end
    note:close()

    ripple_saved = ripple_saved or {
        shader = hl.get_config("decoration.screen_shader"),
        damage = hl.get_config("debug.damage_tracking"),
    }
    hl.timer(function()
        if run ~= ripple_runs then
            return -- switched on again since; that one will tidy up
        end
        hl.config({ decoration = { screen_shader = ripple_saved.shader } })
        hl.config({ debug = { damage_tracking = ripple_saved.damage } })
        ripple_saved, ripple_picks = nil, {}
    end, { timeout = math.max(1, math.floor((ripple_till - now) * 1000)), type = "oneshot" })

    hl.config({ debug = { damage_tracking = 0 } })
    hl.config({ decoration = { screen_shader = path } })
end

-- One look at the picker's config. A change of wallpaper there is a pick.
local function watch_picker()
    if not picking() then
        ripple_watch:set_enabled(false)
        return
    end
    -- The picker acts when the button comes back up, and by the time that
    -- shows here the cursor may be on its way elsewhere. Three looks ago the
    -- button was still down, or only just up.
    table.insert(ripple_trail, hl.get_cursor_pos())
    if #ripple_trail > 4 then
        table.remove(ripple_trail, 1)
    end
    local cursor = ripple_trail[1]

    local wallpaper = chosen()
    if not wallpaper or wallpaper == ripple_chosen then
        return
    end
    local known = ripple_chosen ~= nil
    ripple_chosen = wallpaper
    local mon = hl.get_monitor_at_cursor()
    if not (known and cursor and mon) then
        return
    end

    local now = uptime()
    for i = #ripple_picks, 1, -1 do
        if now - ripple_picks[i].at > ripple_window then
            table.remove(ripple_picks, i)
        end
    end
    ripple_picks[#ripple_picks + 1] = {
        at = now,
        monitor = mon.id,
        x = (cursor.x - mon.x) * mon.scale,
        y = (cursor.y - mon.y) * mon.scale,
    }
    ripple_till = now + ripple_window
    show_ripple()
end

ripple_watch = hl.timer(watch_picker, { timeout = 20, type = "repeat" })
ripple_watch:set_enabled(false)

-- Start watching when the picker gets focus, from whatever wallpaper it has
-- on record then. watch_picker stops itself once focus has gone.
local function follow_picker()
    if picking() and not ripple_watch:is_enabled() then
        ripple_chosen, ripple_trail = chosen() or ripple_chosen, {}
        ripple_watch:set_enabled(true)
    end
end

hl.on("window.active", follow_picker)

-- Carry on after a reload (see the note in show_ripple). Guarded, because an
-- error here would stop the rest of the config loading.
pcall(function()
    local note = io.open(ripple_note)
    if note then
        local text = note:read("a")
        note:close()
        ripple_till = tonumber(text:match("^%S+")) or 0
        for at, monitor, x, y in text:gmatch(" ([%d.]+),(%-?%d+),([%d.%-]+),([%d.%-]+)") do
            ripple_picks[#ripple_picks + 1] = { at = tonumber(at), monitor = tonumber(monitor), x = tonumber(x), y = tonumber(y) }
        end
        show_ripple()
    end
    follow_picker()
end)
