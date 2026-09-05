#!/usr/bin/env bash
set -eo pipefail
dirty_max="$(grep -oP '^Dirty:\s+\K\d+' /proc/meminfo)"
dirty="$dirty_max"
writeback_max="$(grep -oP '^Writeback:\s+\K\d+' /proc/meminfo)"
{
echo "Waiting to be written:;$dirty_max"
echo "Writing:;$writeback_max"
until [ "$dirty" -eq 0 ]; do
    dirty="$(grep -oP '^Dirty:\s+\K\d+' /proc/meminfo)"
    writeback="$(grep -oP '^Writeback:\s+\K\d+' /proc/meminfo)"
    if [ "$dirty" -gt "$dirty_max" ]; then
        echo "Waiting to be written:;$dirty"
        dirty_max="$dirty"
        continue
    elif [ "$writeback" -gt "$writeback_max" ]; then
        echo "Writing:;$writeback"
        writeback_max="$writeback"
        continue
    fi
    echo "0:$dirty"
    echo "1:$writeback"
done
} | "$(dirname "$0")/progress.sh"
