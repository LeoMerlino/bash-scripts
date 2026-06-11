#!/bin/bash
# shellcheck disable=SC2016

LIST=/tmp/buildpkglist
# awk command: don't print lines where "g" (binary package) is present in $1, 
# and only print $2 if "/" is present (check if its a package name)
test -e $LIST || emerge --pretend --getbinpkg --update \
						--deep --changed-use --color=n  \
						--columns --quiet=y world        \
						| awk '$1 !~ /g/ && $2 ~ /\// {print $2}' > $LIST;

build () {
	if [ -e /var/cache/binpkgs/"$0" ]; then
		echo "Binary package already built for $0..."
		return 0
	fi
	printf "Building binary package for %s... " "$0"
	MAKEOPTS="-j4"               \
	emerge --update --changed-use \
		   --quiet-build --quiet=y \
		   --buildpkgonly "$0"
}
export -f build
cat $LIST - <<<"$@" | xargs -r -P8 -l bash -c 'build $0'
