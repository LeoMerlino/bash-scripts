#!/bin/bash
set -e
size=$(qarma --entry --width 250 --text='Pick file size in MB' --int='10')
rate=$(qarma --entry --width 250 --text='Pick frame rate' --int='30')
codec=$(qarma --list --column='Codec' --text='Pick codec' h264 hevc av1)
python /opt/scripts/constrict/constrict_cli.py -i "$1" -s "$size" -o "${1%.*}.mp4" --codec "$codec" --framerate "$rate" || notify-send -a Failed "Compression failed" -u critical
