#!/bin/bash
while true; do
	if readlink -f /dev/input/by-id/usb-Logitech_USB_Receiver-if02-event-mouse; then
		event=$(readlink -f /dev/input/by-id/usb-Logitech_USB_Receiver-if02-event-mouse)
		if test -e "$event"; then
			/home/leo/.cargo/bin/theclicker run -d"$event" -c25 -C0 -l188 -m189 -r187 -H --grab
		else
			echo "Mouse offline. Waiting..."
		fi
	fi
	sleep 5
done
