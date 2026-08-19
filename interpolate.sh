#!/usr/bin/env bash
set -eo pipefail
prepare() {
    audio="-i /tmp/extracted-audio.aac -c:a copy"
    ffmpeg -hide_banner -loglevel error -i "$file" -q:a 0 -map a /tmp/extracted-audio.aac || unset audio
    mkdir -p /tmp/extracted-frames /tmp/output-frames
    ffmpeg -hide_banner -loglevel error -i "$file" /tmp/extracted-frames/frame_%08d.png
    num_frames=$(ls /tmp/extracted-frames -1 | wc -l)
    fps=$(ffprobe -hide_banner -loglevel error -v error -select_streams v:0 -show_entries stream=r_frame_rate -of default=noprint_wrappers=1 "$file" | grep -oE '[0-9]+/[0-9]+')
}

interpolate() {
    new_frames=$((num_frames * $1))
    t=$(($(nproc) / 3))
    "$(dirname "$0")/rife/rife-ncnn-vulkan" -i /tmp/extracted-frames -o /tmp/output-frames -m "$(dirname "$0")/rife/rife-v4.6/" -n $new_frames -j $t:$t:$t
}

encode() {
    if [ -z "$custom_fps" ]; then
        ffmpeg -hide_banner -loglevel error -y -i /tmp/output-frames/%08d.png $audio -crf 30 -c:v libsvtav1 -preset 6 -r "$fps*$mult" "${file%.*}"-int.mp4
    else
        ffmpeg -hide_banner -loglevel error -y -framerate "$custom_fps" -i /tmp/output-frames/%08d.png $audio -crf 30 -c:v libsvtav1 -preset 6 "${file%.*}"-int.mp4
    fi
}

clean() {
    rm -rf /tmp/extracted-audio.aac /tmp/extracted-frames /tmp/output-frames
}
trap 'clean' EXIT SIGINT
mult=$1
if [ "$mult" = "custom" ]; then
    custom_fps=$(qarma --entry --width 25 --text='New frame rate' --int='60')
    custom=1
fi
set -x
shift
for file in "$@"; do
    prepare
    if [ -z "$custom" ]; then
        interpolate "$mult"
    else
        mult=$(awk "BEGIN { print int($custom_fps/($fps))+1 }")
        interpolate "$mult"
    fi
    encode
    clean
done
