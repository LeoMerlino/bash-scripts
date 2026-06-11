#!/bin/bash
set -e
THRESHOLD_KB=1048576  # 1GB in KB
EXCLUDE_FILE="/tmp/restic-large-dirs.txt"
if test -e $EXCLUDE_FILE; then
	rm $EXCLUDE_FILE
fi
mount -r UUID=D42E8CE92E8CC648 /windows || echo "Windows is already mounted"

for folder in $@; do
	SOURCE="$folder"
	# Find immediate subdirectories over the threshold
	du -a --max-depth=1 "$SOURCE" | \
	  awk -v threshold="$THRESHOLD_KB" '$1 > threshold {$1=""; print $0}' | \
	  grep -v "^$SOURCE$" | awk '{$1=$1};1' >> "$EXCLUDE_FILE"
done
