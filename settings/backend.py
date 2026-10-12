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
INPUTS = os.path.join(CONFIG, "hypr/user/inputs.conf")
MONITORS = os.path.join(CONFIG, "hypr/user/monitors.conf")
KEYBINDS = os.path.join(CONFIG, "hypr/core/keybinds.conf")
CORE_EXECS = os.path.join(CONFIG, "hypr/core/execs.conf")
USER_EXECS = os.path.join(CONFIG, "hypr/user/execs.conf")
NIGHT_LIGHT = os.path.join(CONFIG, "blomst-settings/night-light.json")       # read by ~/scripts/night_light.sh
NIGHT_LIGHT_SCRIPT = os.path.join(HOME, "scripts/night_light.sh")
IDLE_TOGGLE = os.path.join(CONFIG, "eww/scripts/toggle-idle.sh")
XKB_RULES = "/usr/share/X11/xkb/rules/base.lst"
EWW_SCSS = os.path.join(CONFIG, "eww/eww.scss")
ROFI_CONFIGS = [os.path.join(CONFIG, "rofi", n) for n in ("config.rasi", "config-wallpaper.rasi", "config-password.rasi")]
HYPRLOCK = os.path.join(CONFIG, "hypr/service/hyprlock.conf")
FONT_KEYS = ("font_desktop", "font_terminal", "font_terminal_size")
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
TERMINALS = [("kitty", "kitty"), ("alacritty", "Alacritty"), ("foot", "foot"), ("wezterm", "WezTerm"),
             ("ghostty", "Ghostty"), ("konsole", "Konsole"), ("gnome-terminal", "GNOME Terminal")]
APP_VARS = {"browser": "$browser", "terminal": "$terminal"}       # key -> variable in apps.conf
LAYOUT_SWITCHES = {"none": "", "alt_shift": "grp:alt_shift_toggle", "caps": "grp:caps_toggle",
                   "ctrl_space": "grp:ctrl_space_toggle"}
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
    "layout": (APPEARANCE, ["general"], "layout", str),
    "kb_layout": (INPUTS, ["input"], "kb_layout", str),
    "repeat_rate": (INPUTS, ["input"], "repeat_rate", int),
    "repeat_delay": (INPUTS, ["input"], "repeat_delay", int),
    "mouse_sensitivity": (INPUTS, ["input"], "sensitivity", float),
    "accel_profile": (INPUTS, ["input"], "accel_profile", str),
    "follow_mouse": (INPUTS, ["input"], "follow_mouse", int),
    "natural_scroll": (INPUTS, ["input"], "natural_scroll", bool),
    "touchpad_natural_scroll": (INPUTS, ["input", "touchpad"], "natural_scroll", bool),
}
# Only these values are accepted for the text options above
HYPR_CHOICES = {"layout": ("dwindle", "master"), "accel_profile": ("flat", "adaptive"), "follow_mouse": (0, 1)}
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
    "browser": "firefox", "terminal": "kitty",
    "layout": "dwindle", "kb_layout": "us", "layout_switch": "none",
    "repeat_rate": 25, "repeat_delay": 600, "mouse_sensitivity": 0.0, "accel_profile": "adaptive",
    "follow_mouse": 1, "natural_scroll": False, "touchpad_natural_scroll": False,
    "idle_enabled": True, "night_light": False, "night_light_temp": 4500,
    "font_desktop": "Iosevka", "font_terminal": "Iosevka", "font_terminal_size": 11,
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


def _find_block_end(lines, block):
    """Index of the closing brace of `block`, or -1."""
    stack = []
    for i, line in enumerate(lines):
        if _BLOCK_OPEN.match(line):
            stack.append(_BLOCK_OPEN.match(line).group(1))
        elif _BLOCK_CLOSE.match(line):
            if stack == block:
                return i
            if stack:
                stack.pop()
    return -1


def hypr_set(text, block, option, value):
    """Return `text` with the option changed, added to `block` if it is missing there.
    If the block itself is missing the text is left alone."""
    lines = text.split("\n")
    i = _find_option(lines, block, option)
    if i < 0:
        end = _find_block_end(lines, block)
        if end < 0:
            return text
        indent = re.match(r"^\s*", lines[end]).group(0) + "    "
        lines.insert(end, indent + option + " = " + value)
        return "\n".join(lines)
    head, rest = lines[i].split("=", 1)
    comment = ""
    if "#" in rest:
        comment = " #" + rest.split("#", 1)[1]
    lines[i] = head.rstrip() + " = " + value + comment
    return "\n".join(lines)


def _format(value, kind):
    if kind is str:
        return str(value).strip()
    if kind is bool:
        return "true" if value else "false"
    if kind is int:
        return str(int(round(float(value))))
    return ("%.2f" % float(value)).rstrip("0").rstrip(".")


def _parse(raw, kind, fallback):
    if raw is None:
        return fallback
    if kind is str:
        return raw if raw else fallback
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

    apps = _read(APPS_CONF)
    for key, var in APP_VARS.items():
        m = re.search(r"^\s*" + re.escape(var) + r"\s*=\s*(.+?)\s*$", apps, re.M)
        out[key] = m.group(1) if m else DEFAULTS[key]

    options = hypr_get(cache.get(INPUTS, ""), ["input"], "kb_options") or ""
    found = re.search(r"grp:\w+", options)
    out["layout_switch"] = next((k for k, v in LAYOUT_SWITCHES.items() if found and v == found.group(0)), "none")

    m = re.search(r'font-family:\s*"([^"]+)"', _read(EWW_SCSS))
    out["font_desktop"] = m.group(1) if m else DEFAULTS["font_desktop"]
    kitty = _read(KITTY)
    m = re.search(r"^\s*font_family\s+(.+?)\s*$", kitty, re.M)
    out["font_terminal"] = m.group(1) if m else DEFAULTS["font_terminal"]
    m = re.search(r"^\s*font_size\s+([\d.]+)", kitty, re.M)
    out["font_terminal_size"] = float(m.group(1)) if m else DEFAULTS["font_terminal_size"]

    out["idle_enabled"] = _running("hypridle")
    night = _read_json(NIGHT_LIGHT, {})
    out["night_light"] = bool(night.get("enabled", DEFAULTS["night_light"]))
    out["night_light_temp"] = int(night.get("temperature", DEFAULTS["night_light_temp"]))

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


def _read_json(path, fallback):
    try:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
        return data if isinstance(data, type(fallback)) else fallback
    except (OSError, ValueError):
        return fallback


def _write_json(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
    os.replace(tmp, path)


def _running(name):
    try:
        return subprocess.run(["pgrep", "-x", name], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0
    except OSError:
        return False


def _detach(cmd):
    try:
        subprocess.Popen(cmd, start_new_session=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return True
    except OSError:
        return False


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
        if key in HYPR_CHOICES and value not in HYPR_CHOICES[key]:
            return False
        if key == "kb_layout" and not valid_kb_layout(value):
            return False
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
    elif key in APP_VARS:
        value = str(value).strip()
        if not value or "\n" in value:
            return False
        var = APP_VARS[key]
        path, old = APPS_CONF, _read(APPS_CONF)
        line = var + " = " + value
        if re.search(r"^\s*" + re.escape(var) + r"\s*=", old, re.M):
            new = re.sub(r"^\s*" + re.escape(var) + r"\s*=.*$", lambda m: line, old, flags=re.M)
        else:
            new = old.rstrip("\n") + "\n" + line + "\n"
    elif key == "layout_switch":
        if value not in LAYOUT_SWITCHES:
            return False
        path, old = INPUTS, _read(INPUTS)
        current = hypr_get(old, ["input"], "kb_options") or ""
        parts = [o for o in current.split(",") if o.strip() and not o.strip().startswith("grp:")]
        if LAYOUT_SWITCHES[value]:
            parts.append(LAYOUT_SWITCHES[value])
        new = hypr_set(old, ["input"], "kb_options", ",".join(p.strip() for p in parts))
    elif key == "idle_enabled":
        if bool(value) == _running("hypridle"):
            return False
        return _detach(["bash", IDLE_TOGGLE])
    elif key in FONT_KEYS:
        return write_font(key, value)
    elif key in ("night_light", "night_light_temp"):
        data = _read_json(NIGHT_LIGHT, {})
        data.setdefault("enabled", DEFAULTS["night_light"])
        data.setdefault("temperature", DEFAULTS["night_light_temp"])
        if key == "night_light":
            data["enabled"] = bool(value)
        else:
            data["temperature"] = min(6500, max(1000, int(round(float(value)))))
        _write_json(NIGHT_LIGHT, data)
        if data["enabled"]:
            ensure_night_light_autostart()
        apply_night_light()
        return True
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


# ---------- input ----------

def kb_layouts():
    """Every keyboard layout xkb knows, as (code, name) pairs."""
    out, inside = [], False
    for line in _read(XKB_RULES).split("\n"):
        if line.startswith("!"):
            inside = line.strip() == "! layout"
            continue
        parts = line.split(None, 1)
        if inside and len(parts) == 2:
            out.append((parts[0], parts[1].strip()))
    return out


def valid_kb_layout(value):
    codes = {c for c, _ in kb_layouts()}
    wanted = [v.strip() for v in str(value).split(",")]
    if not codes:                     # cannot check on this machine; trust it
        return all(re.fullmatch(r"[a-z]{2,3}", v) for v in wanted)
    return all(v in codes for v in wanted)


# ---------- fonts ----------

_SKIP_FONTS = ("Font Awesome", "Nerd Font Mono", "Nerd Font Propo", "Emoji", "Symbols", "Noto Color", "Noto Sans Mono CJK",
               "Noto Serif CJK", "Noto Sans CJK", "v4 Compatibility")


def installed_fonts():
    """Font families you can pick, as {family, mono}. One entry per family."""
    try:
        out = subprocess.run(["fc-list", ":style=Regular:lang=en", "family", "spacing"], capture_output=True, text=True, timeout=5).stdout
    except (OSError, subprocess.SubprocessError):
        return []
    fonts = {}
    for line in out.splitlines():
        names, _, spacing = line.partition(":spacing=")
        family = names.split(",")[0].strip().replace("\\-", "-")
        if not family or any(skip in family for skip in _SKIP_FONTS):
            continue
        mono = spacing.strip() in ("90", "100")
        fonts[family] = fonts.get(family, False) or mono
    return [{"family": f, "mono": m} for f, m in sorted(fonts.items(), key=lambda kv: kv[0].lower())]


def _known_font(family):
    return any(f["family"] == family for f in installed_fonts())


def write_font(key, value):
    """Change the desktop font (bar, widgets, menus, lock screen) or the terminal font."""
    quiet = dict(stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    if key == "font_terminal_size":
        size = min(32, max(6, round(float(value) * 2) / 2))
        text = _read(KITTY)
        line = "font_size %s" % _format(size, float)
        if re.search(r"^\s*font_size\s", text, re.M):
            new = re.sub(r"^(\s*)font_size\s+.*$", lambda m: m.group(1) + line, text, flags=re.M)
        else:
            new = re.sub(r"^(\s*font_family\s.*)$", lambda m: m.group(1) + "\n" + line, text, count=1, flags=re.M)
        if new == text:
            return False
        _write(KITTY, new)
        _detach(["pkill", "-USR1", "-x", "kitty"])      # kitty re-reads its config
        return True

    family = str(value).strip()
    if not family or '"' in family or "\n" in family or not _known_font(family):
        return False
    if key == "font_terminal":
        text = _read(KITTY)
        new = re.sub(r"^(\s*)font_family\s+.*$", lambda m: m.group(1) + "font_family " + family, text, flags=re.M)
        if new == text:
            return False
        _write(KITTY, new)
        _detach(["pkill", "-USR1", "-x", "kitty"])
        return True

    changed = False
    text = _read(EWW_SCSS)
    new = re.sub(r'font-family:\s*"[^"]+"', 'font-family: "%s"' % family, text, count=1)
    if new != text:
        _write(EWW_SCSS, new)                   # eww reloads by itself when its files change
        changed = True
    for path in ROFI_CONFIGS:
        text = _read(path)
        new = re.sub(r'(^\s*font:\s*")[^"]*?(\s+\d+)?(";)', lambda m: m.group(1) + family + (m.group(2) or " 14") + m.group(3), text, count=1, flags=re.M)
        if new != text:
            _write(path, new)
            changed = True
    text = _read(HYPRLOCK)
    new = re.sub(r"^(\s*font_family\s*=\s*).*$", lambda m: m.group(1) + family, text, flags=re.M)
    if new != text:
        _write(HYPRLOCK, new)
        changed = True
    return changed


# ---------- night light ----------

def night_light_available():
    return shutil.which("hyprsunset") is not None


def apply_night_light():
    """Start, retune or stop hyprsunset to match the saved setting."""
    data = _read_json(NIGHT_LIGHT, {})
    quiet = dict(stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        subprocess.run(["pkill", "-x", "hyprsunset"], **quiet)
    except OSError:
        pass
    if data.get("enabled") and night_light_available():
        _detach(["hyprsunset", "-t", str(int(data.get("temperature", DEFAULTS["night_light_temp"])))])


def ensure_night_light_autostart():
    """Hyprland should restore the night light at login."""
    line = "exec-once = ~/scripts/night_light.sh"
    text = _read(CORE_EXECS)
    if text and "night_light.sh" not in text:
        _write(CORE_EXECS, text.rstrip("\n") + "\n\n# Night light (Blomst Settings)\n" + line + "\n")


# ---------- displays ----------

def _hyprctl_json(*args):
    try:
        out = subprocess.run(["hyprctl", *args, "-j"], capture_output=True, text=True, timeout=2).stdout
        return json.loads(out)
    except (OSError, ValueError, subprocess.SubprocessError):
        return []


def _clean_mode(mode):
    return mode[:-2] if mode.endswith("Hz") else mode


def _valid_scales(width, height):
    out = []
    for s in (1, 1.25, 4 / 3, 1.5, 1.6, 5 / 3, 2):
        w, h = width / s, height / s
        if abs(w - round(w)) < 0.01 and abs(h - round(h)) < 0.01:
            out.append(round(s, 6))
    return out


def monitors():
    out = []
    for m in _hyprctl_json("monitors"):
        modes, seen = [], set()
        for mode in m.get("availableModes", []):
            res, _, hz = _clean_mode(mode).partition("@")
            label = "%s @ %s Hz" % (res.replace("x", " × "), round(float(hz or 0)))
            if label not in seen:
                seen.add(label)
                modes.append({"value": _clean_mode(mode), "label": label})
        current = "%dx%d@%.2f" % (m["width"], m["height"], m["refreshRate"])
        out.append({
            "name": m["name"], "description": m.get("description", ""),
            "mode": current, "modes": modes,
            "scale": round(float(m.get("scale", 1)), 6),
            "scales": _valid_scales(m["width"], m["height"]),
            "x": m.get("x", 0), "y": m.get("y", 0), "width": m["width"], "height": m["height"],
        })
    return out


def _closest_mode(mon, mode):
    """The listed mode that best matches `mode` (refresh rates come back rounded)."""
    res, _, hz = mode.partition("@")
    best = None
    for m in mon["modes"]:
        r, _, h = m["value"].partition("@")
        if r == res:
            diff = abs(float(h or 0) - float(hz or 0))
            if best is None or diff < best[0]:
                best = (diff, m["value"])
    return best[1] if best else mode


def monitor_lines(mons):
    """`monitor = ...` lines for these monitors, laid out left to right in their current order."""
    lines, x = {}, 0
    for m in sorted(mons, key=lambda m: m["x"]):
        res = m["mode"].partition("@")[0]
        w, h = (int(v) for v in res.split("x"))
        scale = m["scale"]
        lines[m["name"]] = "%s, %s, %dx%d, %s" % (m["name"], m["mode"], x, m["y"], ("%.6f" % scale).rstrip("0").rstrip("."))
        x += round(w / scale)
    return lines


def apply_monitor_lines(lines):
    ok = True
    for line in lines.values():
        try:
            r = subprocess.run(["hyprctl", "keyword", "monitor", line], capture_output=True, text=True, timeout=3)
            ok = ok and r.returncode == 0 and "error" not in r.stdout.lower()
        except (OSError, subprocess.SubprocessError):
            ok = False
    return ok


def write_monitor_lines(lines):
    text = _read(MONITORS)
    for name, line in lines.items():
        pattern = r"^\s*monitor\s*=\s*" + re.escape(name) + r"\s*,.*$"
        if re.search(pattern, text, re.M):
            text = re.sub(pattern, lambda m: "monitor = " + line, text, flags=re.M)
        else:
            text = "monitor = " + line + "\n" + text
    _write(MONITORS, text)


# ---------- keybinds ----------

MOD_NAMES = {"SUPER": "Super", "SHIFT": "Shift", "CTRL": "Ctrl", "CONTROL": "Ctrl", "ALT": "Alt"}
KEY_NAMES = {"RETURN": "Enter", "SPACE": "Space", "PRINT": "Print", "Escape": "Esc", "ESCAPE": "Esc", "mouse_down": "Scroll down",
             "mouse_up": "Scroll up", "mouse:272": "Left drag", "mouse:273": "Right drag",
             "XF86AudioRaiseVolume": "Volume up", "XF86AudioLowerVolume": "Volume down",
             "XF86AudioMute": "Mute", "XF86AudioMicMute": "Mute microphone",
             "XF86MonBrightnessUp": "Brightness up", "XF86MonBrightnessDown": "Brightness down"}
DIRECTIONS = {"l": "left", "r": "right", "u": "up", "d": "down"}


def _describe(dispatcher, arg, apps):
    arg = arg.strip()
    if dispatcher == "exec":
        floating = arg.startswith("[float")
        command = re.sub(r"^\[[^\]]*\]\s*", "", arg)
        for var, val in apps.items():
            command = command.replace(var, val)
        return command + (" (floating)" if floating else "")
    if dispatcher in ("workspace", "movetoworkspace"):
        return ("Go to workspace " if dispatcher == "workspace" else "Send window to workspace ") + arg.replace("e+1", "next").replace("e-1", "previous")
    if dispatcher in ("movefocus", "movewindow"):
        return ("Focus " if dispatcher == "movefocus" else "Move window ") + DIRECTIONS.get(arg, arg)
    if dispatcher in ("resizeactive", "moveactive"):
        return ("Resize window " if dispatcher == "resizeactive" else "Move floating window ") + arg
    if dispatcher == "layoutmsg" and arg == "togglesplit":
        return "Switch split direction"
    return {"killactive": "Close window", "togglefloating": "Float or tile window", "fullscreen": "Fullscreen",
            "movewindow": "Drag to move window", "resizewindow": "Drag to resize window"}.get(dispatcher, (dispatcher + " " + arg).strip())


def read_keybinds():
    """Binds from keybinds.conf grouped under the comment above them."""
    text = _read(KEYBINDS)
    variables = dict(re.findall(r"^\s*(\$\w+)\s*=\s*(\w+)", text, re.M))
    apps = dict(re.findall(r"^\s*(\$\w+)\s*=\s*(.+?)\s*$", _read(APPS_CONF), re.M))
    groups, title = [], "Other"
    for line in text.split("\n"):
        stripped = line.strip()
        if stripped.startswith("#"):
            heading = stripped.lstrip("#").strip()
            if heading and not heading.lower().startswith(("1-5", "keybinds")):
                title = heading
            continue
        m = re.match(r"^bind\w*\s*=\s*([^,]*),\s*([^,]+),\s*([^,]+)(?:,\s*(.*))?$", stripped)
        if not m:
            continue
        mods, key, dispatcher, arg = m.group(1), m.group(2).strip(), m.group(3).strip(), (m.group(4) or "").split("#")[0]
        for var, val in variables.items():
            mods = mods.replace(var, val)
        names = [MOD_NAMES.get(w.upper(), w.title()) for w in mods.split()]
        keys = " + ".join(names + [KEY_NAMES.get(key, key.upper() if len(key) == 1 else key)])
        if not groups or groups[-1]["title"] != title:
            groups.append({"title": title, "binds": []})
        groups[-1]["binds"].append({"keys": keys, "action": _describe(dispatcher, arg, apps)})
    return groups


# ---------- startup apps ----------

def read_autostart():
    return [m.strip() for m in re.findall(r"^\s*exec-once\s*=\s*(.+)$", _read(USER_EXECS), re.M)]


def write_autostart(commands):
    lines = ["# Auto Start Apps. Written by Blomst Settings (the Startup page)."]
    lines += ["exec-once = " + c for c in commands]
    _write(USER_EXECS, "\n".join(lines) + "\n")


def add_autostart(command):
    command = command.strip()
    if not command or "\n" in command:
        return False
    current = read_autostart()
    if command in current:
        return False
    write_autostart(current + [command])
    _detach(["sh", "-c", command])      # start it now too, like it would at login
    return True


def remove_autostart(command):
    write_autostart([c for c in read_autostart() if c != command])


def installed_terminals():
    return [(cmd, name) for cmd, name in TERMINALS if shutil.which(cmd)]


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
