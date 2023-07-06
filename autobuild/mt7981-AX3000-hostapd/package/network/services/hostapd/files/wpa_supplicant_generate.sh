#!/bin/sh

usage()
{
	echo " "
	echo "USAGE: wpa_supplicant_generate.sh [interface: apcli0|apclii0] [security option: open|wpapsk|wpa2psk|wpawpa2mixedpsk|wepopen|wepshare]"
}

if [ $# -lt 2 ]; then
	echo "Wrong Input!!!"
	usage
	exit 1
fi

sta_wif_if=$1;
sec_type=$2;

if [ $sta_wif_if == "apcli0" ]; then
	band=2G;
else
	band=5G;
fi

conf_file=wpa_supplicant_${sta_wif_if}_$sec_type.conf;
cp /etc/wpa_supplicant_common.conf $conf_file

if [ $sec_type == "open" ]; then
	sed -i 's/^\tssid=.*/\tssid="'${band}'_OPEN"/g' $conf_file
	sed -i 's/^\tkey_mgmt=.*/\tkey_mgmt=NONE/g' $conf_file
elif [ $sec_type == "wpapsk" ]; then
	sed -i 's/^\tssid=.*/\tssid="'${band}'_WPAPSK"/g' $conf_file
	sed -i 's/^\tkey_mgmt=.*/\tkey_mgmt=WPA-PSK/g' $conf_file
	sed -i 's/^.*psk=.*/\tpsk="12345678"/g' $conf_file
	sed -i 's/^.*proto=.*/\tproto=WPA/g' $conf_file
	sed -i 's/^.*pairwise=.*/\tpairwise=TKIP/g' $conf_file
	sed -i 's/^.*group=.*/\tgroup=TKIP/g' $conf_file
elif [ $sec_type == "wpa2psk" ]; then
	sed -i 's/^\tssid=.*/\tssid="'${band}'_WPA2PSK"/g' $conf_file
	sed -i 's/^\tkey_mgmt=.*/\tkey_mgmt=WPA-PSK/g' $conf_file
	sed -i 's/^.*psk=.*/\tpsk="12345678"/g' $conf_file
	sed -i 's/^.*proto=.*/\tproto=WPA2/g' $conf_file
	sed -i 's/^.*pairwise=.*/\tpairwise=CCMP/g' $conf_file
	sed -i 's/^.*group=.*/\tgroup=CCMP/g' $conf_file
elif [ $sec_type == "wpa3psk" ]; then
	sed -i 's/^\tssid=.*/\tssid="'${band}'_WPA3PSK"/g' $conf_file
	sed -i 's/^\tkey_mgmt=.*/\tkey_mgmt=SAE/g' $conf_file
	sed -i 's/^.*psk=.*/\tpsk="12345678"/g' $conf_file
	sed -i 's/^.*proto=.*/\tproto=RSN/g' $conf_file
	sed -i 's/^.*pairwise=.*/\tpairwise=CCMP/g' $conf_file
	sed -i 's/^.*group=.*/\tgroup=CCMP/g' $conf_file
	sed -i 's/^.*ieee80211w=.*/\tieee80211w=2/g' $conf_file
elif [ $sec_type == "owe" ]; then
	sed -i 's/^\tssid=.*/\tssid="'${band}'_OWE"/g' $conf_file
	sed -i 's/^\tkey_mgmt=.*/\tkey_mgmt=OWE/g' $conf_file
	sed -i 's/^.*proto=.*/\tproto=RSN/g' $conf_file
	sed -i 's/^.*pairwise=.*/\tpairwise=CCMP/g' $conf_file
	sed -i 's/^.*group=.*/\tgroup=CCMP/g' $conf_file
	sed -i 's/^.*ieee80211w=.*/\tieee80211w=2/g' $conf_file
elif [ $sec_type == "wpawpa2mixedpsk" ]; then
	sed -i 's/^\tssid=.*/\tssid="'${band}'_WPAWPA2MixedPSK"/g' $conf_file
	sed -i 's/^\tkey_mgmt=.*/\tkey_mgmt=WPA-PSK/g' $conf_file
	sed -i 's/^.*psk=.*/\tpsk="12345678"/g' $conf_file
	sed -i 's/^.*proto=.*/\tproto=WPA2\ WPA/g' $conf_file
	sed -i 's/^.*pairwise=.*/\tpairwise=CCMP/g' $conf_file
	sed -i 's/^.*group=.*/\tgroup=TKIP/g' $conf_file
elif [ $sec_type == "wepopen" ]; then
	sed -i 's/^\tssid=.*/\tssid="'${band}'_WEP_OPEN"/g' $conf_file
	sed -i 's/^\tkey_mgmt=.*/\tkey_mgmt=NONE/g' $conf_file
	sed -i 's/^.*wep_key0=.*/\twep_key0=1234567890/g' $conf_file
	sed -i 's/^.*wep_tx_keyidx=.*/\twep_tx_keyidx=0/g' $conf_file
	sed -i 's/^.*priority=.*/\tpriority=5/g' $conf_file
elif [ $sec_type == "wepshare" ]; then
	sed -i 's/^\tssid=.*/\tssid="'${band}'_WEP_SHARED"/g' $conf_file
	sed -i 's/^\tkey_mgmt=.*/\tkey_mgmt=NONE/g' $conf_file
	sed -i 's/^.*wep_key0=.*/\twep_key0=1234567890/g' $conf_file
	sed -i 's/^.*wep_key1=.*/\twep_key1=0102030405/g' $conf_file
	sed -i 's/^.*wep_key2=.*/\twep_key2="1234567890123"/g' $conf_file
	sed -i 's/^.*wep_tx_keyidx=.*/\twep_tx_keyidx=0/g' $conf_file
	sed -i 's/^.*priority=.*/\tpriority=5/g' $conf_file
	sed -i 's/^.*auth_alg=.*/\tauth_alg=SHARED/g' $conf_file
else
	echo $sec_type" is not supported!!!"
	rm -rf $conf_file
	usage
	exit 1
fi

echo $sta_wif_if"("$band") "$sec_type" mode ==> File generated: "$conf_file
