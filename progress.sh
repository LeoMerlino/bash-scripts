#!/bin/env bash
trap 'tput cnorm' EXIT INT TERM
tput sc
tput civis
titles=()
totals=()
while read -r line; do
    if [[ "$line" =~ ^(.+)\;([0-9]+)$ ]]; then
        for i in "${!titles[@]}"; do
            if [[ "${titles[i]}" == "${BASH_REMATCH[1]}" ]]; then
                titles[i]="${BASH_REMATCH[1]}"
                totals[i]="${BASH_REMATCH[2]}"
                continue 2
            fi
        done
        titles+=("${BASH_REMATCH[1]}")
        totals+=("${BASH_REMATCH[2]}")
    elif [[ "$line" =~ ^([0-9]+):([0-9]+)$ ]]; then
        i=${BASH_REMATCH[1]}
        prog=${BASH_REMATCH[2]}
        cols=$(($(tput cols) - (4 + ${#prog} + ${#totals[i]})))
        perc=0
        (( totals[i] > 0 )) && perc=$((prog * 100 / totals[i]))
        progcols=$((cols * perc / 100))
        ((i > 0)) && printf '\033[%dB' $((i * 2))
        echo "${titles[i]}"
        printf '\r'
        printf '█%.0s' $(seq 1 $progcols)
        printf ' [%s/%s]' "$prog" "${totals[i]}"
        tput el
        tput rc
    fi
done
tput cnorm
