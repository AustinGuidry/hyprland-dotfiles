

-------------------
--- AUTOSTART   ---
-------------------

hl.on("hyprland.start", function()
    hl.exec_cmd("fcitx5 -d")
    hl.exec_cmd("/usr/lib/polkit-kde-authentication-agent-1")
    hl.exec_cmd("qs -c desktop") -- bar, dashboard, cheatsheet: ~/.config/quickshell/desktop
    hl.exec_cmd("waypaper --restore")
    hl.exec_cmd("wl-paste --watch clipist store")
    hl.exec_cmd("dunst")
    hl.exec_cmd(terminal)
    hl.exec_cmd(browser)
end)
