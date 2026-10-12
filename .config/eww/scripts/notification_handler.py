#!/usr/bin/env python3
import dbus
import dbus.service
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib
import json
import os
import sys
import time

OPTIONS_FILE = os.path.expanduser("~/.config/blomst-settings/notifications.json")  # written by Blomst Settings
DEFAULT_OPTIONS = {"popups": True, "popup_seconds": 10, "history_limit": 50}
HISTORY_FILE = os.path.expanduser("~/.cache/eww/notification-history.json")
BUS_CMD = "busctl --user call org.freedesktop.Notifications /org/freedesktop/Notifications org.blomst.NotificationHistory"

popups = []   # ids currently shown as popups
history = []  # newest first: {id, app, summary, body, icon, time}
next_id = 1

def options():
    # Read on every notification so changes in Blomst Settings apply at once
    try:
        with open(OPTIONS_FILE) as f:
            data = json.load(f)
        return {**DEFAULT_OPTIONS, **(data if isinstance(data, dict) else {})}
    except (OSError, ValueError):
        return dict(DEFAULT_OPTIONS)

def load_history():
    global history, next_id
    try:
        with open(HISTORY_FILE) as f:
            history = json.load(f)[:max(1, int(options()["history_limit"]))]
    except (OSError, ValueError):
        history = []
    next_id = max((n["id"] for n in history), default=0) + 1

def save_history():
    try:
        os.makedirs(os.path.dirname(HISTORY_FILE), exist_ok=True)
        with open(HISTORY_FILE, "w") as f:
            json.dump(history, f)
    except OSError as e:
        print(f"Could not save history: {e}", file=sys.stderr)

def find(notif_id):
    return next((n for n in history if n["id"] == notif_id), None)

def esc(text):
    return " ".join(str(text).split()).replace('\\', '\\\\').replace('"', '\\"')

def shorten(text, limit):
    return text if len(text) <= limit else text[:limit - 1].rstrip() + "…"

def icon_widget(icon, size):
    if icon and os.path.isfile(os.path.expanduser(icon)):
        return f'(image :class "notif-icon" :image-width {size} :image-height {size} :path "{esc(os.path.expanduser(icon))}")'
    if icon:
        return f'(image :class "notif-icon" :icon "{esc(icon)}" :icon-size "{"dnd" if size >= 32 else "large-toolbar"}")'
    return '(label :class "notif-icon notif-icon-fallback" :text "")'

def popup_widget(n):
    s = esc(n["summary"])
    b = shorten(esc(n["body"]), 140)
    return f"""
(box :class "notif" :orientation "horizontal" :space-evenly false :spacing 10
  {icon_widget(n["icon"], 32)}
  (box :orientation "vertical" :space-evenly false :hexpand true :valign "center"
    (label :class "notif-summary" :xalign 0 :limit-width 32 :truncate true :text "{s}")
    {f'(label :class "notif-body" :xalign 0 :wrap true :text "{b}")' if b else ""}))
"""

def history_widget(n):
    s = esc(n["summary"])
    b = shorten(esc(n["body"]), 200)
    meta = esc(" · ".join(x for x in (n["app"], time.strftime("%H:%M", time.localtime(n["time"]))) if x))
    return f"""
(box :class "nc-item" :orientation "horizontal" :space-evenly false :spacing 8
  {icon_widget(n["icon"], 24)}
  (box :orientation "vertical" :space-evenly false :hexpand true
    (label :class "nc-meta" :xalign 0 :limit-width 26 :truncate true :text "{meta}")
    (label :class "notif-summary" :xalign 0 :limit-width 22 :truncate true :text "{s}")
    {f'(label :class "notif-body" :xalign 0 :wrap true :text "{b}")' if b else ""})
  (button :class "nc-dismiss" :valign "start" :tooltip "Dismiss"
          :onclick "{BUS_CMD} Dismiss u {n['id']}" ""))
"""

def print_state():
    shown = [n for n in history if n["id"] in popups]
    popup_yuck = "".join(popup_widget(n) for n in shown)
    if history:
        history_yuck = "".join(history_widget(n) for n in history)
    else:
        history_yuck = '(label :class "nc-empty" :vexpand true :text "No notifications")'
    state = {
        "popups": f'(box :class "notifications" :orientation "vertical" :space-evenly false {popup_yuck})'.replace('\n', ' '),
        "history": f'(box :class "nc-list" :orientation "vertical" :space-evenly false {history_yuck})'.replace('\n', ' '),
        "count": len(history),
    }
    try:
        print(json.dumps(state), flush=True)
    except BrokenPipeError:
        pass

def expire(notif_id):
    if notif_id in popups:
        popups.remove(notif_id)
        print_state()
    return False

def add_notification(replaces_id, app_name, summary, body, icon):
    global next_id
    old = find(replaces_id) if replaces_id else None
    if old:
        history.remove(old)
        notif_id = old["id"]
    else:
        notif_id = next_id
        next_id += 1
    history.insert(0, {"id": notif_id, "app": str(app_name), "summary": str(summary),
                       "body": str(body), "icon": str(icon), "time": time.time()})
    opts = options()
    del history[max(1, int(opts["history_limit"])):]
    popups[:] = [i for i in popups if find(i)]
    if opts["popups"]:
        if notif_id not in popups:
            popups.insert(0, notif_id)
        GLib.timeout_add_seconds(max(1, int(opts["popup_seconds"])), expire, notif_id)
    save_history()
    print_state()
    return notif_id

class NotificationServer(dbus.service.Object):
    def __init__(self):
        bus = dbus.SessionBus()
        bus_name = dbus.service.BusName(
            'org.freedesktop.Notifications',
            bus=bus,
            replace_existing=True,
            do_not_queue=True
        )
        dbus.service.Object.__init__(self, bus_name, '/org/freedesktop/Notifications')

    @dbus.service.method('org.freedesktop.Notifications', in_signature='susssasa{sv}i', out_signature='u')
    def Notify(self, app_name, replaces_id, app_icon, summary, body, actions, hints, timeout):
        if not app_icon:
            app_icon = str(hints.get('image-path') or hints.get('image_path') or "")
        return add_notification(int(replaces_id), app_name, summary, body, app_icon)

    @dbus.service.method('org.freedesktop.Notifications', in_signature='u')
    def CloseNotification(self, notif_id):
        expire(int(notif_id))

    @dbus.service.method('org.freedesktop.Notifications', out_signature='as')
    def GetCapabilities(self):
        return ["body"]

    @dbus.service.method('org.freedesktop.Notifications', out_signature='ssss')
    def GetServerInformation(self):
        return ("Zentities-Notif", "Zen", "1.0", "1.2")

    # Used by the notification center buttons
    @dbus.service.method('org.blomst.NotificationHistory', in_signature='u')
    def Dismiss(self, notif_id):
        n = find(int(notif_id))
        if n:
            history.remove(n)
            if n["id"] in popups:
                popups.remove(n["id"])
            save_history()
            print_state()

    @dbus.service.method('org.blomst.NotificationHistory')
    def Clear(self):
        history.clear()
        popups.clear()
        save_history()
        print_state()

DBusGMainLoop(set_as_default=True)

if __name__ == '__main__':
    try:
        load_history()
        server = NotificationServer()
        print_state()
        mainloop = GLib.MainLoop()
        mainloop.run()
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
