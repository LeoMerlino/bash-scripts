#!/usr/bin/env bash
set -eo pipefail

TMP_DIR=$(mktemp -d /tmp/rife-interp.XXXXXX)
clean() {
    rm -rf "$TMP_DIR"
}
trap 'clean' EXIT SIGINT

mult_arg="$1"
custom_fps=""

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

for file in "$@"; do
    [ ! -f "$file" ] && continue
    echo "==> Processing: $file"

    in_frames="$TMP_DIR/input_frames"
    out_frames="$TMP_DIR/output_frames"
    mkdir -p "$in_frames" "$out_frames"

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

    "$(dirname "$0")/rife/rife-ncnn-vulkan" \
        -i "$in_frames"                      \
        -o "$out_frames"                      \
        -m "$(dirname "$0")/rife/rife-v4.6/"   \
        -n "$target_frames"                     \
        -j "$threads:$threads:$threads"

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

    rm -rf "$in_frames" "$out_frames"
done
