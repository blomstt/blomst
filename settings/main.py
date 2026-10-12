#!/usr/bin/env python3
"""Blomst Settings: a small settings window for this Hyprland setup.

Needs: sudo pacman -S --needed pyside6 qt6-wayland
Run:   python ~/blomst/settings/main.py
"""
import getpass
import json
import os
import socket
import subprocess
import sys

from PySide6.QtCore import Property, QObject, QTimer, QUrl, Signal, Slot
from PySide6.QtGui import QFont, QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuick import QQuickWindow

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import backend as cfg  # noqa: E402

WINDOW_CLASS = "blomst-settings"
STATE = os.path.join(cfg.CONFIG, "blomst-settings/state.json")    # window state, e.g. the last page
MONITOR_CONFIRM_SECONDS = 15


class Backend(QObject):
    paletteChanged = Signal()
    settingsChanged = Signal()
    presetsChanged = Signal()
    wallpapersChanged = Signal()
    currentWallpaperChanged = Signal()
    appRulesChanged = Signal()
    openAppsChanged = Signal()
    undoChanged = Signal()
    lastPageChanged = Signal()
    monitorsChanged = Signal()
    monitorConfirmChanged = Signal()
    keybindsChanged = Signal()
    autostartChanged = Signal()
    # A setting was written (key), or could not be (key, reason)
    saved = Signal(str)
    failed = Signal(str, str)
    undone = Signal(str)

    def __init__(self):
        super().__init__()
        self._palette = cfg.read_palette()
        self._settings = cfg.read_settings()
        self._presets = self._load_presets()
        self._wallpapers = self._load_wallpapers()
        self._current = cfg.current_wallpaper()
        self._app_rules = cfg.read_app_rules()
        self._open_apps = []
        self._preparing = []
        self._undo = []                 # (key, previous value), newest last
        self._state = self._load_state()
        self._monitors = cfg.monitors()
        self._monitor_backup = None     # monitor lines to go back to while a change awaits confirmation
        self._monitor_pending = None
        self._countdown = 0
        self._keybinds = cfg.read_keybinds()
        self._autostart = cfg.read_autostart()
        self._layouts = [{"value": c, "label": n} for c, n in cfg.kb_layouts()]
        # Poll for outside changes (wallpaper picker, hand edits). Cheap: a few small files.
        self._timer = QTimer(self)
        self._timer.setInterval(1500)
        self._timer.timeout.connect(self.refresh)
        self._timer.start()
        self._monitor_timer = QTimer(self)
        self._monitor_timer.setInterval(1000)
        self._monitor_timer.timeout.connect(self._tick_monitor)

    # ----- data for QML -----
    def _load_presets(self):
        out = []
        for p in cfg.read_presets():
            wall = p.get("wallpaper", "")
            out.append({
                "name": p["name"],
                "description": p.get("description", ""),
                "wallpaper": wall,
                "image": self._url(cfg.thumbnail(wall)),
            })
        return out

    def _load_wallpapers(self):
        return [{"name": n, "image": self._url(cfg.thumbnail(n))} for n in cfg.list_wallpapers()]

    @staticmethod
    def _url(path):
        return QUrl.fromLocalFile(path).toString() if path else ""

    @staticmethod
    def _load_state():
        try:
            with open(STATE, encoding="utf-8") as f:
                data = json.load(f)
            return data if isinstance(data, dict) else {}
        except (OSError, ValueError):
            return {}

    def _save_state(self):
        try:
            os.makedirs(os.path.dirname(STATE), exist_ok=True)
            with open(STATE, "w", encoding="utf-8") as f:
                json.dump(self._state, f, indent=2)
        except OSError:
            pass

    @Slot()
    def refresh(self):
        palette = cfg.read_palette()
        if palette != self._palette:
            self._palette = palette
            self.paletteChanged.emit()
        settings = cfg.read_settings()
        if settings != self._settings:
            self._settings = settings
            self.settingsChanged.emit()
        current = cfg.current_wallpaper()
        if current != self._current:
            self._current = current
            self.currentWallpaperChanged.emit()
        # New pictures in ~/wallpapers need converting and a preview before they can be listed.
        waiting = cfg.unprepared_wallpapers()
        if waiting and waiting != self._preparing:
            cfg.prepare_wallpapers()
        self._preparing = waiting
        walls = self._load_wallpapers()
        if walls != self._wallpapers:
            self._wallpapers = walls
            self.wallpapersChanged.emit()

    palette = Property("QVariantMap", lambda self: self._palette, notify=paletteChanged)
    settings = Property("QVariantMap", lambda self: self._settings, notify=settingsChanged)
    defaults = Property("QVariantMap", lambda self: cfg.DEFAULTS, constant=True)
    presets = Property("QVariantList", lambda self: self._presets, notify=presetsChanged)
    wallpapers = Property("QVariantList", lambda self: self._wallpapers, notify=wallpapersChanged)
    currentWallpaper = Property(str, lambda self: self._current, notify=currentWallpaperChanged)
    currentWallpaperImage = Property(str, lambda self: self._url(cfg.thumbnail(self._current)), notify=currentWallpaperChanged)
    appRules = Property("QVariantList", lambda self: self._app_rules, notify=appRulesChanged)
    openApps = Property("QVariantList", lambda self: self._open_apps, notify=openAppsChanged)
    canUndo = Property(bool, lambda self: bool(self._undo), notify=undoChanged)
    monitors = Property("QVariantList", lambda self: self._monitors, notify=monitorsChanged)
    monitorPending = Property(bool, lambda self: self._monitor_pending is not None, notify=monitorConfirmChanged)
    monitorCountdown = Property(int, lambda self: self._countdown, notify=monitorConfirmChanged)
    keybinds = Property("QVariantList", lambda self: self._keybinds, notify=keybindsChanged)
    autostart = Property("QVariantList", lambda self: self._autostart, notify=autostartChanged)
    kbLayouts = Property("QVariantList", lambda self: self._layouts, constant=True)
    nightLightAvailable = Property(bool, lambda self: cfg.night_light_available(), constant=True)

    def _with_custom(self, found, key):
        current = self._settings.get(key, "")
        if current and all(b["value"] != current for b in found):
            found.append({"value": current, "label": current})     # a custom command you typed in
        return found

    @Property("QVariantList", notify=settingsChanged)
    def browsers(self):
        return self._with_custom([{"value": c, "label": n} for c, n in cfg.installed_browsers()], "browser")

    @Property("QVariantList", notify=settingsChanged)
    def terminals(self):
        return self._with_custom([{"value": c, "label": n} for c, n in cfg.installed_terminals()], "terminal")

    def _get_last_page(self):
        return self._state.get("page", "home")

    def _set_last_page(self, page):
        if page != self._state.get("page"):
            self._state["page"] = page
            self._save_state()
            self.lastPageChanged.emit()

    lastPage = Property(str, _get_last_page, _set_last_page, notify=lastPageChanged)

    userName = Property(str, lambda self: getpass.getuser(), constant=True)
    hostName = Property(str, lambda self: socket.gethostname(), constant=True)

    # ----- settings, with undo -----
    def _write(self, key, value):
        if not cfg.write_setting(key, value):
            return False
        self._settings = cfg.read_settings()
        # Some writes take effect a moment later (hypridle starting), so trust what was asked for
        if key in ("idle_enabled",):
            self._settings[key] = bool(value)
        self.settingsChanged.emit()
        return True

    @Slot(str, "QVariant", result=bool)
    def setValue(self, key, value):
        before = self._settings.get(key)
        if before == value:
            return True
        if not self._write(key, value):
            reason = {"kb_layout": "Unknown keyboard layout"}.get(key, "Nothing was changed")
            self.failed.emit(key, reason)
            return False
        self._undo.append((key, before))
        del self._undo[:-50]
        self.undoChanged.emit()
        self.saved.emit(key)
        return True

    @Slot(str)
    def resetValue(self, key):
        if key in cfg.DEFAULTS:
            self.setValue(key, cfg.DEFAULTS[key])

    @Slot()
    def undo(self):
        while self._undo:
            key, value = self._undo.pop()
            if self._write(key, value):
                self.undoChanged.emit()
                self.undone.emit(key)
                return
        self.undoChanged.emit()

    @Slot(str)
    def applyWallpaper(self, name):
        if cfg.apply_wallpaper(name):
            self._current = name
            self.currentWallpaperChanged.emit()

    @Slot(str, str, result=bool)
    def savePreset(self, name, description):
        ok = cfg.save_preset(name, description)
        self._presets = self._load_presets()
        self.presetsChanged.emit()
        return ok

    @Slot(str)
    def removePreset(self, name):
        cfg.remove_preset(name)
        self._presets = self._load_presets()
        self.presetsChanged.emit()

    @Slot(str)
    def applyPreset(self, name):
        cfg.apply_preset(name)
        self.refresh()

    @Slot()
    def refreshOpenApps(self):
        self._open_apps = cfg.open_app_classes()
        self.openAppsChanged.emit()

    @Slot(str, str, int, bool, result=bool)
    def addAppRule(self, cls, screen, workspace, floating):
        ok = cfg.add_app_rule(cls, screen, workspace, floating)
        self._app_rules = cfg.read_app_rules()
        self.appRulesChanged.emit()
        return ok

    @Slot(str)
    def removeAppRule(self, cls):
        cfg.remove_app_rule(cls)
        self._app_rules = cfg.read_app_rules()
        self.appRulesChanged.emit()

    @Slot()
    def clearNotifications(self):
        cfg.clear_notifications()

    # ----- displays: changes are tried live and kept only when confirmed -----
    @Slot()
    def refreshMonitors(self):
        if self._monitor_pending is None:
            self._monitors = cfg.monitors()
            self.monitorsChanged.emit()

    @Slot(str, str, float, result=bool)
    def applyMonitor(self, name, mode, scale):
        if self._monitor_pending is not None:
            return False
        mons = cfg.monitors()
        target = next((m for m in mons if m["name"] == name), None)
        if not target:
            return False
        backup = cfg.monitor_lines(mons)
        target["mode"] = cfg._closest_mode(target, mode)
        target["scale"] = scale
        lines = cfg.monitor_lines(mons)
        if lines == backup:
            return True
        if not cfg.apply_monitor_lines(lines):
            cfg.apply_monitor_lines(backup)
            self.failed.emit("monitor", "The display did not accept that")
            return False
        self._monitor_backup, self._monitor_pending = backup, lines
        self._countdown = MONITOR_CONFIRM_SECONDS
        self._monitor_timer.start()
        self.monitorConfirmChanged.emit()
        QTimer.singleShot(500, self._reload_monitors)
        return True

    def _reload_monitors(self):
        self._monitors = cfg.monitors()
        self.monitorsChanged.emit()

    def _tick_monitor(self):
        self._countdown -= 1
        if self._countdown <= 0:
            self.revertMonitors()
        else:
            self.monitorConfirmChanged.emit()

    @Slot()
    def keepMonitors(self):
        if self._monitor_pending is not None:
            cfg.write_monitor_lines(self._monitor_pending)
            self.saved.emit("monitor")
        self._end_monitor_change()

    @Slot()
    def revertMonitors(self):
        if self._monitor_backup is not None:
            cfg.apply_monitor_lines(self._monitor_backup)
            self.undone.emit("monitor")
        self._end_monitor_change()

    def _end_monitor_change(self):
        self._monitor_timer.stop()
        self._monitor_backup = self._monitor_pending = None
        self._countdown = 0
        self.monitorConfirmChanged.emit()
        QTimer.singleShot(500, self._reload_monitors)

    # ----- keybinds and startup apps -----
    @Slot()
    def refreshKeybinds(self):
        self._keybinds = cfg.read_keybinds()
        self.keybindsChanged.emit()

    @Slot(str, result=bool)
    def addAutostart(self, command):
        ok = cfg.add_autostart(command)
        self._autostart = cfg.read_autostart()
        self.autostartChanged.emit()
        return ok

    @Slot(str)
    def removeAutostart(self, command):
        cfg.remove_autostart(command)
        self._autostart = cfg.read_autostart()
        self.autostartChanged.emit()

    # ----- opening things -----
    @staticmethod
    def _open(path):
        for cmd in (["code", path], ["xdg-open", path]):
            try:
                subprocess.Popen(cmd, start_new_session=True,
                                 stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                return
            except OSError:
                continue

    @Slot()
    def openConfigFolder(self):
        self._open(os.path.dirname(HERE))

    @Slot()
    def openKeybindsFile(self):
        self._open(os.path.realpath(cfg.KEYBINDS))


def focus_running_window():
    """Super + S again should bring the open window forward, not start a second one."""
    try:
        out = subprocess.run(["hyprctl", "clients", "-j"], capture_output=True, text=True, timeout=2).stdout
        if any(c.get("class") == WINDOW_CLASS for c in json.loads(out)):
            subprocess.run(["hyprctl", "dispatch", "focuswindow", "class:^(%s)$" % WINDOW_CLASS],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=2)
            return True
    except (OSError, ValueError, subprocess.SubprocessError):
        pass
    return False


def main():
    if "--new-window" not in sys.argv and focus_running_window():
        return 0
    QQuickWindow.setDefaultAlphaBuffer(True)          # allow a see-through window (for blur)
    # Colours and fonts are our own; otherwise qt6ct swaps the font for items made after startup
    QGuiApplication.setDesktopSettingsAware(False)
    app = QGuiApplication(sys.argv)
    app.setApplicationName("Blomst Settings")
    app.setDesktopFileName(WINDOW_CLASS)            # this becomes the window class in Hyprland
    app.setFont(QFont("Iosevka", 11))

    backend = Backend()
    engine = QQmlApplicationEngine()
    engine.rootContext().setContextProperty("backend", backend)
    engine.load(QUrl.fromLocalFile(os.path.join(HERE, "Main.qml")))
    if not engine.rootObjects():
        print("Blomst Settings: the window failed to load, see the errors above.", file=sys.stderr)
        return 1
    return app.exec()


if __name__ == "__main__":
    sys.exit(main())
