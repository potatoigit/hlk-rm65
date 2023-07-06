#!/bin/sh

usage()
{
	echo " "
	echo "USAGE: hostapd_ap.sh [ra0|rai0|rax0|both] [security option: open|wpapsk|wpa2psk|wpawpa2mixedpsk|wepopen|wepshare|EnterpriseAP|wpsopen|wpswpa2psk|owe|sae|suiteB] [optional: conf=<conf_file_path>]"
	echo "example: hostapd_ap.sh rai0 open => rai0 with security open mode"
	echo "example: hostapd_ap.sh rax0 open => rax0 with security open mode"
	echo "example: hostapd_ap.sh ra0 wpa2psk => ra0 with security wpa2psk mode"
	echo "example: hostapd_ap.sh both EnterpriseAP => ra0 and rai0 with security EnterpriseAP mode"
	echo "example: hostapd_ap.sh ra0 open conf=/etc/hostapd_ra0_open.conf=> ra0 up with provided configuration"
}

hostapd_generate_conf()
{
wif_if=$1;
sec_type=$2;
if [ $wif_if == "rai0" ]; then
	band=2G;
elif [ $wif_if == "rax0" ]; then
	band=5G;
else
	band=6G;
fi

if [ $sec_type == "EnterpriseAP" ]; then
	conf_file=hostapd_${wif_if}_wpa2$sec_type.conf;
else
	conf_file=hostapd_${wif_if}_$sec_type.conf;
fi
cp /etc/hostapd_common.conf /etc/$conf_file

# Interface name update
sed -i 's/^interface=.*/interface='${wif_if}'/g' /etc/$conf_file

if [ $sec_type == "open" ]; then
	sed -i 's/^ssid=.*/ssid='${band}'_OPEN/g' /etc/$conf_file
elif [ $sec_type == "wpapsk" ]; then
	sed -i 's/^ssid=.*/ssid='${band}'_WPAPSK/g' /etc/$conf_file
	sed -i 's/^.*wpa=.*/wpa=1/g' /etc/$conf_file
	sed -i 's/^.*wpa_passphrase=.*/wpa_passphrase=12345678/g' /etc/$conf_file
	sed -i 's/^.*wpa_key_mgmt=.*/wpa_key_mgmt=WPA-PSK/g' /etc/$conf_file
	sed -i 's/^.*wpa_pairwise=.*/wpa_pairwise=TKIP/g' /etc/$conf_file
elif [ $sec_type == "wpa2psk" ]; then
	sed -i 's/^ssid=.*/ssid='${band}'_WPA2PSK/g' /etc/$conf_file
	sed -i 's/^.*wpa=.*/wpa=2/g' /etc/$conf_file
	sed -i 's/^.*wpa_passphrase=.*/wpa_passphrase=12345678/g' /etc/$conf_file
	sed -i 's/^.*wpa_key_mgmt=.*/wpa_key_mgmt=WPA-PSK/g' /etc/$conf_file
	sed -i 's/^.*rsn_pairwise=.*/rsn_pairwise=CCMP/g' /etc/$conf_file
elif [ $sec_type == "wpawpa2mixedpsk" ]; then
	sed -i 's/^ssid=.*/ssid='${band}'_WPAWPA2MixedPSK/g' /etc/$conf_file
	sed -i 's/^.*wpa=.*/wpa=3/g' /etc/$conf_file
	sed -i 's/^.*wpa_passphrase=.*/wpa_passphrase=12345678/g' /etc/$conf_file
	sed -i 's/^.*wpa_key_mgmt=.*/wpa_key_mgmt=WPA-PSK/g' /etc/$conf_file
	sed -i 's/^.*wpa_pairwise=.*/wpa_pairwise=TKIP CCMP/g' /etc/$conf_file
elif [ $sec_type == "wepopen" ]; then
	sed -i 's/^ssid=.*/ssid='${band}'_WEP_OPEN/g' /etc/$conf_file
	sed -i 's/^.*wep_key0=.*/wep_key0=1234567890/g' /etc/$conf_file
	sed -i 's/^.*wep_default_key=.*/wep_default_key=0/g' /etc/$conf_file
elif [ $sec_type == "wepshare" ]; then
	sed -i 's/^ssid=.*/ssid='${band}'_WEP_SHARED/g' /etc/$conf_file
	sed -i 's/^.*wep_key0=.*/wep_key0=1234567890/g' /etc/$conf_file
	sed -i 's/^.*wep_default_key=.*/wep_default_key=0/g' /etc/$conf_file
	sed -i 's/^.*auth_algs=.*/auth_algs=2/g' /etc/$conf_file
elif [ $sec_type == "EnterpriseAP" ]; then
	sed -i 's/^ssid=.*/ssid='${band}'_WPA2ENTERPRISE/g' /etc/$conf_file
	sed -i 's/^.*auth_algs=.*/auth_algs=3/g' /etc/$conf_file
	sed -i 's/^.*wpa=.*/wpa=2/g' /etc/$conf_file
	sed -i 's/^.*wpa_key_mgmt=.*/wpa_key_mgmt=WPA-EAP/g' /etc/$conf_file
	sed -i 's/^.*rsn_pairwise=.*/rsn_pairwise=CCMP/g' /etc/$conf_file
	sed -i 's/^.*ieee8021x=.*/ieee8021x=1/g' /etc/$conf_file
	sed -i 's/^.*own_ip_addr=.*/own_ip_addr=192.168.1.1/g' /etc/$conf_file
	sed -i 's/^.*auth_server_addr=.*/auth_server_addr=192.168.1.15/g' /etc/$conf_file
	sed -i 's/^.*auth_server_port=.*/auth_server_port=1812/g' /etc/$conf_file
	sed -i 's/^.*auth_server_shared_secret=.*/auth_server_shared_secret=12345678/g' /etc/$conf_file
	sed -i 's/^.*rsn_preauth=.*/rsn_preauth=1/g' /etc/$conf_file
	sed -i 's/^.*rsn_preauth_interfaces=.*/rsn_preauth_interfaces=br-lan/g' /etc/$conf_file
elif [ $sec_type == "wpsopen" ]; then
	sed -i 's/^ssid=.*/ssid='${band}'_WPSOPEN/g' /etc/$conf_file
	sed -i 's/^.*eap_server=.*/eap_server=1/g' /etc/$conf_file
	sed -i 's/^.*wps_state=.*/wps_state=2/g' /etc/$conf_file
	sed -i 's/^.*wps_independent=.*/wps_independent=1/g' /etc/$conf_file
	sed -i 's/^.*device_name=/device_name=/g' /etc/$conf_file
	sed -i 's/^.*manufacturer=/manufacturer=/g' /etc/$conf_file
	sed -i 's/^.*model_name=.*/model_name=WAP/g' /etc/$conf_file
	sed -i 's/^.*model_number=.*/model_number=123/g' /etc/$conf_file
	sed -i 's/^.*serial_number=.*/serial_number=12345/g' /etc/$conf_file
	sed -i 's/^.*device_type=.*/device_type=6-0050F204-1/g' /etc/$conf_file
	sed -i 's/^.*config_methods=/config_methods=/g' /etc/$conf_file
elif [ $sec_type == "wpswpa2psk" ]; then
	sed -i 's/^ssid=.*/ssid='${band}'_WPSWPA2PSK/g' /etc/$conf_file
	sed -i 's/^.*wpa=.*/wpa=2/g' /etc/$conf_file
	sed -i 's/^.*wpa_passphrase=.*/wpa_passphrase=12345678/g' /etc/$conf_file
	sed -i 's/^.*wpa_key_mgmt=.*/wpa_key_mgmt=WPA-PSK/g' /etc/$conf_file
	sed -i 's/^.*rsn_pairwise=.*/rsn_pairwise=CCMP/g' /etc/$conf_file
	sed -i 's/^.*eapol_version=.*/eapol_version=2/g' /etc/$conf_file
	sed -i 's/^.*eap_server=.*/eap_server=1/g' /etc/$conf_file
	sed -i 's/^.*wps_state=.*/wps_state=2/g' /etc/$conf_file
	sed -i 's/^.*wps_independent=.*/wps_independent=1/g' /etc/$conf_file
	sed -i 's/^.*device_name=/device_name=/g' /etc/$conf_file
	sed -i 's/^.*manufacturer=/manufacturer=/g' /etc/$conf_file
	sed -i 's/^.*model_name=.*/model_name=WAP/g' /etc/$conf_file
	sed -i 's/^.*model_number=.*/model_number=123/g' /etc/$conf_file
	sed -i 's/^.*serial_number=.*/serial_number=12345/g' /etc/$conf_file
	sed -i 's/^.*device_type=.*/device_type=6-0050F204-1/g' /etc/$conf_file
	sed -i 's/^.*config_methods=/config_methods=/g' /etc/$conf_file
elif [ $sec_type == "sae" ]; then
	sed -i 's/^ssid=.*/ssid='${band}'_SAE/g' /etc/$conf_file
	sed -i 's/^.*wpa=.*/wpa=2/g' /etc/$conf_file
	sed -i 's/^.*wpa_passphrase=.*/wpa_passphrase=12345678/g' /etc/$conf_file
	sed -i 's/^.*wpa_key_mgmt=.*/wpa_key_mgmt=SAE/g' /etc/$conf_file
	sed -i 's/^.*rsn_pairwise=.*/rsn_pairwise=CCMP/g' /etc/$conf_file
	sed -i 's/^.*eapol_version=.*/eapol_version=2/g' /etc/$conf_file
	sed -i 's/^.*ieee80211w=.*/ieee80211w=2/g' /etc/$conf_file
elif [ $sec_type == "suiteB" ]; then
	sed -i 's/^ssid=.*/ssid='${band}'_SuiteB/g' /etc/$conf_file
	sed -i 's/^.*auth_algs=.*/auth_algs=3/g' /etc/$conf_file
	sed -i 's/^.*ctrl_interface_group=.*/ctrl_interface_group=0/g' /etc/$conf_file
	sed -i 's/^.*wpa=.*/wpa=2/g' /etc/$conf_file
	sed -i 's/^.*wpa_passphrase=.*/wpa_passphrase=12345678/g' /etc/$conf_file
	sed -i 's/^.*wpa_key_mgmt=.*/wpa_key_mgmt=WPA-EAP-SUITE-B-192/g' /etc/$conf_file
	sed -i 's/^.*wpa_group_rekey=.*/wpa_group_rekey=30000/g' /etc/$conf_file
	sed -i 's/^.*ieee8021x=.*/ieee8021x=1/g' /etc/$conf_file
	sed -i 's/^.*ieee80211w=.*/ieee80211w=2/g' /etc/$conf_file
	sed -i 's/^.*own_ip_addr=.*/own_ip_addr=192.168.1.1/g' /etc/$conf_file
	sed -i 's/^.*auth_server_addr=.*/auth_server_addr=192.168.1.15/g' /etc/$conf_file
	sed -i 's/^.*auth_server_port=.*/auth_server_port=1812/g' /etc/$conf_file
	sed -i 's/^.*auth_server_shared_secret=.*/auth_server_shared_secret=1234567890123456789012345678901234567890123456789012345678901234/g' /etc/$conf_file
	sed -i 's/^.*rsn_preauth=.*/rsn_preauth=1/g' /etc/$conf_file
	sed -i 's/^.*rsn_preauth_interfaces=.*/rsn_preauth_interfaces=br-lan/g' /etc/$conf_file
	sed -i 's/^.*rsn_pairwise=.*/rsn_pairwise=GCMP-256/g' /etc/$conf_file
	sed -i 's/^.*group_mgmt_cipher=.*/group_mgmt_cipher=BIP-GMAC-256/g' /etc/$conf_file
else
	echo "Wrong Input!!!"
	rm -rf /etc/$conf_file
fi
}

hostapd_ap_start()
{
if [ "$1" = "rai0" ]; then
	if [ "$2" = "open" ]; then
		echo "rai0(2G) security is open."
		/usr/bin/hostapd -B /etc/hostapd_rai0_open.conf
	elif [ "$2" = "wpapsk" ]; then
		echo "rai0(2G) security is wpapsk."
		/usr/bin/hostapd -B /etc/hostapd_rai0_wpapsk.conf
	elif [ "$2" = "wpa2psk" ]; then
		echo "rai0(2G) security is wpa2psk."
		/usr/bin/hostapd -B /etc/hostapd_rai0_wpa2psk.conf
	elif [ "$2" = "wpawpa2mixedpsk" ]; then
		echo "rai0(2G) security is wpawpa2mixedpsk."
		/usr/bin/hostapd -B /etc/hostapd_rai0_wpawpa2mixedpsk.conf
	elif [ "$2" = "wepopen" ]; then
		echo "rai0(2G) security is wep open."
		/usr/bin/hostapd -B /etc/hostapd_rai0_wepopen.conf
	elif [ "$2" = "wepshare" ]; then
		echo "rai0(2G)security is wep shared."
		/usr/bin/hostapd -B /etc/hostapd_rai0_wepshare.conf
	elif [ "$2" = "EnterpriseAP" ]; then
		echo "rai0(2G) security is EnterpriseAP."
		/usr/bin/hostapd -B /etc/hostapd_rai0_wpa2EnterpriseAP.conf
	elif [ "$2" = "wpsopen" ]; then
		echo "rai0(2G) security is wps open."
		/usr/bin/hostapd -B /etc/hostapd_rai0_wpsopen.conf
	elif [ "$2" = "wpswpa2psk" ]; then
		echo "rai0(2G) security is wps wpa2psk."
		/usr/bin/hostapd -B /etc/hostapd_rai0_wpswpa2psk.conf
	elif [ "$2" = "owe" ]; then
		echo "rai0(2G) security is owe."
		/usr/bin/hostapd -B /etc/hostapd_rai0_owe.conf
	elif [ "$2" = "sae" ]; then
		echo "rai0(2G) security is sae."
		/usr/bin/hostapd -B /etc/hostapd_rai0_sae.conf
	elif [ "$2" = "suiteB" ]; then
		echo "rai0(2G) security is suiteB."
		/usr/bin/hostapd -B /etc/hostapd_rai0_suiteB.conf
	else 
		echo "AP has no this security($2)"	
	fi	

elif [ "$1" = "rax0" ]; then
	if [ "$2" = "open" ]; then
		echo "rax0(5G) security is open."
		/usr/bin/hostapd -B /etc/hostapd_rax0_open.conf
	elif [ "$2" = "wpapsk" ]; then
		echo "rax0(5G) security is wpapsk."
		/usr/bin/hostapd -B /etc/hostapd_rax0_wpapsk.conf
	elif [ "$2" = "wpa2psk" ]; then
		echo "rax0(5G) security is wpa2psk."
		/usr/bin/hostapd -B /etc/hostapd_rax0_wpa2psk.conf
	elif [ "$2" = "wpawpa2mixedpsk" ]; then
		echo "rax0(5G) security is wpawpa2mixedpsk."
		/usr/bin/hostapd -B /etc/hostapd_rax0_wpawpa2mixedpsk.conf
	elif [ "$2" = "wepopen" ]; then
		echo "rax0(5G) security is wep open."
		/usr/bin/hostapd -B /etc/hostapd_rax0_wepopen.conf
	elif [ "$2" = "wepshare" ]; then
		echo "rax0(5G)security is wep shared."
		/usr/bin/hostapd -B /etc/hostapd_rax0_wepshare.conf
	elif [ "$2" = "EnterpriseAP" ]; then
		echo "rax0(5G) security is EnterpriseAP."
		/usr/bin/hostapd -B /etc/hostapd_rax0_wpa2EnterpriseAP.conf
	elif [ "$2" = "wpsopen" ]; then
		echo "rax0(5G) security is wps open."
		/usr/bin/hostapd -B /etc/hostapd_rax0_wpsopen.conf
	elif [ "$2" = "wpswpa2psk" ]; then
		echo "rax0(5G) security is wps wpa2psk."
		/usr/bin/hostapd -B /etc/hostapd_rax0_wpswpa2psk.conf
	elif [ "$2" = "owe" ]; then
		echo "rax0(5G) security is owe."
		/usr/bin/hostapd -B /etc/hostapd_rax0_owe.conf
	elif [ "$2" = "sae" ]; then
		echo "rax0(5G) security is sae."
		/usr/bin/hostapd -B /etc/hostapd_rax0_sae.conf
	elif [ "$2" = "suiteB" ]; then
		echo "rax0(5G) security is suiteB."
		/usr/bin/hostapd -B /etc/hostapd_rax0_suiteB.conf
	else 
		echo "AP has no this security($2)"	
	fi	


elif [ "$1" = "raix0" ]; then 
	if [ "$2" = "open" ]; then
		echo "raix0(6G) security is open."
		/usr/bin/hostapd -B /etc/hostapd_raix0_open.conf
	elif [ "$2" = "wpapsk" ]; then
		echo "raix0(6G) security is wpapsk."
		/usr/bin/hostapd -B  /etc/hostapd_raix0_wpapsk.conf
	elif [ "$2" = "wpa2psk" ]; then
		echo "raix0(6G) security is wpa2psk."
		/usr/bin/hostapd -B  /etc/hostapd_raix0_wpa2psk.conf
	elif [ "$2" = "wpawpa2mixedpsk" ]; then
		echo "raix0(6G) security is wpawpa2mixedpsk."
		/usr/bin/hostapd -B /etc/hostapd_raix0_wpawpa2mixedpsk.conf
	elif [ "$2" = "wepopen" ]; then
		echo "raix0(6G) security is wep open."
		/usr/bin/hostapd -B /etc/hostapd_raix0_wepopen.conf
	elif [ "$2" = "wepshare" ]; then
		echo "raix0(6G) security is wep shared."
		/usr/bin/hostapd -B /etc/hostapd_raix0_wepshare.conf
	elif [ "$2" = "EnterpriseAP" ]; then
		echo "raix0(6G) security is EnterpriseAP."
		/usr/bin/hostapd -B  /etc/hostapd_raix0_wpa2EnterpriseAP.conf
	elif [ "$2" = "wpsopen" ]; then
		echo "raix0(6G) security is wps open."
		/usr/bin/hostapd -B /etc/hostapd_raix0_wpsopen.conf
	elif [ "$2" = "wpswpa2psk" ]; then
		echo "raix0(6G) security is wps wpa2psk."
		/usr/bin/hostapd -B /etc/hostapd_raix0_wpswpa2psk.conf
	elif [ "$2" = "owe" ]; then
		echo "raix0(6G) security is owe."
		/usr/bin/hostapd -B  /etc/hostapd_raix0_owe.conf
	elif [ "$2" = "sae" ]; then
		echo "raix0(6G) security is sae."
		/usr/bin/hostapd -B /etc/hostapd_raix0_sae.conf
	elif [ "$2" = "suiteB" ]; then
		echo "raix0(6G) security is suiteB."
		/usr/bin/hostapd -B /etc/hostapd_raix0_suiteB.conf
	else
		echo "AP has no this security($2)"		
	fi
elif [ "$1" = "both" ]; then 
	if [ "$2" = "open" ]; then
		echo "ra0(2G) and rai0(5G) security is open."
		/usr/bin/hostapd -B /etc/hostapd_rai0_open.conf /etc/hostapd_ra0_open.conf
	elif [ "$2" = "wpapsk" ]; then
		echo "ra0(2G) and rai0(5G) security is wpapsk."
		/usr/bin/hostapd -B /etc/hostapd_rai0_wpapsk.conf /etc/hostapd_ra0_wpapsk.conf
	elif [ "$2" = "wpa2psk" ]; then
		echo "ra0(2G) and rai0(5G) security is wpa2psk."
		/usr/bin/hostapd -B /etc/hostapd_rai0_wpa2psk.conf /etc/hostapd_ra0_wpa2psk.conf
	elif [ "$2" = "wpawpa2mixedpsk" ]; then
		echo "ra0(2G) and rai0(5G) security is wpawpa2mixedpsk."
		/usr/bin/hostapd -B /etc/hostapd_rai0_wpawpa2mixedpsk.conf /etc/hostapd_ra0_wpawpa2mixedpsk.conf
	elif [ "$2" = "wepopen" ]; then
		echo "ra0(2G) and rai0(5G)security is wep open."
		/usr/bin/hostapd -B /etc/hostapd_rai0_wepopen.conf /etc/hostapd_ra0_wepopen.conf
	elif [ "$2" = "wepshare" ]; then
		echo "ra0(2G) and rai0(5G)security is wep shared."
		/usr/bin/hostapd -B /etc/hostapd_rai0_wepshare.conf /etc/hostapd_ra0_wepshare.conf
	elif [ "$2" = "EnterpriseAP" ]; then
		echo "ra0(2G) and rai0(5G) security is EnterpriseAP."
		/usr/bin/hostapd -B /etc/hostapd_rai0_wpa2EnterpriseAP.conf /etc/hostapd_ra0_wpa2EnterpriseAP.conf
	elif [ "$2" = "wpsopen" ]; then
		echo "ra0(2G) and rai0(5G) security is wps open."
		/usr/bin/hostapd -B /etc/hostapd_rai0_wpsopen.conf /etc/hostapd_ra0_wpsopen.conf
	elif [ "$2" = "wpswpa2psk" ]; then
		echo "ra0(2G) and rai0(5G) security is wps wpa2psk."
		/usr/bin/hostapd -B /etc/hostapd_rai0_wpswpa2psk.conf /etc/hostapd_ra0_wpswpa2psk.conf
	elif [ "$2" = "owe" ]; then
		echo "ra0(2G) and rai0(5G) security is owe."
		/usr/bin/hostapd -B /etc/hostapd_rai0_owe.conf /etc/hostapd_ra0_owe.conf
	elif [ "$2" = "sae" ]; then
		echo "ra0(2G) and rai0(5G) security is sae."
		/usr/bin/hostapd -B /etc/hostapd_rai0_sae.conf /etc/hostapd_ra0_sae.conf
	elif [ "$2" = "suiteB" ]; then
		echo "ra0(2G) and rai0(5G) security is suiteB."
		/usr/bin/hostapd -B /etc/hostapd_rai0_suiteB.conf /etc/hostapd_ra0_suiteB.conf
	else
		echo "APs has no this security($2)"		
	fi	
fi
}

echo "HOSTAPD AP script..."

wif_if=$1;
sec_type=$2;

if [ $# -eq 3 ]; then
	/usr/bin/hostapd -B $3
elif [ "$1" = "rai0" ] || [ "$1" = "rax0" ] || [ "$1" = "raix0" ] || [ "$1" = "both" ]; then
	if [ $sec_type == "owe" ]; then
		hostapd_ap_start $wif_if $sec_type
	else
		hostapd_generate_conf $wif_if $sec_type
		hostapd_ap_start $wif_if $sec_type
	fi
else
	usage	
fi

return;
