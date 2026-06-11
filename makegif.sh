#!/bin/bash

maxw=0; maxh=0
for f in "$@"; do
  read w h < <(identify -format "%w %h\n" "$f")
  (( w > maxw )) && maxw=$w
  (( h > maxh )) && maxh=$h
done

magick -size ${maxw}x${maxh} -background black -dispose Background -delay 100 -loop 0 "$@" -gravity center -extent ${maxw}x${maxh} -coalesce -layers optimize /tmp/output.gif
gifsicle -i /tmp/output.gif -O3 --lossy=100 --colors 128 -o /home/leo/Downloads/output.gif --resize=640x_
