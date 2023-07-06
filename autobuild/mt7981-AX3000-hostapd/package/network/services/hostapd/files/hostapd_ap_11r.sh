#!/bin/sh
if [ $2 -eq 1 ]; then
nas_self="ap1.mtk.com"
nas_other="ap.mtk.com"
else
nas_self="ap.mtk.com"
nas_other="ap1.mtk.com"
fi

if { [ "$3" = "5g" ] || [ "$3" = "5G" ]; }; then
	iface=rai0
	holder=$(iwconfig rai0 | grep 'Access Point' | awk '{print $5}' | sed "s/://g")
elif { [ "$3" = "2g" ] || [ "$3" = "2G" ]; }; then
	iface=ra0
	holder=$(iwconfig ra0 | grep 'Access Point' | awk '{print $5}' | sed "s/://g")
fi

bridge=$(brctl show | grep -v bridge | awk '{print $1}')

#iface=$(ifconfig | grep 'Link encap' | grep -v 'eth.*\|br.*\|lo.*' | awk '{print $1}')

#holder=$(iwconfig ${iface} | grep 'Access Point' | awk '{print $5}' | sed "s/://g")

cp /etc/hostapd_rai0_AP_11r.conf /etc/hostapd_${iface}_11r.conf;

sed -i "s/nas_identifier=.*/nas_identifier=${nas_self}/g" /etc/hostapd_${iface}_11r.conf;

sed -i "s/interface=.*/interface=${iface}/g" /etc/hostapd_${iface}_11r.conf;

sed -i "s/ctrl_interface=.*/ctrl_interface=\/var\/run\/hostapd/g" /etc/hostapd_${iface}_11r.conf;

sed -i "s/bridge=.*/bridge=${bridge}/g" /etc/hostapd_${iface}_11r.conf;

sed -i "s/r1_key_holder=.*/r1_key_holder=${holder}/g" /etc/hostapd_${iface}_11r.conf;

sed -i "s/r1kh=.*/r1kh=$1 $1 000102030405060708090a0b0c0d0e0f/g" /etc/hostapd_${iface}_11r.conf;

sed -i "s/r0kh=.*/r0kh=$1 ${nas_other} 000102030405060708090a0b0c0d0e0f/g" /etc/hostapd_${iface}_11r.conf;

/usr/bin/hostapd -B /etc/hostapd_${iface}_11r.conf
