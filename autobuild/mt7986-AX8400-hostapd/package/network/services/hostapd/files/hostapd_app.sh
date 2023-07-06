#!/bin/sh

usage()
{
	echo " "
	echo "USAGE: hostapd_app.sh [option] [5g|2g|both(only for option 1)] [security option: open|wpapsk|wpa2psk|wpawpa2mixedpsk|wepopen|wepshare|EnterpriseAP|wpsopen|wpswpa2psk|owe|sae|suiteB] [optional: conf=<conf_file_path>]"
	echo "option 1: Hostapd AP BringUp."
	echo "option 2: Hostapd STA Connects to AP."
	echo "option 3: WDS Hostapd STA BringUp."
	echo "option 4: WDS Hostapd STA Connects to AP."
	echo "option 5: Hostapd 11r BringUp."
	echo "example: hostapd_app.sh 1 5g open => normal AP(5G) up with rai0 and security open mode."
	echo "example: hostapd_app.sh 1 both open => two bandand normal APs(2G and 5G) up with rai0/rai0 and security open mode."
	echo "example: hostapd_app.sh 2 2g wpapsk => normal STA with apcli0 and security wpapsk mode connects to AP."
	echo "example: hostapd_app.sh 5 5g 00:0C:43:26:46:80 0 => AP0 bring hostapd with 11r for 5G, and another AP's rai0 is 00:0C:43:26:46:80."
	echo "example: hostapd_app.sh 1 2g open conf=/etc/hostapd_ra0_open.conf=> normal AP(2G) up with ra0 with given conf file."
}


echo "HOSTAPD APPLICATION..."

option=$1;
wifi_if=$2;
sec_type=$3;

# Check for conf file
for last in $@; do :; done
if [ $(echo "$last" | grep "conf") ]; then
	eval $last
	conf_file=$conf
fi

# Option 5: 11r
if [ "$1" = "5" ]; then
	other_ap_mac_addr=$3;
	ap_index=$4;
fi

if { [ "$1" = "1" ] || [ "$1" = "3" ]; } && { [ "$2" = "5g" ] || [ "$2" = "5G" ]; }; then
	wifi_if=rai0
	echo $wifi_if "!!!!!!!!"
elif { [ "$1" = "1" ] || [ "$1" = "3" ]; } && { [ "$2" = "2g" ] || [ "$2" = "2G" ]; }; then
	wifi_if=ra0
	echo $wifi_if "!!!!!!!!"
elif { [ "$1" = "2" ] || [ "$1" = "4" ]; } && { [ "$2" = "5g" ] || [ "$2" = "5G" ]; }; then
	wifi_if=apclii0
	echo $wifi_if "!!!!!!!!"
elif { [ "$1" = "2" ] || [ "$1" = "4" ]; } && { [ "$2" = "2g" ] || [ "$2" = "2G" ]; }; then
	wifi_if=apcli0
	echo $wifi_if "!!!!!!!!"
elif { [ "$1" = "5" ]; } && { [ "$2" = "5g" ] || [ "$2" = "5G" ]; }; then
	wifi_if=rai0
	echo $wifi_if "!!!!!!!!"
elif { [ "$1" = "5" ]; } && { [ "$2" = "2g" ] || [ "$2" = "2G" ]; }; then
	wifi_if=ra0
	echo $wifi_if "!!!!!!!!"
fi

if [ "$1" = "1" ]; then
	killall hostapd
	echo "killall hostapd"
	sleep 1
	hostapd_ap.sh $wifi_if $sec_type $conf_file
elif [ "$1" = "2" ]; then
	killall wpa_supplicant
	echo "killall wpa_supplicant"
	sleep 1
	hostapd_sta.sh $wifi_if $sec_type $conf_file
elif [ "$1" = "3" ]; then
	killall hostapd
	echo "killall hostapd"
	sleep 1
	hostapd_ap.sh $wifi_if $sec_type $conf_file
	sleep 2
	iwpriv $wifi_if set wds=1
	echo "set wds = 1"
elif [ "$1" = "4" ]; then
	killall wpa_supplicant
	echo "killall wpa_supplicant"
	sleep 1
	hostapd_sta.sh $wifi_if $sec_type $conf_file
	sleep 2
	iwpriv $wifi_if set wds=1
	echo "set wds = 1"
elif [ "$1" = "5" ]; then
	killall hostapd
	echo "killall hostapd"
	sleep 1
	if [ $conf_file == "" ]; then
		hostapd_ap_11r.sh $other_ap_mac_addr $ap_index $2
	else
		/usr/bin/hostapd -B $conf_file
	fi
	#$2: 2g or 5g
	sleep 2
	iwpriv $wifi_if set ftenable=1
	echo "set ftenable = 1"
else
	usage
fi

return;
