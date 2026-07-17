#!/usr/bin/env bash
gw=$(ip -4 route | awk '{print $3; exit}')
addrs=()
for addr in $(seq 1 254); do
    addrs+=("${gw%.*}.$addr")
done

check() {
    if echo >/dev/tcp/"$1"/"$2"; then
        echo "open: $1:$2"
    fi
}

export -f check

xargs -P0 -d' ' -I{} timeout 0.01 sh -c "check {} $1 2>/dev/null" <<<"${addrs[@]}"
