"""Process data for the task manager (Ctrl + Shift + Esc).

Everything is sorted into plain-language sections, so you can tell what is safe to end:
  app         open windows, with all their child processes
  background  apps that are running without a window (Steam in the tray, ...)
  other       small helpers and things we do not recognise
  desktop     the pieces your desktop is made of (bar, wallpaper, sound, ...)
Each row also says what it is and how safe it is to end:
  safe        nothing important stops
  caution     a part of the desktop stops working (the row says which)
  protected   ending it would end your session, so there is no button
No Qt in here, so it can be tried from a terminal:  python3 tasks.py
"""
import glob
import json
import os
import signal
import subprocess
import time

import psutil

# Programs that run many unrelated things: never grouped by name, and never taken for an app
GENERIC = {"sh", "bash", "zsh", "dash", "fish", "python", "python3", "node", "perl", "ruby", "lua", "luajit",
           "awk", "gawk", "sleep", "env", "timeout", "setsid", "sudo", "java", "wine", "wine64", "wineserver",
           "bwrap", "socat", "flatpak", "systemctl"}

# name -> (section, safety, what it is, what stops if you end it)
KNOWN = {
    # The session itself
    "Hyprland": ("desktop", "protected", "The window manager. Everything you see runs inside it", ""),
    "start-hyprland": ("desktop", "protected", "Starts Hyprland and restarts it if it crashes", ""),
    "Xwayland": ("desktop", "protected", "Runs older apps made for X11", ""),
    "systemd": ("desktop", "protected", "Starts and looks after your background services", ""),
    "(sd-pam)": ("desktop", "protected", "Part of your login", ""),
    "dbus-broker": ("desktop", "protected", "Lets programs talk to each other", ""),
    "dbus-broker-launch": ("desktop", "protected", "Lets programs talk to each other", ""),
    "dbus-daemon": ("desktop", "protected", "Lets programs talk to each other", ""),
    "waitpid": ("desktop", "protected", "Part of your login session", ""),
    "xdg-desktop-portal": ("desktop", "protected", "Lets apps open file pickers, share the screen and take screenshots", ""),
    "xdg-desktop-portal-hyprland": ("desktop", "protected", "Screen sharing and screenshots for apps", ""),
    "xdg-desktop-portal-gtk": ("desktop", "caution", "File picker windows for apps", "Open and save dialogs stop working"),
    "xdg-document-portal": ("desktop", "caution", "Lets sandboxed apps open your files", "Some apps cannot open files"),
    "xdg-permission-store": ("desktop", "caution", "Remembers which apps may do what", "Apps may ask for permissions again"),
    # Your desktop's own pieces
    "eww": ("desktop", "caution", "The bar, widgets and notifications", "The bar and notifications disappear until you log in again"),
    "hyprpaper": ("desktop", "caution", "Draws your wallpaper", "The wallpaper goes black until you pick one again"),
    "hypridle": ("desktop", "caution", "Locks the screen when you step away", "The screen stops locking by itself"),
    "hyprsunset": ("desktop", "caution", "Night light", "Colours go back to normal"),
    "pipewire": ("desktop", "caution", "Sound", "Sound stops for a moment (it restarts by itself)"),
    "pipewire-pulse": ("desktop", "caution", "Sound for older apps", "Sound stops for a moment (it restarts by itself)"),
    "wireplumber": ("desktop", "caution", "Picks your speakers and microphone", "Sound may stop until it restarts"),
    "nm-applet": ("desktop", "safe", "Network icon in the tray", "The network icon disappears (your internet keeps working)"),
    "dconf-service": ("desktop", "caution", "Stores settings for apps", "Apps may not save their settings"),
    "gnome-keyring-daemon": ("desktop", "caution", "Keeps your saved passwords", "Apps may ask for passwords again"),
    "polkit-gnome-authentication-agent-1": ("desktop", "caution", "Asks for your password when an app needs admin rights", "Those prompts stop appearing"),
    # Helpers that are fine to end
    "at-spi-bus-launcher": ("other", "safe", "Accessibility support (screen readers)", ""),
    "at-spi2-registryd": ("other", "safe", "Accessibility support (screen readers)", ""),
    "gvfsd": ("other", "safe", "Trash, USB drives and network folders in file managers", ""),
    "gvfsd-fuse": ("other", "safe", "Shows network folders as normal folders", ""),
    "gvfsd-metadata": ("other", "safe", "Remembers file details for file managers", ""),
    "gvfsd-trash": ("other", "safe", "The trash for file managers", ""),
    "gvfsd-network": ("other", "safe", "Network folders for file managers", ""),
    "gvfs-udisks2-volume-monitor": ("other", "safe", "Notices USB drives being plugged in", ""),
    "obexd": ("other", "safe", "Receives files over Bluetooth", ""),
    "appimagelauncherd": ("other", "safe", "Adds downloaded AppImages to your app list", ""),
    "chrome_crashpad_handler": ("other", "safe", "Crash reporter for an app", ""),
    "glycin-image-rs": ("other", "safe", "Loads images for GTK apps", ""),
    "fusermount3": ("other", "safe", "Part of the file sharing portal", ""),
    "playerctl": ("other", "safe", "Reads what music is playing, for the bar", ""),
}
# Recognised by their command line instead of their name
KNOWN_CMD = [
    ("float_sizes.py", ("desktop", "safe", "Remembers the size of floating windows", "Floating windows stop remembering their size")),
    ("notification_handler.py", ("desktop", "caution", "Shows your notifications", "Notifications stop showing")),
    ("uwsm/signal-handler", ("desktop", "protected", "Part of your login session", "")),
    ("wayland-session", ("desktop", "protected", "Part of your login session", "")),
    ("blomst/settings/main.py", ("other", "safe", "Blomst Settings", "")),
]
# Prettier names for the desktop pieces
DISPLAY_NAMES = {"eww": "Bar and widgets", "hyprpaper": "Wallpaper", "hypridle": "Screen lock timer",
                 "hyprsunset": "Night light", "pipewire": "Sound (PipeWire)", "pipewire-pulse": "Sound for older apps",
                 "wireplumber": "Sound devices", "nm-applet": "Network icon", "Hyprland": "Hyprland",
                 "float_sizes.py": "Floating window sizes", "notification_handler.py": "Notifications",
                 "appimagelauncherd": "AppImage helper", "obexd": "Bluetooth file receiver",
                 "dconf-service": "App settings store", "chrome_crashpad_handler": "Crash reporter",
                 "glycin-image-rs": "Image loader", "playerctl": "Music info for the bar",
                 "gnome-keyring-daemon": "Password keyring", "blomst/settings/main.py": "Blomst Settings"}
# Several small pieces shown as one row: label -> (row key, name, what it is)
GROUPS = {
    "(sd-pam)": ("session", "Login session", "Keeps you logged in"),
    "waitpid": ("session", "Login session", "Keeps you logged in"),
    "uwsm/signal-handler": ("session", "Login session", "Keeps you logged in"),
    "wayland-session": ("session", "Login session", "Keeps you logged in"),
    "start-hyprland": ("session", "Login session", "Keeps you logged in"),
    "dbus-broker": ("dbus", "Program messaging (D-Bus)", "Lets programs talk to each other"),
    "dbus-broker-launch": ("dbus", "Program messaging (D-Bus)", "Lets programs talk to each other"),
    "dbus-daemon": ("dbus", "Program messaging (D-Bus)", "Lets programs talk to each other"),
    "xdg-desktop-portal": ("portals", "App portals", "File pickers, screen sharing and screenshots for apps"),
    "xdg-desktop-portal-hyprland": ("portals", "App portals", "File pickers, screen sharing and screenshots for apps"),
    "xdg-desktop-portal-gtk": ("portals", "App portals", "File pickers, screen sharing and screenshots for apps"),
    "xdg-document-portal": ("portals", "App portals", "File pickers, screen sharing and screenshots for apps"),
    "xdg-permission-store": ("portals", "App portals", "File pickers, screen sharing and screenshots for apps"),
    "fusermount3": ("portals", "App portals", "File pickers, screen sharing and screenshots for apps"),
    "pipewire": ("sound", "Sound", "Plays sound and records from your microphone"),
    "pipewire-pulse": ("sound", "Sound", "Plays sound and records from your microphone"),
    "wireplumber": ("sound", "Sound", "Plays sound and records from your microphone"),
    "gvfsd": ("gvfs", "File manager helpers", "Trash, USB drives and network folders in file managers"),
    "gvfsd-fuse": ("gvfs", "File manager helpers", "Trash, USB drives and network folders in file managers"),
    "gvfsd-metadata": ("gvfs", "File manager helpers", "Trash, USB drives and network folders in file managers"),
    "gvfsd-trash": ("gvfs", "File manager helpers", "Trash, USB drives and network folders in file managers"),
    "gvfsd-network": ("gvfs", "File manager helpers", "Trash, USB drives and network folders in file managers"),
    "gvfs-udisks2-volume-monitor": ("gvfs", "File manager helpers", "Trash, USB drives and network folders in file managers"),
    "at-spi-bus-launcher": ("a11y", "Accessibility", "Support for screen readers"),
    "at-spi2-registryd": ("a11y", "Accessibility", "Support for screen readers"),
}
SAFETY_RANK = {"safe": 0, "caution": 1, "protected": 2}
# Things whose children belong to them (the bar's little scripts are part of the bar)
OWNS_CHILDREN = {"eww", "hyprpaper", "hypridle", "nm-applet", "gvfsd"}

DESKTOP_DIRS = ["/usr/share/applications", os.path.expanduser("~/.local/share/applications"),
                "/var/lib/flatpak/exports/share/applications",
                os.path.expanduser("~/.local/share/flatpak/exports/share/applications")]


def _desktop_entries():
    """Two maps from desktop files, both lower case -> (name, icon):
    by window class or file name (for windows), and by program name (for apps without a window)."""
    by_class, by_program = {}, {}
    for folder in DESKTOP_DIRS:
        for path in glob.glob(os.path.join(folder, "*.desktop")):
            fields, inside = {}, False
            try:
                with open(path, encoding="utf-8", errors="replace") as f:
                    for line in f:
                        line = line.strip()
                        if line.startswith("["):
                            inside = line == "[Desktop Entry]"
                        elif inside and "=" in line:
                            k, v = line.split("=", 1)
                            fields.setdefault(k.strip(), v.strip())
            except OSError:
                continue
            entry = (fields.get("Name", ""), fields.get("Icon", ""))
            base = os.path.basename(path)[:-len(".desktop")].lower()
            by_class.setdefault(base, entry)
            if fields.get("StartupWMClass"):
                by_class[fields["StartupWMClass"].lower()] = entry
            program = os.path.basename(fields.get("Exec", "").split(" ")[0]).lower()
            if program and fields.get("NoDisplay", "false").lower() != "true" and fields.get("Type") == "Application":
                by_class.setdefault(program, entry)
                by_program.setdefault(program, entry)
                by_program.setdefault(base, entry)
    return by_class, by_program


def _windows():
    try:
        out = subprocess.run(["hyprctl", "clients", "-j"], capture_output=True, text=True, timeout=2).stdout
        return json.loads(out)
    except (OSError, ValueError, subprocess.SubprocessError):
        return []


def _known(proc):
    for needle, info in KNOWN_CMD:
        if needle in proc["cmd"]:
            return needle, info
    if proc["name"] in KNOWN:
        return proc["name"], KNOWN[proc["name"]]
    return None, None


class Tasks:
    def __init__(self):
        self._procs = {}            # pid -> psutil.Process, kept so cpu_percent has a previous sample
        self._by_class, self._by_program = _desktop_entries()
        self._me = psutil.Process().pid
        self._user = psutil.Process().username()
        self.cpu_count = psutil.cpu_count() or 1

    def _sample(self):
        """Every process of this user: pid -> info."""
        seen = {}
        for p in psutil.process_iter(["pid", "ppid", "name", "username", "memory_info", "cmdline"]):
            info = p.info
            if info["username"] != self._user or not info["memory_info"] or info["pid"] == self._me:
                continue
            proc = self._procs.get(info["pid"])
            if proc is None or proc.create_time() != p.create_time():
                proc = p
                try:
                    proc.cpu_percent(None)       # first call only primes the counter
                except psutil.Error:
                    continue
            try:
                cpu = proc.cpu_percent(None) / self.cpu_count
            except psutil.Error:
                continue
            seen[info["pid"]] = {
                "proc": proc, "ppid": info["ppid"], "name": info["name"] or "?",
                "cpu": cpu, "mem": info["memory_info"].rss,
                "cmd": " ".join(info["cmdline"] or [])[:160],
            }
        self._procs = {pid: v["proc"] for pid, v in seen.items()}
        return seen

    def snapshot(self):
        procs = self._sample()
        children = {}
        for pid, p in procs.items():
            children.setdefault(p["ppid"], []).append(pid)
        claimed = set()

        def tree(root):
            out, stack = [], [root]
            while stack:
                pid = stack.pop()
                if pid in procs and pid not in out and pid not in claimed:
                    out.append(pid)
                    stack.extend(children.get(pid, []))
            return out

        groups = {}

        def add(key, pids, **fields):
            group = groups.setdefault(key, dict({"key": key, "title": "", "windows": 0, "pids": []}, **fields))
            for pid in pids:
                if pid not in claimed:
                    group["pids"].append(pid)
                    claimed.add(pid)
            return group

        # 1. Open windows
        for w in _windows():
            pid = w.get("pid", 0)
            if pid not in procs:
                continue
            key = "app:%d" % pid
            if key not in groups:
                cls = w.get("class") or w.get("initialClass") or procs[pid]["name"]
                name, icon = self._by_class.get(cls.lower(), ("", ""))
                if not name:
                    name, icon = self._by_class.get(procs[pid]["name"].lower(), ("", ""))
                title = w.get("title", "")
                add(key, tree(pid), section="app", safety="safe",
                    name=name or (title if 0 < len(title) <= 30 else cls), icon=icon or cls.lower(),
                    title=title, about="", consequence="")
            groups[key]["windows"] += 1

        # 2. Desktop pieces and known helpers (protected ones first, so nothing else claims them)
        order = sorted(procs, key=lambda pid: 0 if (_known(procs[pid])[1] or ("",))[0:2] == ("desktop", "protected") else 1)
        for pid in order:
            if pid in claimed:
                continue
            label, info = _known(procs[pid])
            if not info:
                continue
            section, safety, about, consequence = info
            owns = procs[pid]["name"] in OWNS_CHILDREN
            key, name = "known:" + label, DISPLAY_NAMES.get(label, label)
            if label in GROUPS:
                key, name, about = "known:" + GROUPS[label][0], GROUPS[label][1], GROUPS[label][2]
            group = add(key, tree(pid) if owns else [pid], section=section, safety=safety,
                        name=name, icon="", about=about, consequence=consequence)
            if SAFETY_RANK[safety] > SAFETY_RANK[group["safety"]]:      # a group is as careful as its most careful part
                group["safety"], group["section"] = safety, section
            if consequence and not group["consequence"]:
                group["consequence"] = consequence

        # 3. Apps without a window: the program has an entry in the app list
        for pid, p in procs.items():
            if pid in claimed or p["name"] in GENERIC:
                continue
            entry = self._by_program.get(p["name"].lower())
            if not entry or not entry[0]:
                continue
            root = pid
            while procs.get(procs[root]["ppid"], {}).get("name") in GENERIC and procs[root]["ppid"] not in claimed:
                root = procs[root]["ppid"]          # include launch scripts (steam.sh starts steam)
            name, icon = entry
            add("bg:" + name, tree(root), section="background", safety="safe", name=name, icon=icon,
                about="Running without a window", consequence="")
        # Leftover pieces of those apps, recognised by where they live (Steam's runtime, ...)
        for key, group in list(groups.items()):
            if group["section"] != "background":
                continue
            folder = "/%s/" % group["name"].lower()
            for pid, p in procs.items():
                if pid not in claimed and folder in p["cmd"].lower():
                    add(key, tree(pid))

        # 4. Everything else, grouped by name (but generic programs one by one)
        for pid, p in procs.items():
            if pid in claimed:
                continue
            key = "other:%d" % pid if p["name"] in GENERIC else "other:" + p["name"]
            parent = procs.get(p["ppid"], {}).get("name", "")
            about = ("Started by " + parent) if parent and parent not in ("systemd", "bash", "sh") else ""
            add(key, [pid], section="other", safety="safe", name=p["name"], icon="", title=p["cmd"],
                about=about, consequence="")

        rows = []
        for group in groups.values():
            pids = group.pop("pids")
            if not pids:
                continue
            group["count"] = len(pids)
            group["pidList"] = pids
            group["cpu"] = round(sum(procs[p]["cpu"] for p in pids), 1)
            group["memory"] = sum(procs[p]["mem"] for p in pids)
            group["protected"] = group["safety"] == "protected"
            group["kind"] = "app" if group["section"] in ("app", "background") and group["icon"] else group["section"]
            rows.append(group)

        mem = psutil.virtual_memory()
        return {
            "rows": rows,
            "cpu": round(psutil.cpu_percent(None), 1),
            "memoryUsed": mem.total - mem.available,
            "memoryTotal": mem.total,
            "processes": len(procs),
        }

    def end(self, pids, force=False):
        """Ask the processes to stop (or make them). Returns how many were signalled."""
        sent = 0
        for pid in pids:
            if pid == self._me:
                continue
            try:
                os.kill(int(pid), signal.SIGKILL if force else signal.SIGTERM)
                sent += 1
            except (ProcessLookupError, PermissionError, ValueError):
                pass
        return sent

    @staticmethod
    def alive(pids):
        return [p for p in pids if psutil.pid_exists(int(p))]


if __name__ == "__main__":
    t = Tasks()
    t.snapshot()
    time.sleep(1)
    snap = t.snapshot()
    print("CPU %.1f%%  memory %.1f / %.1f GB  %d processes" % (
        snap["cpu"], snap["memoryUsed"] / 1e9, snap["memoryTotal"] / 1e9, snap["processes"]))
    for section in ("app", "background", "other", "desktop"):
        print("\n== %s" % section)
        for r in sorted((r for r in snap["rows"] if r["section"] == section), key=lambda r: -r["memory"]):
            print("  %-9s %-26s %3d procs %5.1f%% %7.1f MB  %s%s" % (
                r["safety"], r["name"][:26], r["count"], r["cpu"], r["memory"] / 1e6, r["about"][:50],
                ("  -> " + r["consequence"]) if r["consequence"] else ""))
