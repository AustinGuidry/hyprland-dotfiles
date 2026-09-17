------------------------------
--- WINDOWS AND WORKSPACES ---
------------------------------

hl.window_rule({
    name  = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})

hl.window_rule({
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },
    no_focus = true,
})

hl.window_rule({
    name  = "move-hyprland-run",
    match = { class = "hyprland-run" },
    move  = "20 monitor_h-120",
    float = true,
})

-- Terminal transparency is handled inside kitty itself (background_opacity in
-- ~/.config/kitty/kitty.conf), not with a Hyprland opacity rule. A Hyprland
-- rule dims the whole window -- glyphs included -- which wrecks readability;
-- kitty's background_opacity dims only the background and keeps text crisp.
-- SUPER+P toggles it between the configured value and fully opaque for reading
-- long text / playing terminal games (see ~/scripts/toggle-kitty-opacity.sh).
