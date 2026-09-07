-- =============================================================================
-- hyprland.lua — Full Lua config (Hyprland 0.55+)
-- https://wiki.hypr.land/Configuring/Start/
-- =============================================================================

-----------------
--- PROGRAMS  ---
-----------------

terminal    = "kitty"
fileManager = "nautilus"
menu        = "hyprlauncher"
browser     = "brave-origin-beta"
mainMod     = "SUPER"

----------------------------------
--- MODULES OF HYPRLAND CONFIG ---
----------------------------------

require("config.colors") -- COLORS --
require("config.keybinds") -- KEYBINDS --
require("config.look_feel") -- LOOK AND FEEL --
require("config.permissions") -- PERMISSIONS --
require("config.windows_workspaces") -- WINDOWS AND WORKSPACES --
require("config.gestures") -- GESTURES
require("config.autostart") -- AUTOSTART
require("config.colors") -- COLORS

----------------
--- MONITORS ---
----------------

hl.monitor({
    output   = "eDP-1",
    mode     = "1920x1080@60",
    position = "0x0",
    scale    = 1,
})

-----------------------------
--- ENVIRONMENT VARIABLES ---
-----------------------------

hl.env("XCURSOR_SIZE",    "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("HYPRSHOT_DIR",    os.getenv("HOME") .. "/Pictures/Screenshots")

-----------
--- INPUT ---
-----------

hl.config({
    input = {
        kb_layout    = "us",
        follow_mouse = 1,
        sensitivity  = 0,
        touchpad = {
            natural_scroll = false,
        },
    },
})
