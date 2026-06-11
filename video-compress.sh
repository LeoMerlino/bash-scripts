#!/bin/bash
set -e
size=$(qarma --entry --width 250 --title='Pick file size in MB' --entry-text='10')
rate=$(qarma --entry --width 250 --title='Pick frame rate' --entry-text='30')
codec=$(qarma --entry --width 250 --title='Pick codec' --entry-text='h264,hevc,av1')
python /opt/scripts/constrict/constrict_cli.py -i "$1" -s "$size" -o "$(sed 's/\.[^.]*$//' <<<"$1").mp4" --codec "$codec" --framerate "$rate" || notify-send -a Failed "Compression failed" -u critical
