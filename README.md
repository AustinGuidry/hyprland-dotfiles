# hyprland-dotfiles

My [Hyprland](https://hypr.land) setup on Arch Linux — a Lua-configured compositor
with a wallpaper-driven color scheme that repaints the entire desktop.

![Hyprland desktop](docs/screenshot.png)

## The idea

Everything is themed from one source: the current wallpaper. Pick a new one in
`waypaper`, and [matugen](https://github.com/InioX/matugen) extracts a Material You
palette and regenerates the colors for every component at once — no per-app color
editing, ever.

```
  wallpaper (waypaper)
          │
          ▼
  scripts/wallpaper-changed.sh
          │
          ▼
      matugen
          │
          ├─► hypr/config/colors.lua            window borders
          ├─► quickshell/desktop/colors.json    bar, dashboard, cheatsheet
          └─► rofi/colors.rasi                  launcher
```

The hook doesn't restart anything: the Quickshell shell watches `colors.json` and
recolors itself, fading to the new palette. Meanwhile a ripple spreads from where
you clicked, like a stone dropped in a pond — a screen shader
(`.config/hypr/shaders/ripple.frag`), so it bends the picture rather than drawing
over it. Hyprland spots a pick the moment waypaper records it in its config,
rather than waiting for the hook, so the ripple answers the click and only
wallpaper clicks make one.

The templates in `.config/matugen/templates/` are the only place colors are
authored. Files like `.config/hypr/config/colors.lua` and `.config/waybar/colors.css`
are **generated output** — they're committed so a fresh clone looks right
immediately, but editing them by hand is pointless: the next wallpaper change
overwrites them.

## Layout

| Path | What it is |
|---|---|
| `.config/hypr/hyprland.lua` | Entry point — monitors, env, input; requires the modules below |
| `.config/hypr/config/` | `keybinds`, `look_feel`, `windows_workspaces`, `gestures`, `autostart`, `permissions`, `colors` |
| `.config/hypr/hyprlock.conf` | Lock screen |
| `.config/hypr/hypridle.conf` | Idle → lock → suspend |
| `.config/matugen/` | Color pipeline config + templates |
| `.config/quickshell/desktop/` | Status bar (top, 44px), dashboard and keybind cheatsheet — one [Quickshell](https://quickshell.org) config, run as `qs -c desktop` |
| `.config/waybar/`, `.config/eww/` | The bar and dashboard this replaced, kept around but no longer autostarted |
| `.config/eww-kde/` | Same cheatsheet widget, for KDE Plasma sessions (toggled by `scripts/toggle-kde-cheatsheet.sh`) |
| `.config/rofi/` | Launcher theming |
| `.config/kitty/` | Terminal |
| `.config/waypaper/` | Wallpaper picker; its `post_command` kicks off the pipeline |
| `.config/ashell/` | Alternative bar, kept around but not currently autostarted |
| `scripts/` | Wallpaper hook, brightness clamp, AirPods pairing helper |

Hyprland is configured in **Lua**, not hyprlang — this needs Hyprland 0.55+.
`hyprland.lua` is the entry point and `require()`s each module under `config/`.

## Keybinds

`SUPER` is the mod key.

| Key | Action |
|---|---|
| `SUPER` + `T` | Terminal (kitty) |
| `SUPER` + `B` | Browser |
| `SUPER` + `E` | Files (nautilus) |
| `SUPER` + `H` | Launcher (rofi) |
| `SUPER` + `D` | Toggle dashboard |
| `SUPER` + `K` | Toggle keybind cheatsheet |
| `SUPER` + `W` | Wallpaper picker → retheme |
| `SUPER` + `L` | Lock |
| `SUPER` + `Q` | Close window |
| `SUPER` + `F` | Fullscreen |
| `SUPER` + `M` | Toggle floating |
| `SUPER` + `J` | Toggle split direction |
| `SUPER` + `1`–`0` | Switch to the Nth workspace (past the last opens a new one) |
| `SUPER` + `SHIFT` + `1`–`0` | Move window to the Nth workspace |
| `SUPER` + `S` | Scratchpad |
| `SUPER` + `Escape` | Shutdown menu |
| `Print` | Screenshot output |
| `SUPER` + `Print` | Screenshot window |
| `SUPER` + `SHIFT` + `Print` | Screenshot region |

Mouse: `SUPER` + drag to move, `SUPER` + right-drag to resize, `SUPER` + wheel to
cycle workspaces.

## Install

```bash
git clone git@github.com:AustinGuidry/hyprland-dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

`install.sh` symlinks each directory into `$HOME`. Anything already there is moved
to `~/.dotfiles-backup/<timestamp>/` first, so it's safe to run on a live system.

Then reload: `hyprctl reload`

### Dependencies

```bash
# core
sudo pacman -S hyprland hyprlock hypridle waybar rofi kitty \
               brightnessctl playerctl wireplumber dunst nautilus jq \
               polkit-kde-agent swaybg nwg-menu papirus-icon-theme

# AUR
paru -S matugen-bin waypaper hyprshot eww quickshell-git \
        networkmanager-dmenu rofi-bluetooth clipist
```

The lock screen shells out to [qylock](https://github.com/Darkkal44/qylock), which
lives outside this repo — clone it to `~/qylock` or repoint the bind in
`.config/hypr/config/keybinds.lua`.

### Worth editing after cloning

- `.config/hypr/hyprland.lua` — the monitor block is hardcoded to `eDP-1` at 1920x1080
- `.config/hypr/hyprlock.conf` and `.config/hypr/hyprlock/colors.conf` — absolute
  wallpaper paths; point them at your own
- `.config/waypaper/config.ini` — wallpaper folder

## Regenerating colors by hand

```bash
matugen image ~/Pictures/Wallpapers/your.jpg --prefer=saturation
```

The `--prefer=saturation` flag matters. Without any preference, matugen 4.x fails
non-interactively with *"Multiple source colors found, no preference was inputted,
and a terminal was not detected"* — which is exactly how the wallpaper hook runs.
`--prefer=saturation` is what `scripts/wallpaper-changed.sh` passes, so the command
above reproduces the automatic behaviour exactly.

Don't combine it with `--source-color-index`: that flag **silently takes precedence**
and the `--prefer` value is ignored entirely. They're alternatives, not complements —
`--source-color-index 0` picks the most *dominant* color while `--prefer=saturation`
picks the most *saturated* one, and they disagree on roughly half of a typical
wallpaper collection, so the override is easy to miss.
