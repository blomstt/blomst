"""Reads and writes the real config files behind the settings window.

No Qt in here on purpose: everything in this file can be tested from a terminal.
"""
import json
import os
import re
import shutil
import subprocess

HOME = os.path.expanduser("~")
CONFIG = os.environ.get("XDG_CONFIG_HOME", os.path.join(HOME, ".config"))

APPEARANCE = os.path.join(CONFIG, "hypr/core/appearence.conf")
ANIMATIONS = os.path.join(CONFIG, "hypr/core/animations.conf")
KITTY = os.path.join(CONFIG, "kitty/kitty.conf")
COLORS = os.path.join(CONFIG, "eww/colors.scss")
HYPRPAPER = os.path.join(CONFIG, "hypr/service/hyprpaper.conf")
WALLPAPER_SCRIPT = os.path.join(CONFIG, "eww/scripts/change-wallpaper.sh")
WALLPAPERS = os.path.join(HOME, "wallpapers")
PRESETS = os.path.join(CONFIG, "blomst-settings/presets.json")
HYPRIDLE = os.path.join(CONFIG, "hypr/hypridle.conf")
HYPRLAND = os.path.join(CONFIG, "hypr/hyprland.conf")
EWW_SETTINGS = os.path.join(CONFIG, "eww/settings.yuck")
APP_RULES_CONF = os.path.join(CONFIG, "hypr/user/app-rules.conf")
APP_RULES_JSON = os.path.join(CONFIG, "blomst-settings/app-rules.json")
APPS_CONF = os.path.join(CONFIG, "hypr/user/apps.conf")
FLOAT_OPTIONS = os.path.join(CONFIG, "blomst-settings/float-options.json")   # read by ~/scripts/float_sizes.py
FLOAT_KEYS = {"float_size": "size", "float_position": "position"}
NOTIF_OPTIONS = os.path.join(CONFIG, "blomst-settings/notifications.json")   # read by the eww notification handler
NOTIF_KEYS = {"notif_popups": ("popups", bool), "notif_popup_seconds": ("popup_seconds", int),
              "notif_history_limit": ("history_limit", int), "notif_in_stack": ("in_stack", bool),
              "notif_hide_with_stack": ("hide_with_stack", bool)}
NOTIF_BUS = ["busctl", "--user", "call", "org.freedesktop.Notifications", "/org/freedesktop/Notifications",
             "org.blomst.NotificationHistory"]
BROWSERS = [("firefox", "Firefox"), ("zen-browser", "Zen"), ("librewolf", "LibreWolf"), ("floorp", "Floorp"),
            ("brave", "Brave"), ("chromium", "Chromium"), ("google-chrome-stable", "Chrome"),
            ("vivaldi-stable", "Vivaldi"), ("qutebrowser", "qutebrowser")]
SECOND_SCREEN_OFFSET = 5      # second monitor owns workspaces 6-10 (see ~/scripts/workspace.sh)

BORDER_SPIN_ON = "animation = borderangle, 1, 60, linear, loop"
BORDER_SPIN_OFF = "animation = borderangle, 0"

# key -> (file, block path, option name, type)
HYPR_KEYS = {
    "gaps_in": (APPEARANCE, ["general"], "gaps_in", int),
    "gaps_out": (APPEARANCE, ["general"], "gaps_out", int),
    "border_size": (APPEARANCE, ["general"], "border_size", int),
    "rounding": (APPEARANCE, ["decoration"], "rounding", int),
    "inactive_opacity": (APPEARANCE, ["decoration"], "inactive_opacity", float),
    "blur_enabled": (APPEARANCE, ["decoration", "blur"], "enabled", bool),
    "blur_size": (APPEARANCE, ["decoration", "blur"], "size", int),
    "blur_passes": (APPEARANCE, ["decoration", "blur"], "passes", int),
    "shadow_enabled": (APPEARANCE, ["decoration", "shadow"], "enabled", bool),
    "animations_enabled": (ANIMATIONS, ["animations"], "enabled", bool),
}
# Normal-speed duration of each animation; the speed setting scales these.
ANIM_BASE = {
    "windowsIn": 5, "windowsOut": 3, "windowsMove": 5, "layersIn": 4, "layersOut": 3,
    "fadeLayersIn": 3, "fadeLayersOut": 2, "fadeIn": 4, "fadeOut": 3, "fadeSwitch": 4,
    "fadeShadow": 4, "fadeDim": 4, "border": 6, "workspaces": 5, "specialWorkspace": 4,
}
ANIM_SPEEDS = {"fast": 0.6, "normal": 1.0, "slow": 1.6}
WS_STYLES = {"vertical": "slidefadevert 20%", "horizontal": "slidefade 20%", "fade": "fade"}
IDLE_KEYS = {"idle_lock_min": "lock-session", "idle_suspend_min": "systemctl suspend"}
BAR_KEYS = {"show_cpu": "show-cpu", "show_temp": "show-temp", "show_mem": "show-mem",
            "show_disk": "show-disk", "show_music": "show-music"}

# What a preset remembers (looks only; idle timings and bar contents are left alone).
ALL_KEYS = list(HYPR_KEYS) + ["border_spin", "terminal_opacity", "anim_speed", "ws_anim"]

DEFAULTS = {
    "gaps_in": 5, "gaps_out": 8, "border_size": 2, "rounding": 14,
    "inactive_opacity": 0.92, "blur_enabled": True, "blur_size": 6,
    "blur_passes": 3, "shadow_enabled": True, "animations_enabled": True,
    "border_spin": True, "terminal_opacity": 0.78,
    "anim_speed": "normal", "ws_anim": "vertical",
    "idle_lock_min": 30, "idle_suspend_min": 60,
    "browser": "firefox",
    "float_size": True, "float_position": True,
    "notif_popups": True, "notif_popup_seconds": 10, "notif_history_limit": 50,
    "notif_in_stack": True, "notif_hide_with_stack": True,
    "show_cpu": True, "show_temp": True, "show_mem": True, "show_disk": True, "show_music": True,
}

_BLOCK_OPEN = re.compile(r"^\s*([\w.:-]+)\s*\{\s*(#.*)?$")
_BLOCK_CLOSE = re.compile(r"^\s*\}\s*(#.*)?$")


def _read(path):
    try:
        with open(os.path.realpath(path), encoding="utf-8") as f:
            return f.read()
    except OSError:
        return ""


def _write(path, text):
    # Write through symlinks, in place, so the stowed dotfiles stay linked.
    with open(os.path.realpath(path), "w", encoding="utf-8") as f:
        f.write(text)


def _find_option(lines, block, option):
    """Index of the line setting `option` directly inside `block`, or -1."""
    stack = []
    pattern = re.compile(r"^\s*" + re.escape(option) + r"\s*=")
    for i, line in enumerate(lines):
        if _BLOCK_OPEN.match(line):
            stack.append(_BLOCK_OPEN.match(line).group(1))
        elif _BLOCK_CLOSE.match(line):
            if stack:
                stack.pop()
        elif stack == block and pattern.match(line):
            return i
    return -1


def hypr_get(text, block, option):
    lines = text.split("\n")
    i = _find_option(lines, block, option)
    if i < 0:
        return None
    return lines[i].split("=", 1)[1].split("#", 1)[0].strip()


def hypr_set(text, block, option, value):
    """Return `text` with the option changed. Unknown options are left alone."""
    lines = text.split("\n")
    i = _find_option(lines, block, option)
    if i < 0:
        return text
    head, rest = lines[i].split("=", 1)
    comment = ""
    if "#" in rest:
        comment = " #" + rest.split("#", 1)[1]
    lines[i] = head.rstrip() + " = " + value + comment
    return "\n".join(lines)


def _format(value, kind):
    if kind is bool:
        return "true" if value else "false"
    if kind is int:
        return str(int(round(float(value))))
    return ("%.2f" % float(value)).rstrip("0").rstrip(".")


def _parse(raw, kind, fallback):
    if raw is None:
        return fallback
    try:
        if kind is bool:
            return raw.lower() in ("true", "yes", "on", "1")
        if kind is int:
            return int(float(raw))
        return float(raw)
    except ValueError:
        return fallback


def read_settings():
    out = {}
    cache = {}
    for key, (path, block, option, kind) in HYPR_KEYS.items():
        text = cache.setdefault(path, _read(path))
        out[key] = _parse(hypr_get(text, block, option), kind, DEFAULTS[key])

    spin = re.search(r"^\s*animation\s*=\s*borderangle\s*,\s*(\d)", cache.get(ANIMATIONS, ""), re.M)
    out["border_spin"] = bool(spin and spin.group(1) == "1")

    m = re.search(r"^\s*background_opacity\s+([\d.]+)", _read(KITTY), re.M)
    out["terminal_opacity"] = float(m.group(1)) if m else DEFAULTS["terminal_opacity"]

    anim = cache.get(ANIMATIONS, "")
    out["anim_speed"] = DEFAULTS["anim_speed"]
    m = re.search(r"^\s*animation\s*=\s*windowsIn\s*,\s*\d\s*,\s*(\d+)", anim, re.M)
    if m:
        for name, factor in ANIM_SPEEDS.items():
            if _scaled("windowsIn", factor) == int(m.group(1)):
                out["anim_speed"] = name
    out["ws_anim"] = DEFAULTS["ws_anim"]
    m = re.search(r"^\s*animation\s*=\s*workspaces\s*,[^,\n]*,[^,\n]*,[^,\n]*,\s*(\w+)", anim, re.M)
    if m:
        out["ws_anim"] = {"slidefadevert": "vertical", "slidevert": "vertical", "slidefade": "horizontal",
                          "slide": "horizontal", "fade": "fade"}.get(m.group(1), "vertical")

    idle = _read(HYPRIDLE)
    for key, needle in IDLE_KEYS.items():
        seconds = idle_get(idle, needle)
        out[key] = max(1, round(seconds / 60)) if seconds else DEFAULTS[key]

    m = re.search(r"^\s*\$browser\s*=\s*(.+?)\s*$", _read(APPS_CONF), re.M)
    out["browser"] = m.group(1) if m else DEFAULTS["browser"]

    try:
        with open(FLOAT_OPTIONS, encoding="utf-8") as f:
            float_opts = json.load(f)
    except (OSError, ValueError):
        float_opts = {}
    for key, name in FLOAT_KEYS.items():
        out[key] = bool(float_opts.get(name, DEFAULTS[key])) if isinstance(float_opts, dict) else DEFAULTS[key]

    try:
        with open(NOTIF_OPTIONS, encoding="utf-8") as f:
            notif_opts = json.load(f)
    except (OSError, ValueError):
        notif_opts = {}
    if not isinstance(notif_opts, dict):
        notif_opts = {}
    for key, (name, kind) in NOTIF_KEYS.items():
        out[key] = _parse(str(notif_opts[name]), kind, DEFAULTS[key]) if name in notif_opts else DEFAULTS[key]

    bar = dict(re.findall(r"\(defvar\s+(show-\w+)\s+(true|false)\)", _read(EWW_SETTINGS)))
    for key, var in BAR_KEYS.items():
        out[key] = bar.get(var, "true") == "true"
    return out


def _scaled(name, factor):
    return max(1, round(ANIM_BASE[name] * factor))


_LISTENER = re.compile(r"^listener\s*\{[^}]*\}", re.M)


def _idle_block(text, needle):
    for m in _LISTENER.finditer(text):
        if re.search(r"^\s*on-timeout\s*=.*" + re.escape(needle), m.group(0), re.M):
            return m
    return None


def idle_get(text, needle):
    m = _idle_block(text, needle)
    if not m:
        return None
    t = re.search(r"^\s*timeout\s*=\s*(\d+)", m.group(0), re.M)
    return int(t.group(1)) if t else None


def idle_set(text, needle, seconds):
    m = _idle_block(text, needle)
    if not m:
        return text
    block = re.sub(r"^(\s*timeout\s*=\s*)\d+[^\n]*", lambda t: t.group(1) + str(int(seconds)), m.group(0), count=1, flags=re.M)
    return text[:m.start()] + block + text[m.end():]


def _restart_hypridle():
    """Only if it is running: a stopped hypridle means the user switched idle off."""
    quiet = dict(stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        if subprocess.run(["pgrep", "-x", "hypridle"], **quiet).returncode == 0:
            subprocess.run(["pkill", "-x", "hypridle"], **quiet)
            subprocess.Popen(["hypridle"], start_new_session=True, **quiet)
    except OSError:
        pass


def _write_bar(settings):
    lines = [";; Written by Blomst Settings. Which pieces of the side-bar are shown."]
    lines += ["(defvar %s %s)" % (var, "true" if settings.get(key, True) else "false") for key, var in BAR_KEYS.items()]
    os.makedirs(os.path.dirname(EWW_SETTINGS), exist_ok=True)
    _write(EWW_SETTINGS, "\n".join(lines) + "\n")


def write_setting(key, value):
    """Change one setting on disk. Returns True if a file was changed."""
    if key in HYPR_KEYS:
        path, block, option, kind = HYPR_KEYS[key]
        old = _read(path)
        new = hypr_set(old, block, option, _format(value, kind))
    elif key == "border_spin":
        path, old = ANIMATIONS, _read(ANIMATIONS)
        line = BORDER_SPIN_ON if value else BORDER_SPIN_OFF
        new = re.sub(r"^(\s*)animation\s*=\s*borderangle\s*,.*$", lambda m: m.group(1) + line, old, flags=re.M)
    elif key == "terminal_opacity":
        path, old = KITTY, _read(KITTY)
        new = re.sub(r"^(\s*)background_opacity\s+[\d.]+", lambda m: m.group(1) + "background_opacity " + _format(value, float), old, flags=re.M)
    elif key == "anim_speed":
        if value not in ANIM_SPEEDS:
            return False
        path, old = ANIMATIONS, _read(ANIMATIONS)
        new = old
        for name in ANIM_BASE:
            new = re.sub(r"^(\s*animation\s*=\s*%s\s*,\s*\d\s*,\s*)\d+" % name,
                         lambda m, n=name: m.group(1) + str(_scaled(n, ANIM_SPEEDS[value])), new, flags=re.M)
    elif key == "ws_anim":
        if value not in WS_STYLES:
            return False
        path, old = ANIMATIONS, _read(ANIMATIONS)
        new = re.sub(r"^(\s*animation\s*=\s*workspaces\s*,[^,\n]*,[^,\n]*,[^,\n]*,\s*)[^\n#]*",
                     lambda m: m.group(1) + WS_STYLES[value], old, flags=re.M)
    elif key in IDLE_KEYS:
        path, old = HYPRIDLE, _read(HYPRIDLE)
        new = idle_set(old, IDLE_KEYS[key], int(round(float(value))) * 60)
    elif key in FLOAT_KEYS:
        settings = read_settings()
        data = {name: settings[k] for k, name in FLOAT_KEYS.items()}
        data[FLOAT_KEYS[key]] = bool(value)
        os.makedirs(os.path.dirname(FLOAT_OPTIONS), exist_ok=True)
        with open(FLOAT_OPTIONS, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2)
        return True
    elif key in NOTIF_KEYS:
        settings = read_settings()
        data = {name: settings[k] for k, (name, _) in NOTIF_KEYS.items()}
        name, kind = NOTIF_KEYS[key]
        data[name] = bool(value) if kind is bool else int(round(float(value)))
        os.makedirs(os.path.dirname(NOTIF_OPTIONS), exist_ok=True)
        with open(NOTIF_OPTIONS, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2)
        return True
    elif key == "browser":
        value = str(value).strip()
        if not value or "\n" in value:
            return False
        path, old = APPS_CONF, _read(APPS_CONF)
        line = "$browser = " + value
        if re.search(r"^\s*\$browser\s*=", old, re.M):
            new = re.sub(r"^\s*\$browser\s*=.*$", lambda m: line, old, flags=re.M)
        else:
            new = old.rstrip("\n") + "\n" + line + "\n"
    elif key in BAR_KEYS:
        settings = read_settings()
        if settings[key] == bool(value) and os.path.isfile(os.path.realpath(EWW_SETTINGS)):
            return False
        settings[key] = bool(value)
        _write_bar(settings)
        return True
    else:
        return False
    if not old or new == old:
        return False
    _write(path, new)
    if key == "terminal_opacity":
        _reload_kitty(_format(value, float))
    if key in IDLE_KEYS:
        _restart_hypridle()
    return True


def _reload_kitty(opacity):
    """Best effort: apply to running terminals. New ones read the config anyway."""
    quiet = dict(stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        for name in os.listdir("/tmp"):
            if name.startswith("kitty"):
                sock = os.path.join("/tmp", name)
                subprocess.Popen(["kitty", "@", "--to", "unix:" + sock, "set-background-opacity", "--all", opacity], **quiet)
        subprocess.Popen(["pkill", "-USR1", "-x", "kitty"], **quiet)
    except OSError:
        pass


def clear_notifications():
    """Empty the notification center (and any pop-ups still showing)."""
    try:
        subprocess.run(NOTIF_BUS + ["Clear"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=3)
    except (OSError, subprocess.SubprocessError):
        pass


# ---------- palette ----------

def _rgb(hexstr):
    h = hexstr.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def mix(a, b, t):
    """Blend colour a toward colour b by t (0..1)."""
    ra, rb = _rgb(a), _rgb(b)
    return "#%02x%02x%02x" % tuple(round(x + (y - x) * t) for x, y in zip(ra, rb))


def read_palette():
    raw = dict(re.findall(r"\$([\w-]+)\s*:\s*(#[0-9a-fA-F]{6})", _read(COLORS)))
    bg = raw.get("background", "#0a0a0a")
    light = raw.get("color7", "#c8c8c8")
    mid = raw.get("color5", "#8e8e8e")
    accent = raw.get("color6", light)
    return {
        "bg": bg,
        "window": "#e0" + mix(bg, mid, 0.06)[1:],     # #AARRGGBB, slightly see-through
        "sidebar": "#66" + bg[1:],
        "surface": mix(bg, mid, 0.14),
        "surface2": mix(bg, mid, 0.24),
        "surface3": mix(bg, mid, 0.38),
        "text": mix(light, "#ffffff", 0.45),
        "subtext": mix(mid, "#ffffff", 0.15),
        "accent": mix(accent, "#ffffff", 0.25),
        "accentText": mix(bg, "#000000", 0.3),
    }


# ---------- wallpapers ----------

def list_wallpapers():
    try:
        names = os.listdir(WALLPAPERS)
    except OSError:
        return []
    out = [n[len("preview-"):-4] for n in names if n.startswith("preview-") and n.endswith(".jpg")]

    def order(n):
        return (0, int(n), "") if n.isdigit() else (1, 0, n.lower())
    return sorted(out, key=order)


NORMALIZE_SCRIPT = os.path.join(HOME, "scripts/normalize_wallpaper.sh")
_IMAGE_TYPES = (".jpg", ".jpeg", ".png", ".webp")


def unprepared_wallpapers():
    """Pictures dropped into ~/wallpapers that have no preview yet (so are not listed)."""
    try:
        names = os.listdir(WALLPAPERS)
    except OSError:
        return []
    have = set(names)
    out = []
    for n in names:
        base, ext = os.path.splitext(n)
        if ext.lower() in _IMAGE_TYPES and not base.startswith("preview-") and "preview-%s.jpg" % base not in have:
            out.append(base)
    return sorted(set(out))


def prepare_wallpapers():
    """Convert new pictures to jpg and make their previews, in the background."""
    if not os.path.isfile(NORMALIZE_SCRIPT):
        return False
    subprocess.Popen(["bash", NORMALIZE_SCRIPT], start_new_session=True,
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return True


def thumbnail(name):
    for candidate in ("preview-%s.jpg" % name, "%s.jpg" % name):
        path = os.path.join(WALLPAPERS, candidate)
        if os.path.isfile(path):
            return path
    return ""


def current_wallpaper():
    m = re.search(r"^\s*path\s*=\s*.*/([^/\n]+)\.jpg\s*$", _read(HYPRPAPER), re.M)
    return m.group(1) if m else ""


def apply_wallpaper(name):
    if not os.path.isfile(os.path.join(WALLPAPERS, name + ".jpg")):
        return False
    subprocess.Popen(["bash", WALLPAPER_SCRIPT, name], start_new_session=True,
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return True


# ---------- presets ----------

def read_presets():
    try:
        with open(PRESETS, encoding="utf-8") as f:
            data = json.load(f)
        return [p for p in data if isinstance(p, dict) and p.get("name")]
    except (OSError, ValueError):
        return []


def write_presets(presets):
    os.makedirs(os.path.dirname(PRESETS), exist_ok=True)
    tmp = PRESETS + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(presets, f, indent=2)
    os.replace(tmp, PRESETS)


def save_preset(name, description):
    name = name.strip()
    if not name:
        return False
    presets = [p for p in read_presets() if p["name"] != name]
    presets.append({
        "name": name,
        "description": description.strip(),
        "wallpaper": current_wallpaper(),
        "settings": {k: v for k, v in read_settings().items() if k in ALL_KEYS},
    })
    write_presets(presets)
    return True


def remove_preset(name):
    write_presets([p for p in read_presets() if p["name"] != name])


def apply_preset(name):
    for p in read_presets():
        if p["name"] == name:
            for key, value in p.get("settings", {}).items():
                if key in ALL_KEYS:
                    write_setting(key, value)
            wall = p.get("wallpaper", "")
            if wall and wall != current_wallpaper():
                apply_wallpaper(wall)
            return True
    return False


# ---------- apps -> workspaces ----------

def open_app_classes():
    """Window classes of everything currently open, for picking from."""
    try:
        out = subprocess.run(["hyprctl", "clients", "-j"], capture_output=True, text=True, timeout=2).stdout
        return sorted({c.get("class", "") for c in json.loads(out) if c.get("class")}, key=str.lower)
    except (OSError, ValueError, subprocess.SubprocessError):
        return []


def read_app_rules():
    try:
        with open(APP_RULES_JSON, encoding="utf-8") as f:
            data = json.load(f)
    except (OSError, ValueError):
        return []
    out = []
    for r in data:
        if isinstance(r, dict) and r.get("class") and r.get("screen") in ("main", "second", "any"):
            floating = bool(r.get("floating", False))
            if r["screen"] == "any" and not floating:
                continue                      # a rule that does nothing
            out.append({"class": str(r["class"]), "screen": r["screen"], "floating": floating,
                        "workspace": min(5, max(1, int(r.get("workspace", 1))))})
    return out


def render_app_rules(rules):
    lines = ["# Written by Blomst Settings. Edit there, not here.",
             "# Where apps open (screen and workspace) and whether they open floating."]
    for r in rules:
        match = "windowrule = match:class ^(%s)$, " % re.escape(r["class"])
        if r.get("floating"):
            lines.append(match + "float on")
        if r["screen"] != "any":
            number = r["workspace"] + (SECOND_SCREEN_OFFSET if r["screen"] == "second" else 0)
            lines.append(match + "workspace %d" % number)
    return "\n".join(lines) + "\n"


def write_app_rules(rules):
    os.makedirs(os.path.dirname(APP_RULES_JSON), exist_ok=True)
    tmp = APP_RULES_JSON + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(rules, f, indent=2)
    os.replace(tmp, APP_RULES_JSON)
    # The rules file must exist before hyprland.conf mentions it, or Hyprland shows an error.
    target = os.path.realpath(APP_RULES_CONF)
    os.makedirs(os.path.dirname(target), exist_ok=True)
    with open(target, "w", encoding="utf-8") as f:
        f.write(render_app_rules(rules))
    main = _read(HYPRLAND)
    if main and "user/app-rules.conf" not in main:
        _write(HYPRLAND, main.rstrip("\n") + "\nsource = $hyprDirectory/user/app-rules.conf\n")


def add_app_rule(cls, screen, workspace, floating=False):
    cls = cls.strip()
    if not cls or screen not in ("main", "second", "any"):
        return False
    if screen == "any" and not floating:
        return False
    rules = [r for r in read_app_rules() if r["class"] != cls]
    rules.append({"class": cls, "screen": screen, "floating": bool(floating),
                  "workspace": min(5, max(1, int(workspace)))})
    write_app_rules(rules)
    return True


def remove_app_rule(cls):
    write_app_rules([r for r in read_app_rules() if r["class"] != cls])


# ---------- default apps ----------

def installed_browsers():
    """Browsers found on this machine, as (command, name) pairs."""
    return [(cmd, name) for cmd, name in BROWSERS if shutil.which(cmd)]
