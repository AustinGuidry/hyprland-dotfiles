

-------------------
--- AUTOSTART   ---
-------------------

hl.on("hyprland.start", function()
    -- No systemd user session here (OpenRC), so nothing hands the session's
    -- environment to D-Bus-activated services unless this does.
    hl.exec_cmd("dbus-update-activation-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE")
    hl.exec_cmd("fcitx5 -d")
    hl.exec_cmd("/usr/libexec/hyprpolkitagent")
    hl.exec_cmd("qs -c desktop") -- bar, dashboard, cheatsheet: ~/.config/quickshell/desktop
    hl.exec_cmd("waypaper --restore")
    hl.exec_cmd("wl-paste --watch cliphist store")
    hl.exec_cmd("dunst")
    hl.exec_cmd("hypridle") -- a systemd user unit on Arch; nothing else starts it here
    hl.exec_cmd(os.getenv("HOME") .. "/scripts/battery-log.sh") -- battery voltage/charge log: ~/.local/state/battery/log.csv
    hl.exec_cmd("brightnessctl -d smc::kbd_backlight set 30%") -- keyboard backlight boots at 0
    hl.exec_cmd(terminal)
    hl.exec_cmd(browser)
end)
