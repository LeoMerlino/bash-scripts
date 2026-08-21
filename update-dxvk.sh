#!/usr/bin/env bash
set -eo pipefail
test "$(id -u)" -eq 0 && {
    echo "Run as a normal user, not root"
    exit 1
}
sudo -v
TMP=$(mktemp -d)
cd "$TMP"
wget https://github.com/netborg-afps/dxvk-low-latency/releases/latest/download/dxvk-3.0.2-low-latency.tar.gz
tar xf dxvk-3.0.2-low-latency.tar.gz

for tool in ~/.local/share/Steam/compatibilitytools.d/*; do
    sudo cp -vt "$tool/files/lib64/wine/dxvk/" x64/*
    sudo chown "$USER:" -R "$tool/files/lib64/wine/dxvk/"
    sudo cp -vt "$tool/files/lib/wine/dxvk/"   x32/*
    sudo chown "$USER:" -R "$tool/files/lib/wine/dxvk/"
done

trap "rm -r $TMP" EXIT
