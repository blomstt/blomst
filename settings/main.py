#!/usr/bin/env python3
"""Blomst Settings: a small settings window for this Hyprland setup.

Needs: sudo pacman -S --needed pyside6 qt6-wayland
Run:   python ~/blomst/settings/main.py
"""
import getpass
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


class Backend(QObject):
    paletteChanged = Signal()
    settingsChanged = Signal()
    presetsChanged = Signal()
    wallpapersChanged = Signal()
    currentWallpaperChanged = Signal()
    appRulesChanged = Signal()
    openAppsChanged = Signal()

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
        # Poll for outside changes (wallpaper picker, hand edits). Cheap: a few small files.
        self._timer = QTimer(self)
        self._timer.setInterval(1500)
        self._timer.timeout.connect(self.refresh)
        self._timer.start()

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
    presets = Property("QVariantList", lambda self: self._presets, notify=presetsChanged)
    wallpapers = Property("QVariantList", lambda self: self._wallpapers, notify=wallpapersChanged)
    currentWallpaper = Property(str, lambda self: self._current, notify=currentWallpaperChanged)
    appRules = Property("QVariantList", lambda self: self._app_rules, notify=appRulesChanged)
    openApps = Property("QVariantList", lambda self: self._open_apps, notify=openAppsChanged)
    @Property("QVariantList", notify=settingsChanged)
    def browsers(self):
        found = [{"value": cmd, "label": name} for cmd, name in cfg.installed_browsers()]
        current = self._settings.get("browser", "")
        if current and all(b["value"] != current for b in found):
            found.append({"value": current, "label": current})     # a custom command you typed in
        return found

    userName = Property(str, lambda self: getpass.getuser(), constant=True)
    hostName = Property(str, lambda self: socket.gethostname(), constant=True)

    # ----- actions from QML -----
    @Slot(str, "QVariant")
    def setValue(self, key, value):
        cfg.write_setting(key, value)
        self._settings = cfg.read_settings()
        self.settingsChanged.emit()

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
    def openConfigFolder(self):
        folder = os.path.dirname(HERE)
        for cmd in (["code", folder], ["xdg-open", folder]):
            try:
                subprocess.Popen(cmd, start_new_session=True,
                                 stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                return
            except OSError:
                continue


def main():
    QQuickWindow.setDefaultAlphaBuffer(True)          # allow a see-through window (for blur)
    app = QGuiApplication(sys.argv)
    app.setApplicationName("Blomst Settings")
    app.setDesktopFileName("blomst-settings")       # this becomes the window class in Hyprland
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
