#!/bin/bash
sleep 0.5
case $1 in
    e)
        ydotool key -d 20 42:1 68:1 68:0 42:0 56:1 45:1 45:0 18:1 18:0 56:0
        ;;
    d)
        ydotool key -d 20 42:1 68:1 68:0 42:0 56:1 45:1 45:0 30:1 30:0 56:0
        ;;
esac
