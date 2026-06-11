#!/usr/bin/env bash
# shellcheck disable=SC2016

print_usage() {
    echo "Usage: $0 [command] [-d <delimiter>] [-c <concurrency>] [-p]"
    echo "Tile processeses parallelised by xargs in a tmux session"
    echo "Commands to provide input items and process them will"
    echo "be read from the user during script execution"
    echo
    echo "Args:"
    echo "  -d  select the delimiter that seperates the items provided by the input command"
    echo "      newline    use a newline as the delimiter"
    # shellcheck disable=SC2028
    echo "      null       use a null character (\0) as the delimiter"
    echo "      custom     use whatever is supplied in place of custom as the delimiter"
    echo "  -t  max processes to run in parallel"
    echo "  -p  prompt before running each command"
    echo
    echo "Examples:"
    echo "  $0 -d % -c 16         use '%' as the delimiter and run 16 processes in parallel"
    echo "  $0 -d null -c 3 -p    use a null character as the delimiter,"
    echo "                        run 3 processes in parallel and prompt before each command"
    exit 0
}

while getopts 'd:c:ph' opt; do
    case "$opt" in
    d)
        case "$OPTARG" in
        newline)
            delim=''                                  # Needs to be something to detect if the user supplied the arg
            echo "Picking a newline as the delimiter" # Default so we don't have to assign anything
            ;;
        null)
            delim="-0"
            echo "Picking a null character as the delimiter"
            ;;
        *)
            delim="-d'$OPTARG'"
            echo "Picking '$OPTARG' as the delimiter"
            ;;
        esac
        ;;
    c)
        case "$OPTARG" in
        '' | *[!0-9]*)
            echo "The '-c' flag must be a number"
            print_usage
            ;;
        *)
            echo "Running $OPTARG processes in parallel"
            threads="$OPTARG"
            ;;
        esac
        ;;
    p)
        echo "Will prompt before each command"
        prompt='-p'
        ;;
    h)
        print_usage
        ;;
    *)
        echo "Invalid usage"
        print_usage
        ;;
    esac
done
if [ -z "${delim+x}" ] || [ -z "${threads+x}" ]; then # Are they both set?
    echo "Error: missing arguments"
    print_usage
fi

echo 'Command providing items to work on. E.g., `ls *.mp3` (use Ctrl + D to end input)'
items="$(mktemp)"
eval "$(</dev/stdin)" >"$items"

echo 'Enter the command to process the items. Use `$0` as the input for each item.'
echo 'For example: `chmod +x $0` (use Ctrl + D to end input)'
processor_file="$(mktemp)"
<<<"$(</dev/stdin)" cat >"$processor_file"

tmux_session="parallelise-$$"
export tmux_session
tmux new-session -d -s "$tmux_session"
progress_file="$(mktemp)"

cleanup() {
    rm -f "$watch_progress" "$progress_file" "$items" "$processor_file"
    if tmux list-sessions -f "$tmux_session" >/dev/null 2>&1; then
        tmux kill-session -t "$tmux_session"
    fi
}

trap 'cleanup' EXIT SIGINT

case "$delim" in
'')
    <"$items" wc -l >"$progress_file"
    ;;
'-0')
    <"$items" tr -cd '\0' | wc -c >"$progress_file"
    ;;
*)
    <"$items" tr -cd "$delim" | wc -c >"$progress_file"
    ;;
esac
watch_progress="$(mktemp)"
# TODO: Work out how to only send one variable
printf '
clear
set -eo pipefail
while :; do
    inotifywait -qe modify %s | while read; do
        clear
        printf "\rProcesses left: $(cat %s)"
    done
done' "$progress_file" "$progress_file" >"$watch_progress"

tmux send-keys -t "$tmux_session" "bash $watch_progress" Enter

echo "New session created: $tmux_session"
echo "Attach with: tmux a $tmux_session"
read -rp 'Attach in new kitty window? [y/N] ' choice
if [ "$choice" = 'y' ]; then
    kitty --detach=y -- tmux a -t "$tmux_session"
fi
export progress_file items processor_file tmux_session
read -rp 'Press enter to run... '
# The first two variables must be unquoted otherwise if they are empty, xargs will interpret it as an argument
cat <<'EOF' | xargs $prompt $delim -l -r -P"$threads" bash -c "$(cat)" <"$items"
id=$$
sleep "$(awk -v r=$RANDOM 'BEGIN { printf "%.3f", r/32767 }')"

# Safely escape the item name ($0) so spaces/special chars don't break the tmux command
escaped_item=$(printf '%q' "$0")

tmux split-window -t "$tmux_session" -h "
    bash -c \"\$(cat '$processor_file')\" $escaped_item || { read -rp '[ERROR] PROCESS FAILED '; tmux wait-for -S $id; exit 1; }
    echo 'Process finished successfully!'
    sleep 1
    tmux wait-for -S $id" &&
tmux select-layout -t "$tmux_session" tiled
tmux wait-for "$id"
echo $(($(cat "$progress_file")-1)) > "$progress_file"
EOF
cleanup
