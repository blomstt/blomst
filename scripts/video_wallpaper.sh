#!/bin/sh
# Video wallpapers. A video in ~/wallpapers (mp4, webm, mkv, mov) gets a still picture of the same
# name from normalize_wallpaper.sh; that picture sets the colours, the lock screen and the login
# screen, and this script plays the video on top of it with mpvpaper, on every screen.
#
#   video_wallpaper.sh <picture>      play the video that belongs to the picture, if there is one
#   video_wallpaper.sh --stop         stop any playing video
#
# The video pauses while windows cover it completely, so it costs nothing while you work or play.
pkill -x mpvpaper 2>/dev/null
[ "$1" = "--stop" ] || [ -z "$1" ] && exit 0
command -v mpvpaper >/dev/null 2>&1 || exit 0

base="${1%.*}"
for ext in mp4 webm mkv mov MP4 WEBM MKV MOV; do
    if [ -f "$base.$ext" ]; then
        setsid -f mpvpaper -p -o "no-audio loop hwdec=auto panscan=1.0" ALL "$base.$ext" >/dev/null 2>&1
        exit 0
    fi
done
