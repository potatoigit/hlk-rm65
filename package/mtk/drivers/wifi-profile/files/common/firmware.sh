#!/bin/sh /etc/rc.common

START=15
STOP=15

USE_PROCD=1

start_service() {
	[ -f /etc/hotplug.d/firmware/11-mtk-wifi-e2p ] && sh /etc/hotplug.d/firmware/11-mtk-wifi-e2p
	[ -f /etc/hotplug.d/firmware/12-mtk-wifi-testmode ] && sh /etc/hotplug.d/firmware/12-mtk-wifi-testmode
}

stop_service() {
    echo 'do nothing' > /dev/null
}


