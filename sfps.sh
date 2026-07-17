#!/usr/bin/env bash

print_usage() {
    echo "Usage: $0 [-l] [-r range] [-t timeout] [-c concurrency] <port>"
    echo "Example: $0 80 -t 0.5 -l"
    echo "Example: $0 22 -t 0.2 -r '192.168.*.*'"
    echo "Port number must be the last argument"
    echo "Options:"
    echo "  -l  Local subnet scan"
    echo "  -r  Range of IP addresses to scan"
    echo "  -t  Timeout for each scan (default: 0.2)"
    echo "  -c  Concurrency level (default: 254)"
    echo "  -h  Print this help message"
}
while getopts "hlt:r:c:" opt; do
    case $opt in
        r) range="$OPTARG" ;;
        l) local_scan=1 ;;
        t) timeout="$OPTARG" ;;
        c) concurrency="$OPTARG" ;;
        h) print_usage; exit 0 ;;
    esac
done
shift $((OPTIND-1))
if  [[ "$1" =~ ^[0-9]+$ ]] && \
    [[ $local_scan -eq 1 || -n "$range" ]] && \
    [[ -z "$concurrency" || "$concurrency" =~ ^[0-9]+$ ]] && \
    [[ -z "$range" || "$range" =~ ^(\*|[0-9]+)(\.(\*|[0-9]+)){3}$ ]]; then :
else
    print_usage
    exit 1
fi

PORT=$1
TIMEOUT=${timeout:-0.2}
if [[ $local_scan -eq 1 ]]; then
    gw=$(ip -4 route show default | awk '{print $3}')
    addrs=()
    for addr in {1..254}; do
        addrs+=("${gw%.*}.$addr")
    done
else
    addrs=($(eval echo $(sed 's/\*/{1..254}/g' <<<"$range")))
fi

check() {
    if echo >/dev/tcp/"$1"/"$2"; then
        echo "open: $1:$2"
    fi
}

export -f check

printf '%s\0' "${addrs[@]}" | xargs -0 -P${concurrency:-254} -I{} timeout $TIMEOUT bash -c "check {} $PORT 2>/dev/null"
