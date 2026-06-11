#!/bin/bash
if [ "$EUID" -ne 0 ]; then
    echo "Script must be run as root"
    exit 1
fi

usage() {
    echo "usage: $0 command [program]"
    echo "create and control an isolated network"
    echo "toggle network access for programs running in the network"
    echo
    echo "commands:"
    echo "  enable   enable internet access for isolated apps"
    echo "  disable  disable internet access for isolated apps"
    echo "  run      run the specfied command in the isolated network"
    echo
    echo "examples:"
    echo "  $0 run steam    run steam in the isolated network"
    echo "  $0 enable       enable internet access for processes running in the isolated network"
    exit 0
}

ID="isolated"
NS="ns_${ID}"
VETH_HOST="vh_${ID}"
VETH_NS="vn_${ID}"
SUBNET="169.254.123.0/30"
GW_IP="${SUBNET%.*}.1"
NS_IP="${SUBNET%.*}.2"

# Create a network namespace, ignore if already exists
if ip netns add "$NS" 2>/dev/null; then
    ip link add "$VETH_HOST" type veth peer name "$VETH_NS"
    ip link set "$VETH_NS" netns "$NS"
    ip addr add "${GW_IP}/30" dev "$VETH_HOST"
    ip link set "$VETH_HOST" up
    ip netns exec "$NS" ip addr add "${NS_IP}/30" dev "$VETH_NS"
    ip netns exec "$NS" ip link set "$VETH_NS" up
    ip netns exec "$NS" ip link set lo up
    ip netns exec "$NS" ip route add default via "$GW_IP"
    echo 1 >/proc/sys/net/ipv4/ip_forward
    iptables -t nat -A POSTROUTING -s "${SUBNET}" -j MASQUERADE
fi

case "$1" in
enable)
    ip netns exec "$NS" ip link set veth1 up
    ;;
disable)
    ip netns exec "$NS" ip link set veth1 down
    ;;
run)
    ip netns exec isolated "${@:2}"
    ;;
*) usage ;;
esac
