#!/bin/bash
# shellcheck disable=SC2016
set -x
NUM_CORES=$(nproc)

# Remove binary packages from the list, tail to remove human lines we don't want and grep to filter package names
test -e /tmp/pkglist || emerge --pretend --getbinpkg --update   \
                               --deep --changed-use --color=n    \
                               --usepkg world | grep -v '.binary' |
                                                tail +8           |
                                                grep -oE '[[:alnum:]_+.-]+/[[:alnum:]_+.-]+' \
                                                >/tmp/pkglist

rm /tmp/smallpkglist /tmp/mediumpkglist /tmp/largepkglist
cp /tmp/pkglist /tmp/newpkglist

qlop -a -m -M $(cat /tmp/pkglist) | sort -k 2,2 -n | while read -r pkg; do
    NAME=$(<<<"$pkg" cut -d: -f1)
    if [ "$(cut -d' ' -f2 <<<"$pkg")" -lt 20 ]; then
        echo "$NAME" >>/tmp/smallpkglist
    elif [ "$(cut -d' ' -f2 <<<"$pkg")" -lt 240 ]; then
        echo "$NAME" >>/tmp/mediumpkglist
    else
        echo "$NAME" >>/tmp/largepkglist
    fi
    LINE=$(grep -Fn "$NAME" /tmp/newpkglist | cut -d: -f1)
    sed -i "${LINE}d" /tmp/newpkglist
done

build() {
    if [ -e /var/cache/binpkgs/"$1" ]; then
        echo "Binary package already built for $1..."
        return 0
    fi
    printf "Building binary package for %s... " "$1"
    emerge --update --changed-use \
        --quiet-build --quiet=y \
        --buildpkgonly "$1" ||:
}
export -f build
echo "Building small packages..."
export MAKEOPTS="-j1"
/opt/scripts/parallelise.sh -c "$NUM_CORES" -d newline -e 'build $1' /tmp/smallpkglist

echo "Building medium packages..."
JOBS="$((NUM_CORES / 4))"
export MAKEOPTS="-j$((NUM_CORES / JOBS))"
/opt/scripts/parallelise.sh -c "$JOBS" -d newline -e 'build $1' /tmp/mediumpkglist

echo "Building large packages..."
export MAKEOPTS="-j$NUM_CORES"
cat /tmp/largepkglist | while read -r pkg; do
    build "$pkg"
done

echo "Building new packages..."
JOBS="$((NUM_CORES / 8))"
export MAKEOPTS="-j$((NUM_CORES / JOBS))"
/opt/scripts/parallelise.sh -c "$JOBS" -d newline -e 'build $1' /tmp/newpkglist
