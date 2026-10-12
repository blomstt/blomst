#!/usr/bin/env python3
"""Remembers the size you give floating windows and re-applies it next time.

Remembered sizes are written out as Hyprland window rules (hypr/user/float-sizes.conf),
so a window is created at its size straight away. As a fallback, a window that still
opens at another size is resized after it appears.

Sizes are kept per app and per kind of window (window class + the title the window
opens with), so an app's main window and its dialogs don't overwrite each other.
Saved in ~/.config/blomst-settings/float-sizes.json. Started by Hyprland (exec-once).
"""
import fcntl
import json
import os
import re
import socket
import sys
import time

RUNTIME = os.environ.get("XDG_RUNTIME_DIR", "/tmp")
SIGNATURE = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", "")
CONTROL = os.path.join(RUNTIME, "hypr", SIGNATURE, ".socket.sock")
STORE = os.path.join(os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config")),
                     "blomst-settings", "float-sizes.json")
RULES = os.path.join(os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config")),
                     "hypr", "user", "float-sizes.conf")
KITTY = os.path.join(os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config")),
                     "kitty", "float-size.conf")
RULES_DELAY = 1.5      # seconds of no change before rewriting the rules (not on every step of a drag)
LOG = os.path.join(os.path.dirname(STORE), "float-sizes.log")
POLL_SECONDS = 0.3     # fast, so a resize is caught even if you close the window right after
MIN_SIZE = 80          # ignore tooltips, menus and other tiny windows
TOLERANCE = 2          # pixels; smaller differences are not a real resize
RETRIES = 4            # a resize sent while a window is still appearing can land wrong; re-check and redo


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


def clients():
    """All windows, or None if Hyprland could not be reached."""
    try:
        return json.loads(ask("j/clients"))
    except (OSError, ValueError):
        return None


def key_of(client):
    cls = client.get("class") or ""
    if not cls:
        return None
    return cls + "|" + (client.get("initialTitle") or "")


def usable(client):
    size = client.get("size") or [0, 0]
    return (client.get("floating") is True and client.get("mapped", True)
            and not client.get("fullscreen") and len(size) == 2
            and size[0] >= MIN_SIZE and size[1] >= MIN_SIZE and key_of(client) is not None)


def differs(a, b):
    return abs(a[0] - b[0]) > TOLERANCE or abs(a[1] - b[1]) > TOLERANCE


def load():
    try:
        with open(STORE, encoding="utf-8") as f:
            data = json.load(f)
        return {k: [int(v[0]), int(v[1])] for k, v in data.items() if isinstance(v, list) and len(v) == 2}
    except (OSError, ValueError, TypeError):
        return {}


def save(sizes):
    os.makedirs(os.path.dirname(STORE), exist_ok=True)
    tmp = STORE + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(sizes, f, indent=2, sort_keys=True)
    os.replace(tmp, STORE)


def escape(text):
    """Escape only real regex characters (Hyprland's regex engine dislikes stray backslashes)."""
    return re.sub(r"([.^$*+?()\[\]{}|\\])", r"\\\1", text)


def write_rules(sizes):
    """Turn the remembered sizes into Hyprland window rules. Hyprland reloads them by itself."""
    lines = ["# Written by ~/scripts/float_sizes.py. Sizes you gave floating windows.", ""]
    for key in sorted(sizes):
        cls, _, title = key.partition("|")
        if "," in key:                     # a comma would break the rule syntax; the fallback resize covers these
            continue
        match = "match:class ^(%s)$" % escape(cls)
        if title:
            match += ", match:initial_title ^(%s)$" % escape(title)
        lines.append("windowrule = %s, size %d %d" % (match, sizes[key][0], sizes[key][1]))
    text = "\n".join(lines) + "\n"
    try:
        target = os.path.realpath(RULES)
        os.makedirs(os.path.dirname(target), exist_ok=True)
        try:
            with open(target, encoding="utf-8") as f:
                if f.read() == text:
                    return
        except OSError:
            pass
        with open(target, "w", encoding="utf-8") as f:
            f.write(text)
        log("wrote %d size rules" % (len(lines) - 2))
    except OSError as err:
        log("could not write rules: %s" % err)


def write_kitty(sizes):
    """kitty keeps its own memory of its last window size and asks for that when it opens,
    which overrides everything else. Tell it to ask for the remembered size instead."""
    size = sizes.get("kitty|kitty")
    if not size or not os.path.isdir(os.path.dirname(os.path.realpath(KITTY))):
        return
    text = ("# Written by ~/scripts/float_sizes.py. The size kitty asks for when it opens floating.\n"
            "remember_window_size no\ninitial_window_width %d\ninitial_window_height %d\n" % (size[0], size[1]))
    try:
        target = os.path.realpath(KITTY)
        try:
            with open(target, encoding="utf-8") as f:
                if f.read() == text:
                    return
        except OSError:
            pass
        with open(target, "w", encoding="utf-8") as f:
            f.write(text)
        log("kitty will open at %dx%d" % (size[0], size[1]))
    except OSError as err:
        log("could not write kitty size: %s" % err)


def resize(address, size):
    """Resize one window; the result goes in the log so problems can be traced."""
    try:
        reply = ask("/dispatch resizewindowpixel exact %d %d,address:%s" % (size[0], size[1], address))
    except OSError as err:
        reply = "failed: %s" % err
    log("resize %s to %dx%d -> %s" % (address, size[0], size[1], reply.strip()))


class Tracker:
    def __init__(self):
        self.saved = load()     # "class|initial title" -> [w, h]
        self.seen = {}          # address of each settled floating window -> last size we saw
        self.fresh = {}         # address -> size, for new windows still settling
        self.pending = {}       # address -> [wanted size, attempts], resizes being checked
        self.rules_due = None   # when to rewrite the Hyprland rules after a change

    def scan(self, first=False):
        """Give newly floating windows their remembered size, and learn from your resizes.

        `first` is the scan at startup: windows that are already open are left alone.
        Returns False if Hyprland could not be reached.
        """
        windows = clients()
        if windows is None:
            return False
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
            size, key = list(c["size"]), key_of(c)

            if address in self.pending:            # we resized it: check that it took
                want, attempts = self.pending[address]
                if not differs(want, size) or attempts >= RETRIES:
                    del self.pending[address]
                    self.seen[address] = size
                else:
                    resize(address, want)
                    self.pending[address] = [want, attempts + 1]
            elif address not in self.seen:         # just opened, or just switched to floating
                want = None if first else self.saved.get(key)
                if not want or not differs(want, size):
                    self.fresh.pop(address, None)
                    self.seen[address] = size
                elif address in self.fresh and not differs(self.fresh[address], size):
                    # same size on two checks in a row: it has finished appearing
                    del self.fresh[address]
                    resize(address, want)
                    self.pending[address] = [want, 1]
                else:
                    self.fresh[address] = size
            elif differs(self.seen[address], size):   # you resized it
                self.saved[key] = size
                self.seen[address] = size
                changed = True
                log("learned %s = %dx%d" % (key, size[0], size[1]))
        for book in (self.seen, self.fresh, self.pending):
            for address in list(book):
                if address not in alive:
                    del book[address]
        if changed:
            save(self.saved)
            self.rules_due = time.monotonic() + RULES_DELAY
        if self.rules_due is not None and time.monotonic() >= self.rules_due:
            self.rules_due = None
            write_rules(self.saved)
            write_kitty(self.saved)
        return True


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
    write_rules(tracker.saved)
    write_kitty(tracker.saved)
    log("started, remembering %d kinds of window" % len(tracker.saved))
    failures = 0
    while failures < 20:                           # Hyprland gone for good: stop
        time.sleep(POLL_SECONDS)
        failures = 0 if tracker.scan() else failures + 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
