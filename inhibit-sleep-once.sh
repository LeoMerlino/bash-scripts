#!/usr/bin/env bash
notify-send -a "Sleep status" "Sleep temporarily disabled"

# wait until the lid is closed, then wait until it is opened again
while ! grep -q closed /proc/acpi/button/lid/LID/state; do
	sleep 1
done
while ! grep -q open   /proc/acpi/button/lid/LID/state; do
	sleep 1
done
