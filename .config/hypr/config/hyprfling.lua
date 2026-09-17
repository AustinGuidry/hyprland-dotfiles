-----------------
--- HYPRFLING ---
-----------------

-- Throw windows around: https://github.com/AustinGuidry/hyprfling
-- A rebuilt hyprfling.so only takes effect after restarting Hyprland.

hl.plugin.load(os.getenv("HOME") .. "/hyprfling/hyprfling.so")

-- Skipped on the first parse at startup, before the plugin has registered
-- these keys; the plugin's own reload applies them a moment later.
if hl.plugin.fling then
    hl.config({
        plugin = {
            fling = {
                friction  = 1.6,  -- how fast windows lose speed (1/s)
                bounce    = 0.7,  -- speed kept after hitting an edge or window (0-1)
                gravity   = 0,    -- downward pull (px/s^2); try 2500
                min_speed = 400,  -- slower releases just drop the window (px/s)
                max_speed = 6000, -- px/s
                collide   = true, -- flung windows knock other floating windows around
            },
        },
    })
end

-- Fling mode: every window comes loose, plain click-drag throws, Esc puts it back.
-- Checked at keypress so a plugin that failed to load (say, after a Hyprland
-- update without a rebuild) doesn't turn the bind into a Lua error.
hl.bind(mainMod .. " + G", function()
    if hl.plugin.fling then
        hl.plugin.fling.mode()
    end
end)
