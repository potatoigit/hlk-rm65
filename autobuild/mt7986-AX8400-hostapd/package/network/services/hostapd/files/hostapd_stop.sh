#!/bin/sh
echo "Kill Hostapd..."
killall hostapd
sleep 3
ifconfig ra0 down
sleep 3
ifconfig rai0 down
sleep 3
echo "interface up start..."
ifconfig ra0 up
sleep 3
ifconfig rai0 up
sleep 3
echo "interface up complete..."