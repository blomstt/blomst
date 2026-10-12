#!/usr/bin/env python3
"""Copy the wallpaper palette into Code - OSS's settings (workbench.colorCustomizations).

Run by the wallpaper script after matugen. Leaves settings.json alone if it can't be
read as plain JSON (for example if it has comments), so nothing of yours gets lost.
"""
import json
import os
import sys

home = os.path.expanduser("~")
colors_path = os.path.join(home, ".config/blomst-settings/vscode-colors.json")
settings_path = os.path.join(home, ".config/Code - OSS/User/settings.json")

try:
    with open(colors_path, encoding="utf-8") as f:
        colors = json.load(f)
    with open(settings_path, encoding="utf-8") as f:
        settings = json.load(f)
except (OSError, ValueError) as err:
    print("vscode_colors: skipped (%s)" % err, file=sys.stderr)
    sys.exit(0)

current = settings.get("workbench.colorCustomizations")
merged = dict(current) if isinstance(current, dict) else {}
merged.update(colors)
if merged != current:
    settings["workbench.colorCustomizations"] = merged
    tmp = settings_path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(settings, f, indent=4)
        f.write("\n")
    os.replace(tmp, settings_path)
