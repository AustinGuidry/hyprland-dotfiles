-- =============================================================================
-- hyprland.lua — Full Lua config (Hyprland 0.55+)
-- https://wiki.hypr.land/Configuring/Start/
-- =============================================================================

-----------------
--- PROGRAMS  ---
-----------------

terminal    = "kitty"
fileManager = "pcmanfm-qt"
menu        = "rofi -show drun"
browser     = "brave-browser-stable"
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
require("config.hyprfling") -- HYPRFLING
require("config.colors") -- COLORS

----------------
--- MONITORS ---
----------------

hl.monitor({
    output   = "eDP-1",
    mode     = "2560x1600@60",
    position = "0x0",
    scale    = 1.6,
})

-----------------------------
--- ENVIRONMENT VARIABLES ---
-----------------------------

hl.env("XCURSOR_SIZE",    "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("HYPRSHOT_DIR",    os.getenv("HOME") .. "/Pictures/Screenshots")

hl.env("QT_IM_MODULE",  "fcitx")
hl.env("XMODIFIERS",    "@im=fcitx")
hl.env("SDL_IM_MODULE", "fcitx")

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
