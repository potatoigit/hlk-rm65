#!/bin/sh

usage()
{
	echo " "
	echo "USAGE: hostapd_sta.sh [apcli0|apclii0] [security option: open|wpapsk|wpa2psk|wpawpa2mixedpsk|wepopen|wepshare|EnterpriseAP|wpsopen|wpswpa2psk|owe|sae|suiteB] [optional: conf=<conf_file_path>]"
	echo "example: hostapd_sta.sh apclii0 open => apclii0 with security open mode"
	echo "example: hostapd_sta.sh apcli0 wpa2psk => apcli0 with security wpa2psk mode"
	echo "example: hostapd_sta.sh apcli0 open conf=/etc/wpa_supplicant_apcli0_open.conf=> apcli0 with provided security conf file"
}

hostapd_sta_generate_conf()
{
sta_wif_if=$1;
sec_type=$2;

if [ $sta_wif_if == "apcli0" ]; then
	band=2G;
else
	band=5G;
fi

conf_file=wpa_supplicant_${sta_wif_if}_$sec_type.conf;
cp /etc/wpa_supplicant_common.conf /etc/$conf_file

if [ $sec_type == "open" ]; then
	sed -i 's/^\tssid=.*/\tssid="'${band}'_OPEN"/g' /etc/$conf_file
	sed -i 's/^\tkey_mgmt=.*/\tkey_mgmt=NONE/g' /etc/$conf_file
elif [ $sec_type == "wpapsk" ]; then
	sed -i 's/^\tssid=.*/\tssid="'${band}'_WPAPSK"/g' /etc/$conf_file
	sed -i 's/^\tkey_mgmt=.*/\tkey_mgmt=WPA-PSK/g' /etc/$conf_file
	sed -i 's/^.*psk=.*/\tpsk="12345678"/g' /etc/$conf_file
	sed -i 's/^.*proto=.*/\tproto=WPA/g' /etc/$conf_file
	sed -i 's/^.*pairwise=.*/\tpairwise=TKIP/g' /etc/$conf_file
	sed -i 's/^.*group=.*/\tgroup=TKIP/g' /etc/$conf_file
elif [ $sec_type == "wpa2psk" ]; then
	sed -i 's/^\tssid=.*/\tssid="'${band}'_WPA2PSK"/g' /etc/$conf_file
	sed -i 's/^\tkey_mgmt=.*/\tkey_mgmt=WPA-PSK/g' /etc/$conf_file
	sed -i 's/^.*psk=.*/\tpsk="12345678"/g' /etc/$conf_file
	sed -i 's/^.*proto=.*/\tproto=WPA2/g' /etc/$conf_file
	sed -i 's/^.*pairwise=.*/\tpairwise=CCMP/g' /etc/$conf_file
	sed -i 's/^.*group=.*/\tgroup=CCMP/g' /etc/$conf_file
elif [ $sec_type == "wpawpa2mixedpsk" ]; then
	sed -i 's/^\tssid=.*/\tssid="'${band}'_WPAWPA2MixedPSK"/g' /etc/$conf_file
	sed -i 's/^\tkey_mgmt=.*/\tkey_mgmt=WPA-PSK/g' /etc/$conf_file
	sed -i 's/^.*psk=.*/\tpsk="12345678"/g' /etc/$conf_file
	sed -i 's/^.*proto=.*/\tproto=WPA2\ WPA/g' /etc/$conf_file
	sed -i 's/^.*pairwise=.*/\tpairwise=CCMP/g' /etc/$conf_file
	sed -i 's/^.*group=.*/\tgroup=TKIP/g' /etc/$conf_file
elif [ $sec_type == "wepopen" ]; then
	sed -i 's/^\tssid=.*/\tssid="'${band}'_WEP_OPEN"/g' /etc/$conf_file
	sed -i 's/^\tkey_mgmt=.*/\tkey_mgmt=NONE/g' /etc/$conf_file
	sed -i 's/^.*wep_key0=.*/\twep_key0=1234567890/g' /etc/$conf_file
	sed -i 's/^.*wep_tx_keyidx=.*/\twep_tx_keyidx=0/g' /etc/$conf_file
	sed -i 's/^.*priority=.*/\tpriority=5/g' /etc/$conf_file
elif [ $sec_type == "wepshare" ]; then
	sed -i 's/^\tssid=.*/\tssid="'${band}'_WEP_SHARED"/g' /etc/$conf_file
	sed -i 's/^\tkey_mgmt=.*/\tkey_mgmt=NONE/g' /etc/$conf_file
	sed -i 's/^.*wep_key0=.*/\twep_key0=1234567890/g' /etc/$conf_file
	sed -i 's/^.*wep_key1=.*/\twep_key1=0102030405/g' /etc/$conf_file
	sed -i 's/^.*wep_key2=.*/\twep_key2="1234567890123"/g' /etc/$conf_file
	sed -i 's/^.*wep_tx_keyidx=.*/\twep_tx_keyidx=0/g' /etc/$conf_file
	sed -i 's/^.*priority=.*/\tpriority=5/g' /etc/$conf_file
	sed -i 's/^.*auth_alg=.*/\tauth_alg=SHARED/g' /etc/$conf_file
else
	echo "Wrong Input"
	rm -rf /etc/$conf_file
fi
}

hostapd_sta_connection_start()
{
if [ "$1" = "apclii0" ]; then
	if [ "$2" = "open" ]; then
		echo "apclii0(5G) security is open."
		/usr/bin/wpa_supplicant -Dnl80211 -i apclii0 -c /etc/wpa_supplicant_apclii0_open.conf &
	elif [ "$2" = "wpapsk" ]; then
		echo "apclii0(5G) security is wpapsk."
		/usr/bin/wpa_supplicant -Dnl80211 -i apclii0 -c /etc/wpa_supplicant_apclii0_wpapsk.conf &
	elif [ "$2" = "wpa2psk" ]; then
		echo "apclii0(5G) security is wpa2psk."
		/usr/bin/wpa_supplicant -Dnl80211 -i apclii0 -c /etc/wpa_supplicant_apclii0_wpa2psk.conf &
	elif [ "$2" = "wpawpa2mixedpsk" ]; then
		echo "apclii0(5G) security is wpawpa2mixedpsk."
		/usr/bin/wpa_supplicant -Dnl80211 -i apclii0 -c /etc/wpa_supplicant_apclii0_wpawpa2mixedpsk.conf &
	elif [ "$2" = "wepopen" ]; then
		echo "apclii0(5G) security is wep open."
		/usr/bin/wpa_supplicant -Dnl80211 -i apclii0 -c /etc/wpa_supplicant_apclii0_wepopen.conf &
	elif [ "$2" = "wepshare" ]; then
		echo "apclii0(5G) security is wep shared."
		/usr/bin/wpa_supplicant -Dnl80211 -i apclii0 -c /etc/wpa_supplicant_apclii0_wepshare.conf &
	elif [ "$2" = "EnterpriseAP" ]; then
		echo "apclii0(5G) security is EnterpriseAP."
		/usr/bin/wpa_supplicant -Dnl80211 -i apclii0 -c /etc/wpa_supplicant_apclii0_EnterpriseAP.conf &
	elif [ "$2" = "wpsopen" ]; then
		echo "apclii0(5G) security is wps open."
		/usr/bin/wpa_supplicant -Dnl80211 -i apclii0 -c /etc/wpa_supplicant_apclii0_wpsopen.conf &
	elif [ "$2" = "wpswpa2psk" ]; then
		echo "apclii0(5G) security is wps wpa2psk."
		/usr/bin/wpa_supplicant -Dnl80211 -i apclii0 -c /etc/wpa_supplicant_apclii0_wpswpa2psk.conf &
	elif [ "$2" = "owe" ]; then
		echo "apclii0(5G) security is owe."
		/usr/bin/wpa_supplicant -Dnl80211 -i apclii0 -c /etc/wpa_supplicant_apclii0_owe.conf &
	elif [ "$2" = "suiteB" ]; then
		echo "apclii0(5G) security is suiteB."
		/usr/bin/wpa_supplicant -Dnl80211 -i apclii0 -c /etc/wpa_supplicant_apclii0_suiteB.conf &	
	elif [ "$2" = "sae" ]; then
		echo "apclii0(5G) security is sae."
		/usr/bin/wpa_supplicant -Dnl80211 -i apclii0 -c /etc/wpa_supplicant_apclii0_sae.conf &
	else 
		echo "STA has no this security($2)"	
	fi	
elif [ "$1" = "apcli0" ]; then 
	if [ "$2" = "open" ]; then
		echo "apcli0(2G) security is open."
		/usr/bin/wpa_supplicant -Dnl80211 -i apcli0 -c /etc/wpa_supplicant_apcli0_open.conf &
	elif [ "$2" = "wpapsk" ]; then
		echo "apcli0(2G) security is wpapsk."
		/usr/bin/wpa_supplicant -Dnl80211 -i apcli0 -c /etc/wpa_supplicant_apcli0_wpapsk.conf &
	elif [ "$2" = "wpa2psk" ]; then
		echo "apcli0(2G) security is wpa2psk."
		/usr/bin/wpa_supplicant -Dnl80211 -i apcli0 -c /etc/wpa_supplicant_apcli0_wpa2psk.conf &
	elif [ "$2" = "wpawpa2mixedpsk" ]; then
		echo "apcli0(2G) security is wpawpa2mixedpsk."
		/usr/bin/wpa_supplicant -Dnl80211 -i apcli0 -c /etc/wpa_supplicant_apcli0_wpawpa2mixedpsk.conf &
	elif [ "$2" = "wepopen" ]; then
		echo "apcli0(2G) security is wep open."
		/usr/bin/wpa_supplicant -Dnl80211 -i apcli0 -c /etc/wpa_supplicant_apcli0_wepopen.conf &
	elif [ "$2" = "wepshare" ]; then
		echo "apcli0(2G) security is wep shared."
		/usr/bin/wpa_supplicant -Dnl80211 -i apcli0 -c /etc/wpa_supplicant_apcli0_wepshare.conf &
	elif [ "$2" = "EnterpriseAP" ]; then
		echo "apcli0(2G) security is EnterpriseAP."
		/usr/bin/wpa_supplicant -Dnl80211 -i apcli0 -c /etc/wpa_supplicant_apcli0_EnterpriseAP.conf &
	elif [ "$2" = "wpsopen" ]; then
		echo "apcli0(2G) security is wps open."
		/usr/bin/wpa_supplicant -Dnl80211 -i apcli0 -c /etc/wpa_supplicant_apcli0_wpsopen.conf &
	elif [ "$2" = "wpswpa2psk" ]; then
		echo "apcli0(2G) security is wps wpa2psk."
		/usr/bin/wpa_supplicant -Dnl80211 -i apcli0 -c /etc/wpa_supplicant_apcli0_wpswpa2psk.conf &
	elif [ "$2" = "owe" ]; then
		echo "apcli0(2G) security is owe."
		/usr/bin/wpa_supplicant -Dnl80211 -i apcli0 -c /etc/wpa_supplicant_apcli0_owe.conf &
	elif [ "$2" = "suiteB" ]; then
		echo "apcli0(2G) security is suiteB."
		/usr/bin/wpa_supplicant -Dnl80211 -i apcli0 -c /etc/wpa_supplicant_apcli0_suiteB.conf &
	elif [ "$2" = "sae" ]; then
		echo "apcli0(2G) security is sae."
		/usr/bin/wpa_supplicant -Dnl80211 -i apcli0 -c /etc/wpa_supplicant_apclii0_sae.conf &
	else
		echo "STA has no this security($2)"		
	fi
fi
}

echo "HOSTAPD APCLI script..."

sta_wif_if=$1;
sec_type=$2;

if [ $# -eq 3 ]; then
	/usr/bin/wpa_supplicant -Dnl80211 -i $sta_wif_if -c $3 &
elif [ "$1" = "apclii0" ] || [ "$1" = "apcli0" ]; then
	hostapd_sta_generate_conf $sta_wif_if $sec_type
	hostapd_sta_connection_start $sta_wif_if $sec_type
else
	usage	
fi

return;
