

--------------
-- GESTURES --
-------------- 

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Gestures/ --

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
hl.gesture({ fingers = 3, direction = "vertical",   action = "move" })

hl.device({
    name        = "epic-mouse-v1",
    sensitivity = -0.5,
})

-- BRIGHTNESS CONTROLS, LOCAL DEVICE ONLY =--
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl set +5%"),  { device = "at-translated-set-2-keyboard" })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 5%-"),  { device = "at-translated-set-2-keyboard" })