

-------------------
--- AUTOSTART   ---
-------------------

hl.on("hyprland.start", function()
    hl.exec_cmd("/usr/lib/polkit-kde-authentication-agent-1")
    hl.exec_cmd("sleep 1 && waybar")
    hl.exec_cmd("eww daemon")
    hl.exec_cmd("waypaper --restore")
    hl.exec_cmd("wl-paste --watch clipist store")
    hl.exec_cmd("dunst")
    hl.exec_cmd(terminal)
    hl.exec_cmd(browser)
end)
