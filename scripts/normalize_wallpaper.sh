#!/bin/bash

DIRECTORY="$HOME/wallpapers"

if [ ! -d "$DIRECTORY" ]; then
  echo "Directory does not exist: $DIRECTORY"
  exit 1
fi

shopt -s nullglob

# Videos: a still picture of the same name (for the colours, lock screen and login screen) and a
# preview with a play badge, so they show up in the wallpaper list. video_wallpaper.sh plays them.
for file in "$DIRECTORY"/*.{mp4,webm,mkv,mov,MP4,WEBM,MKV,MOV}; do
    filename=$(basename "$file")
    base_name="${filename%.*}"
    target_jpg="${DIRECTORY}/${base_name}.jpg"
    preview_file="${DIRECTORY}/preview-${base_name}.jpg"

    if [ ! -f "$target_jpg" ]; then
        # A frame one second in (the very first one is often black), or the first if it is shorter
        ffmpeg -loglevel error -y -ss 1 -i "$file" -frames:v 1 -q:v 2 "$target_jpg" 2>/dev/null
        [ -s "$target_jpg" ] || ffmpeg -loglevel error -y -i "$file" -frames:v 1 -q:v 2 "$target_jpg"
        [ -s "$target_jpg" ] && echo "Still picture: $filename -> ${base_name}.jpg"
    fi

    if [ -s "$target_jpg" ] && [ ! -f "$preview_file" ]; then
        magick "$target_jpg" -resize 800x600 \
            -fill 'rgba(0,0,0,0.55)' -draw 'circle 60,60 60,24' \
            -fill white -draw 'polygon 48,42 48,78 82,60' \
            -quality 50 "$preview_file" \
        && echo "Created video preview: $preview_file"
    fi
done

for file in "$DIRECTORY"/*.{png,jpeg,jpg,webp,PNG,JPG,JPEG,WEBP}; do
  if [ -f "$file" ]; then
    
    filename=$(basename "$file")
    base_name="${filename%.*}"

    if [[ "$base_name" == preview-* ]]; then
      continue
    fi

    target_jpg="${DIRECTORY}/${base_name}.jpg"
    preview_file="${DIRECTORY}/preview-${base_name}.jpg"

    if [[ "$file" != *.jpg && "$file" != *.JPG ]]; then
       if [ ! -f "$target_jpg" ]; then
          magick "$file" "$target_jpg" && echo "Converted: $filename -> ${base_name}.jpg"
       fi
       source_for_preview="$target_jpg"
    else
       source_for_preview="$file"
    fi

    if [ ! -f "$preview_file" ]; then
      magick "$source_for_preview" -resize 800x600 -quality 50 "$preview_file" \
      && echo "Created preview: $preview_file"
    fi

  fi
done

echo "Processing completed."
