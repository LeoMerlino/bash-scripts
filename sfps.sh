#!/usr/bin/env bash

print_usage() {
    echo "Usage: $0 [-l] [-r range] [-t timeout] [-c concurrency] [-p <ports>]"
    echo "Example: $0 -t 0.5 -l -p 21,22,80,100-150"
    echo "Example: $0 -t 0.2 -r '192.168.*.*' -p 22-200"
    echo "Port range must be specified as <port>-<port> (inclusive)"
    echo "Or individually <port>,<port>..."
    echo "Options:"
    echo "  -l  Local subnet scan"
    echo "  -r  Range of IP addresses to scan (or single address)"
    echo "  -p  Port number or range to scan (default: 80)"
    echo "  -t  Timeout for each scan (default: 0.2)"
    echo "  -c  Concurrency level (default: 254)"
    echo "  -h  Print this help message"
}
while getopts "hlt:r:c:p:" opt; do
    case $opt in
        r) range="$OPTARG" ;;
        l) local_scan=1 ;;
        t) timeout="$OPTARG" ;;
        c) concurrency="$OPTARG" ;;
        p) port="$OPTARG" ;;
        h) print_usage; exit 0 ;;
        *) print_usage; exit 1 ;;
    esac
done
concurrency="${concurrency:-254}"
timeout="${timeout:-0.2}"
port="${port:-80}"
if  [[ $local_scan -eq 1 || -n "$range" ]] && \
    [[ "$concurrency" =~ ^[0-9]+$ ]] &&        \
    [[ -z "$range" || "$range" =~ ^(\*|[0-9]+)(\.(\*|[0-9]+)){3}$ ]]; then :
else
    print_usage
    exit 1
fi

process_ports() {
    IFS=',' read -ra segments <<< "$1"
    for seg in "${segments[@]}"; do
        if [[ $seg == *-* ]]; then
            # Extract start and end values and generate sequence
            seq "${seg%-*}" "${seg#*-}"
        else
            echo "$seg"
        fi
    done
}

ports=$(process_ports "$port" || { echo "Invalid port/range: $port"; print_usage; exit 1; })

if [[ $local_scan -eq 1 ]]; then
    gw=$(ip -4 route show default | awk '{print $3}')
    addrs=()
    for addr in {1..254}; do
        addrs+=("${gw%.*}.$addr")
    done
else
    addrs=($(eval echo $(sed 's/\*/{1..254}/g' <<<"$range")))
fi

new_addrs=()
for addr in "${addrs[@]}"; do
    for port in $ports; do
        new_addrs+=("$addr:$port")
    done
done

check() {
    IFS=':' read -r host port <<< "$1"
    [ -n "$DRY" ] && {
        echo "dry: $host:$port"
        return
    }
    if echo >/dev/tcp/"$host"/"$port"; then
        echo "open: $host:$port"
    fi
}

export -f check
printf '%s\0' "${new_addrs[@]}" | xargs -0 -P"$concurrency" -I{} timeout "$timeout" bash -c "check {} $port 2>/dev/null"
