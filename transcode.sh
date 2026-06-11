#!/bin/bash
new_file="${1%.*}".opus
[ "$new_file" != "$1" ] || { echo 'Already transcoded'; exit 1; }
opusenc --bitrate 128 "$1" "$new_file" || ffmpeg -i "$1" -c:a libopus -b:a 128K "$new_file" || notify-send -u low -t 10000 -a 'Transcoding failed' 'Failed to transcode'


