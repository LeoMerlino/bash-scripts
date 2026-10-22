#!/usr/bin/env bash
set -eo pipefail

TMP_DIR=$(mktemp -d /tmp/rife-interp.XXXXXX)

log () {
    echo "$@"
    qdbus6 $dbusRef setLabelText "$@"
    curr_step=$((curr_step + 1))
    qdbus6 $dbusRef Set "" value "$curr_step"
}
clean() {
    log "Cleaning up"
    rm -rf "$TMP_DIR"
    qdbus6 $dbusRef close
    notify-send -a Success "Compression finished" -i emblem-checked
}
cancelled () {
    trap - EXIT
    kill $job 2>/dev/null || kill $$
    rm -rf "$TMP_DIR"
}
show_error () {

    kdialog --textbox "$TMP_DIR/log.txt" 1024 512
    cancelled
}

trap 'clean' EXIT


mult_arg="$1"
custom_fps=""
curr_step=0

if [ "$mult_arg" = "custom" ]; then
    custom_fps=$(qarma --entry --width 25 --text='New frame rate' --int='60')
    if [ -z "$custom_fps" ]; then
        echo "No target framerate specified. Exiting."
        exit 1
    fi
elif [ -z "$mult_arg" ]; then
    echo "Usage: $0 [multiplier | custom] <video_files...>"
    exit 1
fi

shift
steps=$(($# * 3))
dbusRef=$(kdialog --progressbar "Initializing" $steps)
(
    trap 'show_error' ERR
    for file in "$@"; do
    [ ! -f "$file" ] && continue

    in_frames="$TMP_DIR/input_frames"
    out_frames="$TMP_DIR/output_frames"
    mkdir -p "$in_frames" "$out_frames"

    log "Extracting frames from $file"
    ffmpeg -hide_banner -loglevel error -y -i "$file" "$in_frames/%08d.png"
    num_frames=$(find "$in_frames" -name "*.png" | wc -l)

    fps_frac=$(ffprobe -hide_banner -loglevel error -select_streams v:0 \
        -show_entries stream=r_frame_rate -of default=noprint_wrappers=1:nokey=1 "$file")

    fps_val=$(awk -v f="$fps_frac" 'BEGIN { split(f, a, "/"); if (a[2] > 0) print a[1]/a[2]; else print a[1] }')

    if [ -n "$custom_fps" ]; then
        target_fps="$custom_fps"
        target_frames=$(awk -v n="$num_frames" -v c="$custom_fps" -v f="$fps_val" 'BEGIN { printf "%d", (n * c / f) + 0.5 }')
    else
        target_fps=$(awk -v f="$fps_val" -v m="$mult_arg" 'BEGIN { printf "%.4f", f * m }')
        target_frames=$((num_frames * mult_arg))
    fi

    echo "Source: ${num_frames} frames @ ${fps_val} fps"
    echo "Target: ${target_frames} frames @ ${target_fps} fps"

    threads=$(($(nproc) / 3))
    threads=$((threads < 1 ? 1 : threads))
    log "Running RIFE interpolator"
    "$(dirname "$0")/rife/rife-ncnn-vulkan" \
        -i "$in_frames"                      \
        -o "$out_frames"                      \
        -m "$(dirname "$0")/rife/rife-v4.6/"   \
        -n "$target_frames"                     \
        -j "$threads:$threads:$threads"
    log "Encoding output video"
    output_video="${file%.*}_interpolated.mp4"
    ffmpeg -hide_banner -loglevel error -y \
        -framerate "$target_fps"            \
        -i "$out_frames/%08d.png"            \
        -i "$file"                            \
        -map 0:v:0                             \
        -map 1:a?                               \
        -c:a copy                                \
        -c:v libsvtav1                            \
        -preset 6                                  \
        -crf 30                                     \
        -pix_fmt yuv420p                             \
        "$output_video"
done
) 2>&1 | tee "$TMP_DIR/log.txt" &

job=$!

until ! qdbus6 $dbusRef >/dev/null 2>&1; do
    sleep 0.5
done
if test -d /proc/$job; then
    cancelled
fi
