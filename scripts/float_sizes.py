#!/usr/bin/env python3
"""Remembers the size and position you give floating windows and re-applies them next time.

Sizes are also written out as Hyprland window rules (hypr/user/float-sizes.conf), so a
window can be created at its size straight away; anything that still opens differently
is resized and moved after it appears.

Windows are remembered per app and per kind of window (window class + the title the
window opens with), so an app's main window and its dialogs don't overwrite each other.
Saved in ~/.config/blomst-settings/float-sizes.json. What gets restored (size, position)
is switched in the settings window and kept in float-options.json.
Started by Hyprland (exec-once).
"""
import fcntl
import json
import os
import re
import select
import socket
import sys
import time

RUNTIME = os.environ.get("XDG_RUNTIME_DIR", "/tmp")
SIGNATURE = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", "")
CONTROL = os.path.join(RUNTIME, "hypr", SIGNATURE, ".socket.sock")
EVENTS = os.path.join(RUNTIME, "hypr", SIGNATURE, ".socket2.sock")
CONFIG = os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config"))
STORE = os.path.join(CONFIG, "blomst-settings", "float-sizes.json")
OPTIONS = os.path.join(CONFIG, "blomst-settings", "float-options.json")
RULES = os.path.join(CONFIG, "hypr", "user", "float-sizes.conf")
KITTY = os.path.join(CONFIG, "kitty", "float-size.conf")
LOG = os.path.join(os.path.dirname(STORE), "float-sizes.log")

DEFAULT_OPTIONS = {"size": True, "position": True}
RULES_DELAY = 1.5      # seconds of no change before rewriting the rules (not on every step of a drag)
POLL_SECONDS = 0.1     # normal pace: catches your resizes and moves
BURST_SECONDS = 0.02   # right after a window opens: check very often until it is in place
BURST_LENGTH = 1.0     # how long a burst lasts
WAKE_EVENTS = (b"openwindow>>", b"changefloatingmode>>")   # Hyprland tells us about these at once
OPTIONS_EVERY = 30     # re-read the on/off options every this many checks (3 seconds)
MIN_SIZE = 80          # ignore tooltips, menus and other tiny windows
TOLERANCE = 2          # pixels; smaller differences are not a real change
RETRIES = 4            # a change sent while a window is still appearing can land wrong; re-check and redo


def ask(command):
    """Send one command to Hyprland over its control socket and return the reply."""
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as sock:
        sock.settimeout(2)
        sock.connect(CONTROL)
        sock.sendall(command.encode())
        chunks = []
        while True:
            data = sock.recv(65536)
            if not data:
                break
            chunks.append(data)
    return b"".join(chunks).decode("utf-8", "replace")


def log(message):
    try:
        if os.path.exists(LOG) and os.path.getsize(LOG) > 50000:
            os.replace(LOG, LOG + ".old")
        with open(LOG, "a", encoding="utf-8") as f:
            f.write(time.strftime("%H:%M:%S ") + message + "\n")
    except OSError:
        pass


def query(what):
    """A list from Hyprland (clients, monitors), or None if it could not be reached."""
    try:
        return json.loads(ask("j/" + what))
    except (OSError, ValueError):
        return None


def clients():
    return query("clients")


def key_of(client):
    cls = client.get("class") or ""
    title = client.get("initialTitle") or ""
    # Windows without a title are menus and pop-ups (Steam's View/Friends/Games menus, file
    # pickers). Remembering them would write a rule for the whole app that resizes every menu,
    # and the app's clicks would then land in the wrong place. Leave them alone.
    if not cls or not title:
        return None
    return cls + "|" + title


def usable(client):
    size = client.get("size") or [0, 0]
    at = client.get("at") or []
    return (client.get("floating") is True and client.get("mapped", True)
            and not client.get("fullscreen") and len(size) == 2 and len(at) == 2
            and size[0] >= MIN_SIZE and size[1] >= MIN_SIZE and key_of(client) is not None)


def differs(a, b):
    return abs(a[0] - b[0]) > TOLERANCE or abs(a[1] - b[1]) > TOLERANCE


def on_screen(at, size, monitors):
    """True if the window's top-left area would land on one of the connected monitors."""
    x, y = at[0] + min(40, size[0] // 2), at[1] + min(40, size[1] // 2)
    for m in monitors or []:
        if m.get("x", 0) <= x < m.get("x", 0) + m.get("width", 0) and \
           m.get("y", 0) <= y < m.get("y", 0) + m.get("height", 0):
            return True
    return False


def read_options():
    try:
        with open(OPTIONS, encoding="utf-8") as f:
            data = json.load(f)
        return {k: bool(data.get(k, v)) for k, v in DEFAULT_OPTIONS.items()}
    except (OSError, ValueError, AttributeError):
        return dict(DEFAULT_OPTIONS)


def load():
    """Remembered windows: key -> {"size": [w, h], "at": [x, y] or None}."""
    try:
        with open(STORE, encoding="utf-8") as f:
            data = json.load(f)
    except (OSError, ValueError):
        return {}
    out = {}
    for k, v in data.items():
        if k.endswith("|"):                               # untitled pop-ups, learned by older versions
            continue
        try:
            if isinstance(v, list):                       # older files only had the size
                out[k] = {"size": [int(v[0]), int(v[1])], "at": None}
            elif isinstance(v, dict) and len(v.get("size") or []) == 2:
                at = v.get("at")
                out[k] = {"size": [int(v["size"][0]), int(v["size"][1])],
                          "at": [int(at[0]), int(at[1])] if at and len(at) == 2 else None}
        except (TypeError, ValueError, IndexError):
            continue
    return out


def save(saved):
    os.makedirs(os.path.dirname(STORE), exist_ok=True)
    tmp = STORE + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(saved, f, indent=2, sort_keys=True)
    os.replace(tmp, STORE)


def escape(text):
    """Escape only real regex characters (Hyprland's regex engine dislikes stray backslashes)."""
    return re.sub(r"([.^$*+?()\[\]{}|\\])", r"\\\1", text)


def write_if_changed(path, text):
    target = os.path.realpath(path)
    try:
        with open(target, encoding="utf-8") as f:
            if f.read() == text:
                return False
    except OSError:
        pass
    os.makedirs(os.path.dirname(target), exist_ok=True)
    with open(target, "w", encoding="utf-8") as f:
        f.write(text)
    return True


def write_rules(saved, options):
    """Turn the remembered sizes into Hyprland window rules. Hyprland reloads them by itself."""
    lines = ["# Written by ~/scripts/float_sizes.py. Sizes you gave floating windows.", ""]
    if options["size"]:
        for key in sorted(saved):
            cls, _, title = key.partition("|")
            if "," in key:                 # a comma would break the rule syntax; the fallback covers these
                continue
            match = "match:class ^(%s)$" % escape(cls)
            if title:
                match += ", match:initial_title ^(%s)$" % escape(title)
            size = saved[key]["size"]
            lines.append("windowrule = %s, size %d %d" % (match, size[0], size[1]))
    try:
        if write_if_changed(RULES, "\n".join(lines) + "\n"):
            log("wrote %d size rules" % (len(lines) - 2))
    except OSError as err:
        log("could not write rules: %s" % err)


def write_kitty(saved, options):
    """kitty keeps its own memory of its last window size and asks for that when it opens,
    which overrides everything else. Tell it to ask for the remembered size instead."""
    if not os.path.isdir(os.path.dirname(os.path.realpath(KITTY))):
        return
    head = "# Written by ~/scripts/float_sizes.py. The size kitty asks for when it opens floating.\n"
    entry = saved.get("kitty|kitty")
    if options["size"] and entry:
        text = head + "remember_window_size no\ninitial_window_width %d\ninitial_window_height %d\n" % tuple(entry["size"])
    else:
        text = head + "remember_window_size yes\n"
    try:
        if write_if_changed(KITTY, text):
            log("kitty size file updated")
    except OSError as err:
        log("could not write kitty size: %s" % err)


def set_animation(address, on):
    """Turn the move/resize animation off for one window while we put it in place, so it
    jumps there instead of gliding. Two spellings, for older and newer Hyprland."""
    for prop in ("no_anim", "noanim"):
        try:
            reply = ask("/dispatch setprop address:%s %s %d" % (address, prop, 0 if on else 1)).strip()
        except OSError as err:
            reply = "failed: %s" % err
        if reply == "ok":
            return
    log("could not switch animation for %s: %s" % (address, reply))


def resize(address, size):
    try:
        reply = ask("/dispatch resizewindowpixel exact %d %d,address:%s" % (size[0], size[1], address))
    except OSError as err:
        reply = "failed: %s" % err
    log("resize %s to %dx%d -> %s" % (address, size[0], size[1], reply.strip()))


def move(address, current, target):
    """Move by the difference, which means the same thing on every monitor layout."""
    dx, dy = target[0] - current[0], target[1] - current[1]
    try:
        reply = ask("/dispatch movewindowpixel %d %d,address:%s" % (dx, dy, address))
    except OSError as err:
        reply = "failed: %s" % err
    log("move %s to %d,%d -> %s" % (address, target[0], target[1], reply.strip()))


class Tracker:
    def __init__(self):
        self.saved = load()
        self.options = read_options()
        self.seen = {}          # address of each settled floating window -> (size, at) last seen
        self.fresh = {}         # address -> (size, at), new windows still settling
        self.pending = {}       # address -> [wanted size or None, wanted at or None, attempts]
        self.rules_due = None   # when to rewrite the Hyprland rules after a change
        self.checks = 0

    def targets(self, key, size, monitors):
        """What a new window of this kind should be changed to (None where nothing to do)."""
        entry = self.saved.get(key)
        if not entry:
            return None, None
        want_size = entry["size"] if self.options["size"] and differs(entry["size"], size) else None
        want_at = None
        if self.options["position"] and entry.get("at"):
            check_size = entry["size"] if self.options["size"] else size
            if on_screen(entry["at"], check_size, monitors):
                want_at = entry["at"]
        return want_size, want_at

    def apply(self, address, size, at, want_size, want_at):
        set_animation(address, False)
        if want_size and differs(want_size, size):
            resize(address, want_size)
        if want_at and differs(want_at, at):
            move(address, at, want_at)

    def scan(self, first=False):
        """Restore remembered windows as they appear, and learn from your changes.

        `first` is the scan at startup: windows that are already open are left alone.
        Returns False if Hyprland could not be reached.
        """
        windows = clients()
        if windows is None:
            return False
        self.checks += 1
        if self.checks % OPTIONS_EVERY == 0:
            options = read_options()
            if options != self.options:
                self.options = options
                self.rules_due = time.monotonic()
                log("options now %s" % options)
        monitors = None
        changed = False
        alive = set()
        for c in windows:
            address = c.get("address")
            alive.add(address)
            if not usable(c):
                # tiled or fullscreen: forget it, so floating it later counts as new
                for book in (self.seen, self.fresh, self.pending):
                    book.pop(address, None)
                continue
            size, at, key = list(c["size"]), list(c["at"]), key_of(c)

            if address in self.pending:                    # we changed it: check that it took
                want_size, want_at, attempts = self.pending[address]
                ok = (not want_size or not differs(want_size, size)) and (not want_at or not differs(want_at, at))
                if ok or attempts >= RETRIES:
                    del self.pending[address]
                    self.seen[address] = (size, at)
                    set_animation(address, True)      # your own moves animate as usual again
                else:
                    self.apply(address, size, at, want_size, want_at)
                    self.pending[address][2] = attempts + 1
            elif address not in self.seen:                 # just opened, or just switched to floating
                if first or key not in self.saved:
                    self.seen[address] = (size, at)
                    continue
                if monitors is None:
                    monitors = query("monitors") or []
                want_size, want_at = self.targets(key, size, monitors)
                if not want_size and (not want_at or not differs(want_at, at)):
                    self.fresh.pop(address, None)
                    self.seen[address] = (size, at)
                elif address in self.fresh and self.fresh[address] == (size, at):
                    # unchanged on two checks in a row: it has finished appearing
                    del self.fresh[address]
                    self.apply(address, size, at, want_size, want_at)
                    self.pending[address] = [want_size, want_at, 1]
                else:
                    self.fresh[address] = (size, at)
            else:
                old_size, old_at = self.seen[address]
                if differs(old_size, size) or differs(old_at, at):     # you resized or moved it
                    self.saved[key] = {"size": size, "at": at}
                    self.seen[address] = (size, at)
                    changed = True
                    log("learned %s = %dx%d at %d,%d" % (key, size[0], size[1], at[0], at[1]))
        for book in (self.seen, self.fresh, self.pending):
            for address in list(book):
                if address not in alive:
                    del book[address]
        if changed:
            save(self.saved)
            self.rules_due = time.monotonic() + RULES_DELAY
        if self.rules_due is not None and time.monotonic() >= self.rules_due:
            self.rules_due = None
            write_rules(self.saved, self.options)
            write_kitty(self.saved, self.options)
        return True


def connect_events():
    """Hyprland's event stream, so new windows are noticed the moment they open."""
    try:
        sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        sock.connect(EVENTS)
        sock.setblocking(False)
        return sock
    except OSError as err:
        log("no event stream (%s), checking on a timer only" % err)
        return None


def main():
    lock = open(os.path.join(RUNTIME, "blomst-float-sizes.lock"), "w")
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        return 0                                   # already running
    if not SIGNATURE:
        print("float_sizes: not inside a Hyprland session", file=sys.stderr)
        return 1
    tracker = Tracker()
    tracker.scan(first=True)
    write_rules(tracker.saved, tracker.options)
    write_kitty(tracker.saved, tracker.options)
    events = connect_events()
    log("started, remembering %d kinds of window, options %s, events %s"
        % (len(tracker.saved), tracker.options, "on" if events else "off"))
    failures = 0
    burst_until = 0.0
    while failures < 20:                           # Hyprland gone for good: stop
        busy = time.monotonic() < burst_until or tracker.fresh or tracker.pending
        wait = BURST_SECONDS if busy else POLL_SECONDS
        if events is not None:
            ready, _, _ = select.select([events], [], [], wait)
            if ready:
                try:
                    data = events.recv(65536)
                except OSError:
                    data = b""
                if not data:                       # stream closed: carry on with the timer
                    events = None
                elif any(e in data for e in WAKE_EVENTS):
                    burst_until = time.monotonic() + BURST_LENGTH
        else:
            time.sleep(wait)
        failures = 0 if tracker.scan() else failures + 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
