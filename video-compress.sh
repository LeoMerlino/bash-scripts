#!/bin/bash
PID=$$
cleanup() {
    if [[ -n ${dbusRef:-} ]]; then
        qdbus6 $dbusRef close >/dev/null 2>&1 || true
    fi
    rm -f "$FIFO"
}
trap cleanup EXIT
size=$(qarma --entry --width 250 --text='Pick file size in MB' --int='10')
rate=$(qarma --entry --width 250 --text='Pick frame rate' --int='30')
codec=$(qarma --list --column='Codec' --text='Pick codec' h264 hevc av1)
dbusRef=$(kdialog --title "Video compression" --progressbar "Compressing…" 0)
FIFO="/tmp/compress-$PID.pid"
mkfifo "$FIFO"
(
    PYTHON_PID=$(cat "$FIFO")
    until ! qdbus6 $dbusRef >/dev/null 2>&1 || ! test -d /proc/"$PYTHON_PID"; do
        sleep 0.1
    done
    kill "$PYTHON_PID" 2>/dev/null
) &
(
    python /opt/scripts/constrict/constrict_cli.py -i "$1" -s "$size" -o "${1%.*}.mp4" --codec "$codec" --framerate "$rate" 2>&1 &
    echo $! > "$FIFO"
    wait $!
) | tee /tmp/compress-$PID.log
PYTHON_STATUS="${PIPESTATUS[0]}"
if [ "$PYTHON_STATUS" -eq 1 ]; then
    kdialog --textbox "/tmp/compress-$PID.log" 1024 512
elif [ "$PYTHON_STATUS" -eq 143 ]; then
    notify-send -a Success "Compression cancelled" -i emblem-error
else
    notify-send -a Success "Compression finished" -i emblem-checked
fi
