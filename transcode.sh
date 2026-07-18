#!/bin/bash

transcode() {
    new_file="${2%.*}"."$1"
    ffmpeg -i "$2" "$new_file" || notify-send -u low -t 10000 -a 'Transcoding failed' 'Failed to transcode'
}

case "$1" in
    opus)
        new_file="${2%.*}".opus
        [ "$new_file" != "$2" ] || { echo 'Already transcoded'; exit 1; }
        opusenc --bitrate 128 "$2" "$new_file" || ffmpeg -i "$2" -c:a libopus -b:a 128K "$new_file" || notify-send -u low -t 10000 -a 'Transcoding failed' 'Failed to transcode'
        ;;
    prompt)
        format=$(qarma --entry --text='Input extension (e.g., aiff, opus)')
        printf '%s\0' "${@:2}" | xargs -0 -P"$(nproc)" -I{} "$0" "$format" "{}"
        ;;
    *)
        new_file="${2%.*}"."$1"
        ffmpeg -i "$2" "$new_file" || notify-send -u low -t 10000 -a 'Transcoding failed' 'Failed to transcode'
        ;;
esac
