#!/usr/bin/env python3
"""The font picker's hands: reads and writes the font of each place that takes one.

    fonts.py list               the fonts, and what each place uses now
    fonts.py apply JSON         change places: {"terminal": {"family": "X", "size": 12}, ...},
                                either key left out to keep what is there
    fonts.py restore JSON       put places back the way `apply` found them

Each prints one line of JSON. `apply` reports what it replaced, keyed by place,
which is exactly what `restore` takes: that is the picker's Undo. Settings are
kept as the program writes them, so anything beside the family and size stays.
"""

import ast
import json
import os
import re
import signal
import subprocess
import sys
import xml.etree.ElementTree as ET
from pathlib import Path
from xml.sax.saxutils import escape

CONFIG = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config")


def run(*cmd):
    return subprocess.run(cmd, capture_output=True, text=True).stdout.strip()


def resolve(family):
    """The installed family fontconfig draws when asked for this one."""
    return run("fc-match", "--format", "%{family[0]}", family)


def read(path):
    try:
        return Path(path).read_text()
    except FileNotFoundError:
        return ""


# Plain writes, which go through the symlinks into ~/dotfiles rather than
# replacing them.
def write(path, text):
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    Path(path).write_text(text)


def number(text):
    """'10.0' -> 10, '10.5' -> 10.5; None for no size."""
    try:
        n = float(text)
    except (TypeError, ValueError):
        return None
    return int(n) if n.is_integer() else n


def fmt(size):
    return f"{size:g}"


def split_size(desc):
    """'Liberation Mono 11' -> ('Liberation Mono', '11'); None for no size."""
    m = re.fullmatch(r"(.*?)\s+(\d+(?:\.\d+)?)", desc.strip())
    return (m[1], m[2]) if m else (desc.strip(), None)


class Place:
    """Somewhere a font is set. A setting is what the program reads, in
    whatever shape suits the place, or None where nothing is set and the
    program falls back to its own default."""

    id = name = app = note = ""
    mono = False                 # takes monospaced fonts only
    fallback = "sans-serif"      # what is drawn when no family is set
    unit = "pt"                  # "" for a place with no size of its own
    default_size = 11            # the size used when none is set
    limits = (6, 32)

    def get(self):
        raise NotImplementedError

    def put(self, setting):
        raise NotImplementedError

    def family(self, setting):
        return setting

    def size(self, setting):
        return None

    def using(self, setting, family=None, size=None):
        """The setting with a new family and/or size in it, the rest kept."""
        return family or setting

    def reload(self):
        pass

    def describe(self):
        setting = self.get()
        family = self.family(setting)
        asked = family or self.fallback
        shows = resolve(asked)
        now = family or "Not set"
        if shows != asked:
            now += f" (shows as {shows})"
        size = self.size(setting)
        return {"id": self.id, "name": self.name, "app": self.app, "note": self.note,
                "mono": self.mono, "now": now, "shows": shows,
                "size": self.default_size if size is None else size, "unit": self.unit,
                "min": self.limits[0], "max": self.limits[1]}


class Pango(Place):
    """'Family Size' settings, as GTK, rofi and dunst take them."""

    def family(self, setting):
        return setting and split_size(setting)[0]

    def size(self, setting):
        return setting and number(split_size(setting)[1])

    def using(self, setting, family=None, size=None):
        old_family, old_size = split_size(setting) if setting else (self.fallback, None)
        size = fmt(size) if size is not None else old_size or fmt(self.default_size)
        return f"{family or old_family} {size}"


class Split(Place):
    """Family and size on lines of their own: {"family": ..., "size": ...},
    each as written in the file, or None for no such line."""

    def family(self, setting):
        return setting["family"]

    def size(self, setting):
        return number(setting["size"])

    def using(self, setting, family=None, size=None):
        return {"family": family or setting["family"],
                "size": fmt(size) if size is not None else setting["size"]}


class Shell(Split):
    id, name, app = "shell", "Bar & dashboard", "Quickshell"
    note = "Changes at once"
    unit = "px"                  # Qt pixel sizes; the bar is 44 px high
    default_size = 14
    limits = (10, 22)
    path = CONFIG / "quickshell/desktop/Theme.qml"
    font = re.compile(r'^(\s*readonly property string font: )"(.*)"', re.M)
    font_size = re.compile(r"^(\s*readonly property int fontSize: )(\d+)", re.M)

    def get(self):
        text = read(self.path)
        family, size = self.font.search(text), self.font_size.search(text)
        return {"family": family and family[2], "size": size and size[2]}

    def put(self, setting):
        text = read(self.path)
        if setting["family"]:
            text = self.font.sub(lambda m: f'{m[1]}"{setting["family"]}"', text, count=1)
        if setting["size"]:
            # An int property, so no "14.5".
            size = str(round(float(setting["size"])))
            text = self.font_size.sub(lambda m: m[1] + size, text, count=1)
        write(self.path, text)


class Terminal(Split):
    id, name, app = "terminal", "Terminal", "kitty"
    note = "Open windows reload"
    mono = True
    fallback = "monospace"
    path = CONFIG / "kitty/kitty.conf"

    @staticmethod
    def line(key):
        return re.compile(rf"^{key}[ \t]+(.*)$\n?", re.M)

    def get(self):
        text = read(self.path)
        family, size = self.line("font_family").search(text), self.line("font_size").search(text)
        return {"family": family and family[1].strip(), "size": size and size[1].strip()}

    # kitty also takes `family="Name" style=...`.
    def family(self, setting):
        m = setting["family"] and re.match(r'family=(?:"([^"]*)"|(\S+))', setting["family"])
        return (m[1] or m[2]) if m else setting["family"]

    def put(self, setting):
        text = read(self.path)
        text = self.set(text, "font_size", setting["size"])
        # Under font_size, clear of the comment above it.
        text = self.set(text, "font_family", setting["family"], under="font_size")
        write(self.path, text)

    def set(self, text, key, value, under=None):
        line = self.line(key)
        if value is None:
            return line.sub("", text, count=1)
        new = f"{key} {value}\n"
        if line.search(text):
            return line.sub(lambda m: new, text, count=1)
        anchor = under and self.line(under).search(text)
        if anchor:
            head = text[:anchor.end()]
            return head + ("" if head.endswith("\n") else "\n") + new + text[anchor.end():]
        return new + text

    # kitty rereads its config on SIGUSR1, in every window.
    def reload(self):
        for pid in run("pgrep", "-x", "kitty").split():
            os.kill(int(pid), signal.SIGUSR1)


class Launcher(Pango):
    id, name, app = "launcher", "App launcher", "rofi"
    note = "Next time it opens"
    fallback = "mono"            # rofi's own default is "mono 12"
    default_size = 12
    path = CONFIG / "rofi/config.rasi"
    line = re.compile(r'^(\s*font:\s*)"(.*)";[ \t]*\n?', re.M)

    def get(self):
        m = self.line.search(read(self.path))
        return m and m[2]

    def put(self, setting):
        text = read(self.path)
        if setting is None:
            text = self.line.sub("", text, count=1)
        elif self.line.search(text):
            text = self.line.sub(lambda m: f'{m[1]}"{setting}";\n', text, count=1)
        else:
            text = re.sub(r"^configuration\s*\{[ \t]*\n",
                          lambda m: m[0] + f'    font: "{setting}";\n', text, count=1, flags=re.M)
        write(self.path, text)


class Notifications(Pango):
    id, name, app = "notifications", "Notifications", "dunst"
    note = "From the next notification"
    fallback = "monospace"
    default_size = 8
    path = CONFIG / "dunst/dunstrc"
    system = Path("/etc/xdg/dunst/dunstrc")
    line = re.compile(r"^(\s*font\s*=\s*)(.*)$", re.M)

    def get(self):
        m = self.line.search(read(self.path) or read(self.system))
        return m and m[2].strip()

    # dunst reads a single dunstrc, and ignores drop-ins beside any other, so
    # a font of our own takes a whole copy of the system one.
    def put(self, setting):
        if setting is None:
            return
        text = read(self.path)
        if not text:
            text = (f"# Copied from {self.system} by the font picker, to set the font.\n"
                    "# dunst reads only this file now, so make other changes here too.\n\n"
                    + read(self.system))
        if self.line.search(text):
            text = self.line.sub(lambda m: m[1] + setting, text, count=1)
        else:
            text = re.sub(r"^\[global\][ \t]*\n", lambda m: m[0] + f"    font = {setting}\n",
                          text, count=1, flags=re.M)
        write(self.path, text)

    def reload(self):
        run("dunstctl", "reload")


class Gtk(Pango):
    id, name, app = "gtk", "GTK apps", "waypaper, file chooser"
    note = "Open apps change at once"
    key = ("org.gnome.desktop.interface", "font-name")

    # gsettings prints a GVariant string, which reads as a Python one.
    def get(self):
        value = run("gsettings", "get", *self.key)
        return ast.literal_eval(value) if value else None

    def put(self, setting):
        if setting is None:
            run("gsettings", "reset", *self.key)
        else:
            run("gsettings", "set", *self.key, setting)


class FileManager(Place):
    """Qt's built-in KDE theme, which only pcmanfm-qt runs with (its wrapper
    in ~/.local/bin), takes the font from kdeglobals as QFont::toString():
    family, point size, pixel size, then style fields."""

    id, name, app = "files", "File manager", "pcmanfm-qt"
    note = "Next time it starts"
    fallback = "Sans Serif"      # Qt's own default when kdeglobals names none,
    default_size = 9             # at this size
    path = CONFIG / "kdeglobals"
    blank = "{},{},-1,5,50,0,0,0,0,0"
    line = re.compile(r"^font=(.*)\n?", re.M)

    # The [General] group, which runs up to the next group's header.
    def general(self, text):
        m = re.search(r"^\[General\][ \t]*\n(?:(?!\[).*(?:\n|$))*", text, re.M)
        return m and (m.start(), m.end())

    def get(self):
        text = read(self.path)
        span = self.general(text)
        m = span and self.line.search(text, *span)
        return m and m[1].strip()

    def family(self, setting):
        return setting and setting.split(",")[0]

    # -1 when the font was given in pixels instead.
    def size(self, setting):
        size = setting and number(setting.split(",")[1])
        return size if size and size > 0 else None

    def using(self, setting, family=None, size=None):
        fields = (setting or self.blank.format(self.fallback, self.default_size)).split(",")
        if family:
            fields[0] = family
        if size is not None:
            fields[1:3] = [fmt(size), "-1"]
        return ",".join(fields)

    def put(self, setting):
        text = read(self.path)
        span = self.general(text)
        if not span:
            if setting is None:
                return
            text = text.rstrip("\n") + "\n\n[General]\n"
            span = self.general(text)
        start, end = span
        group = text[start:end]
        if setting is None:
            group = self.line.sub("", group, count=1)
        elif self.line.search(group):
            group = self.line.sub(lambda m: f"font={setting}\n", group, count=1)
        else:
            header, _, rest = group.partition("\n")
            group = f"{header}\nfont={setting}\n{rest}"
        write(self.path, text[:start] + group + text[end:])


class Default(Place):
    """What fontconfig hands out for a generic family: the font of anything
    that does not name one. A size is each program's own business."""

    note = "Apps opened from now on"
    unit = ""
    default_size = None
    limits = (None, None)
    path = CONFIG / "fontconfig/conf.d/50-fontpicker.conf"
    generics = ("sans-serif", "monospace")

    def __init__(self, generic, id, name, app, mono=False):
        self.fallback, self.id, self.name, self.app, self.mono = generic, id, name, app, mono

    @classmethod
    def chosen(cls):
        try:
            tree = ET.fromstring(read(cls.path))
        except ET.ParseError:
            return {}
        return {alias.findtext("family"): alias.findtext("prefer/family")
                for alias in tree.iter("alias")}

    def get(self):
        return self.chosen().get(self.fallback)

    def put(self, setting):
        chosen = self.chosen()
        chosen[self.fallback] = setting
        aliases = [f"  <alias>\n    <family>{g}</family>\n"
                   f"    <prefer><family>{escape(chosen[g])}</family></prefer>\n  </alias>\n"
                   for g in self.generics if chosen.get(g)]
        if not aliases:
            self.path.unlink(missing_ok=True)
            return
        write(self.path, '<?xml version="1.0"?>\n'
                         '<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">\n'
                         "<!-- Written by the font picker (~/.config/quickshell/fontpicker). -->\n"
                         "<fontconfig>\n" + "".join(aliases) + "</fontconfig>\n")


PLACES = {p.id: p for p in [
    Shell(),
    Terminal(),
    Launcher(),
    Notifications(),
    Gtk(),
    FileManager(),
    Default("sans-serif", "sans", "Default font", "everything else"),
    Default("monospace", "mono", "Default monospace", "everything else", mono=True),
]}


def fonts():
    """Families that can set English text. That leaves out Noto's hundreds of
    single-script families, which no place here would want."""
    found = {}
    out = run("fc-list", ":lang=en", "--format", "%{family[0]}\t%{spacing}\n")
    for line in out.splitlines():
        family, _, spacing = line.partition("\t")
        # Some monospaced fonts (Noto Sans Mono) don't say so; their names do.
        mono = (spacing.isdigit() and int(spacing) >= 90) or bool(re.search(r"\bMono\b", family))
        found[family] = found.get(family, False) or mono
    return [{"family": f, "mono": mono, "icons": "Nerd Font" in f}
            for f, mono in sorted(found.items(), key=lambda item: item[0].lower())]


def change(settings):
    """Write {place: setting}; returns what each held before, and what failed."""
    before, errors = {}, []
    for id, setting in settings.items():
        place = PLACES[id]
        try:
            before[id] = place.get()
            place.put(setting(before[id]) if callable(setting) else setting)
            place.reload()
        except Exception as e:
            before.pop(id, None)
            errors.append(f"{place.name}: {e}")
    return {"before": before, "errors": errors}


def main(args):
    if args[:1] == ["list"]:
        result = {"fonts": fonts(), "places": [p.describe() for p in PLACES.values()]}
    elif args[:1] == ["apply"] and len(args) == 2:
        asked = json.loads(args[1])
        result = change({id: (lambda s, p=PLACES[id], a=a: p.using(s, a.get("family"), a.get("size")))
                         for id, a in asked.items()})
    elif args[:1] == ["restore"] and len(args) == 2:
        result = change(json.loads(args[1]))
    else:
        sys.exit(__doc__)
    print(json.dumps(result))


if __name__ == "__main__":
    main(sys.argv[1:])
