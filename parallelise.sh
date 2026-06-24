#!/usr/bin/env bash

print_usage() {
    echo "Usage: $0 [OPTIONS] -e <processor_command> [FILE...]"
    echo "Tile processes parallelised by xargs in a tmux session."
    echo "Cannot attach automatically if input is piped via stdin."
    echo "Press Ctrl + C on the progress indicator tile to stop all operations"
    echo
    echo "You can pass items as arguments or pipe them via stdin:"
    echo "Example: ls *.mp3 | $0 -c 4 -e 'chmod +x \"\$1\"'"
    echo "Or via file:"
    echo "Example: $0 -c 4 -e 'chmod +x \"\$1\"' files.txt"
    echo
    echo "Options:"
    echo "  -e  (REQUIRED) Command to execute per item. Use '\$1' as the item variable"
    echo "  -d  Delimiter: 'newline', 'null', or a custom character"
    echo "  -c  Max processes to run in parallel (concurrency)"
    echo "  -h  Show this help text"
    exit 0
}

# Default vars
threads=1
xargs_args=()
processor_cmd=""
count_delim=$'\n'

while getopts 'e:d:c:nh' opt; do
    case "$opt" in
    e) processor_cmd="$OPTARG" ;;
    d)
        if [[ "$OPTARG" == "newline" ]]; then
            xargs_args+=("-d" $'\n')
            count_delim=$'\n'
        elif [[ "$OPTARG" == "null" ]]; then
            xargs_args+=("-0")
            count_delim='\0'
        else
            xargs_args+=("-d" "$OPTARG")
            count_delim="$OPTARG"
        fi
        ;;
    c)
        if [[ "$OPTARG" =~ ^[0-9]+$ ]]; then
            threads="$OPTARG"
        else
            echo "Error: '-c' flag must be a number" >&2
            exit 1
        fi
        ;;
    h) print_usage ;;
    *) print_usage ;;
    esac
done
shift $((OPTIND - 1))

if [[ -z "$processor_cmd" ]]; then
    echo "Error: Missing required processor command (-e)" >&2
    print_usage
fi
items="$(mktemp)"
processor_file="$(mktemp)"
progress_file="$(mktemp)"
progress_lock="$(mktemp)"
watch_progress_script="$(mktemp)"
# Write processor command to file
echo "$processor_cmd" >"$processor_file"
# If more than 0 extra args are given (input files)
if [[ $# -gt 0 ]]; then
    # Copy contents of input file(s) to temp file
    cat "$@" >"$items"
# Check if stdin is not a terminal
elif [[ ! -t 0 ]]; then
    # Read from stdin
    cat >"$items"
else
    echo "Error: No items provided via stdin or arguments" >&2
    print_usage
fi

tmux_session="parallelise-$$"

cleanup() {
    rm -f "$watch_progress_script" "$progress_file" "$items" "$processor_file" "$progress_lock"
    kill "$xargs_pid" 2>/dev/null
    # Check if the tmux session actually exists
    if tmux has-session -t "$tmux_session" 2>/dev/null; then
        tmux kill-session -t "$tmux_session"
    fi
}
# Run cleanup on exit via ctrl+c, etc.
trap 'cleanup' EXIT SIGINT

# Count initial processes and write to progress file
# Progress file will just contain the amount of processes left to finish
<"$items" tr -cd "$count_delim" | wc -c >"$progress_file"

cat <<EOF >"$watch_progress_script"
clear
set -eo pipefail
trap 'cat /tmp/xargs_pid_$$ | xargs kill 2>/dev/null' EXIT SIGINT
printf "\e[H\e[2JProcesses left:\n"
figlet "\$(cat "$progress_file")"
inotifywait -m -q -e modify "$progress_file" | while read -r _ _ _; do
    printf "\e[H\e[2JProcesses left:\n"
    figlet "\$(cat "$progress_file")"
done
EOF

tmux new-session -d -s "$tmux_session"
tmux send-keys -t "$tmux_session" "bash $watch_progress_script" Enter

# Export variables needed by xargs subshells
export progress_file items processor_file tmux_session progress_lock
cat <<'EOF' | xargs "${xargs_args[@]}" -l -r -P"$threads" bash -c "$(cat)" <"$items" &
id=$$
# Gotta sleep otherwise tmux doesn't tile quickly enough
sleep "$(awk -v r=$RANDOM 'BEGIN { printf "%.3f", r/32767 }')"
tmux has-session -t "$tmux_session" 2>/dev/null || exit 1
tmux split-window -t "$tmux_session" -h "
    bash '$processor_file' '$0' || { read -rp '[ERROR] PROCESS FAILED '; tmux wait-for -S $id; exit 1; }
    echo 'Process finished successfully!'
    sleep 1
    tmux wait-for -S $id" &&
tmux select-layout -t "$tmux_session" tiled
tmux wait-for "$id"

# Set progress_lock to fd 200 then lock the file with flock
# Makes sure that files aren't accessed at the same time
(
    flock 200
    current_count=$(cat "$progress_file" 2>/dev/null)
    echo $((current_count - 1)) > "$progress_file"
) 200> "$progress_lock"
EOF
xargs_pid=$!
echo $xargs_pid >/tmp/xargs_pid_$$
# Cor the cleanup function
export xargs_pid
if [ -t 0 ]; then
    tmux a -t "$tmux_session"
else
    echo "Can't attatch automatically, run \`tmux a -t $tmux_session\` in another window or just \`tmux a\` if you don't have any sessions running."
fi
wait
