#!/usr/bin/env lua


function hostapd_setup_vif(dev, iface)
	local file_name = "/var/run/hostapd/hostapd-"..iface[".name"]..".conf"
	local file

	file = io.open(file_name, "w+")

	io.output(file)
	io.write("interface=", iface[".name"], "\n")

--	if dev.country ~= nil then
--		io.write("country_code=", dev.country, "\n")
--	end

--	if dev.country_ie ~= nil then
--		io.write("ieee80211d=", dev.country_ie, "\n")
--	end

	if dev.channel == "auto" or
	   dev.channel == nil or
	   tonumber(dev.channel) == nil then
		io.write("channel=0\n")
	else
		io.write("channel=", dev.channel, "\n")
	end


	io.write("bridge=", "br-", iface.network, "\n")  -- need to have network to bridge translate function

	io.write("driver=nl80211\n")

	io.write("ssid=", iface.ssid, "\n")

	if dev.band == "2.4G" then
		io.write("hw_mode=g\n")
		io.write("preamble=1\n")
		io.write("ieee80211n=1\n")
		io.write("ieee80211ac=1\n")
		io.write("ieee80211ax=1\n")
		io.write("ieee80211be=1\n")
	elseif dev.band == "5G" then
		io.write("hw_mode=a\n")
		io.write("ieee80211n=1\n")
		io.write("ieee80211ac=1\n")
		io.write("ieee80211ax=1\n")
		io.write("ieee80211be=1\n")
	elseif dev.band == "6G" then
		io.write("hw_mode=a\n")
		io.write("ieee80211ax=1\n")
		io.write("ieee80211be=1\n")
	end
	if iface.beacon_int ~= nil then
		if tonumber(iface.beacon_int) >= 15 and tonumber(iface.beacon_int) <= 65535 then
			io.write("beacon_int=", iface.beacon_int, "\n")
		end
	end

	if dev.dtim_period ~= nil then
		if tonumber(dev.dtim_period) >= 1 and tonumber(dev.dtim_period) <= 255 then
			io.write("dtim_period=", dev.dtim_period, "\n")
		end
	end

	if iface.hidden ~= nil then
		if iface.hidden == "0" then
			io.write("ignore_broadcast_ssid=0\n")
		elseif iface.hidden == "2" then
			io.write("ignore_broadcast_ssid=2\n")
		else
			io.write("ignore_broadcast_ssid=1\n")
		end
	end

	if dev.beacon_int ~= nil then
		io.write("beacon_int="..dev.beacon_int.."\n")
	end
	io.write("macaddr_acl=0\n")

	if iface.encryption == "none" or
		iface.encryption == nil then
		io.write("auth_algs=1\n")
	elseif iface.encryption == "psk2+tkip+ccmp" then
		io.write("auth_algs=1\n")
		io.write("wpa=2\n")
		io.write("wpa_key_mgmt=WPA-PSK\n")
		io.write("rsn_pairwise=TKIP CCMP\n")
	elseif iface.encryption == "psk2+tkip" then
		io.write("auth_algs=1\n")
		io.write("wpa=2\n")
		io.write("wpa_key_mgmt=WPA-PSK\n")
		io.write("rsn_pairwise=TKIP\n")
	elseif iface.encryption == "psk2+ccmp" then
		io.write("auth_algs=1\n")
		io.write("wpa=2\n")
		io.write("wpa_key_mgmt=WPA-PSK\n")
		io.write("rsn_pairwise=CCMP\n")
	elseif iface.encryption == "psk+tkip+ccmp" then
		io.write("auth_algs=1\n")
		io.write("wpa=1\n")
		io.write("wpa_key_mgmt=WPA-PSK\n")
		io.write("wpa_pairwise=TKIP CCMP\n")
	elseif iface.encryption == "psk+tkip" then
		io.write("auth_algs=1\n")
		io.write("wpa=1\n")
		io.write("wpa_key_mgmt=WPA-PSK\n")
		io.write("wpa_pairwise=TKIP\n")
	elseif iface.encryption == "psk+ccmp" then
		io.write("auth_algs=1\n")
		io.write("wpa=1\n")
		io.write("wpa_key_mgmt=WPA-PSK\n")
		io.write("wpa_pairwise=CCMP\n")
	elseif iface.encryption == "psk-mixed+tkip+ccmp" then
		io.write("auth_algs=1\n")
		io.write("wpa=3\n")
		io.write("wpa_key_mgmt=WPA-PSK\n")
		io.write("rsn_pairwise=TKIP CCMP\n")
	elseif iface.encryption == "psk-mixed+tkip" then
		io.write("auth_algs=1\n")
		io.write("wpa=3\n")
		io.write("wpa_key_mgmt=WPA-PSK\n")
		io.write("rsn_pairwise=TKIP\n")
	elseif iface.encryption == "psk-mixed+ccmp" then
		io.write("auth_algs=1\n")
		io.write("wpa=3\n")
		io.write("wpa_key_mgmt=WPA-PSK\n")
		io.write("rsn_pairwise=CCMP\n")
	elseif iface.encryption == "wep" or
	       iface.encryption == "wep-open" then
		io.write("auth_algs=1\n")
		io.write("wpa=0\n")
	elseif iface.encryption == "wep-shared" then
		io.write("auth_algs=2\n")
		io.write("wpa=0\n")
	elseif iface.encryption == "wep-auto" then
		io.write("auth_algs=3\n")
		io.write("wpa=0\n")
	elseif iface.encryption == "wpa3" then
		io.write("auth_algs=1")
		io.write("wpa=2")
		io.write("wpa_key_mgmt=WPA-EAP-SUITE-B-192")
		io.write("rsn_pairwise=CCMP")
	elseif iface.encryption == "wpa3-192" then
		io.write("auth_algs=1")
		io.write("wpa=2")
		io.write("wpa_key_mgmt=WPA-EAP-SUITE-B-192")
		io.write("rsn_pairwise=GCMP-256")
	elseif iface.encryption == "wpa3-mixed" then
		io.write("auth_algs=1\n")
		io.write("wpa=2\n")
		io.write("wpa_key_mgmt=WPA-EAP WPA-EAP-SUITE-B-192\n")
		io.write("rsn_pairwise=TKIP CCMP\n")
	elseif iface.encryption == "wpa2+tkip+ccmp" then
		io.write("auth_algs=1\n")
		io.write("wpa=2\n")
		io.write("wpa_key_mgmt=WPA-EAP\n")
		io.write("rsn_pairwise=TKIP CCMP\n")
	elseif iface.encryption == "wpa2+ccmp" then
		io.write("auth_algs=1\n")
		io.write("wpa=2\n")
		io.write("wpa_key_mgmt=WPA-EAP\n")
		io.write("rsn_pairwise=CCMP\n")
	elseif iface.encryption == "wpa2+tkip" then
		io.write("auth_algs=1\n")
		io.write("wpa=2\n")
		io.write("wpa_key_mgmt=WPA-EAP\n")
		io.write("rsn_pairwise=TKIP\n")
	elseif iface.encryption == "wpa+tkip+ccmp" then
		io.write("auth_algs=1\n")
		io.write("wpa=1\n")
		io.write("wpa_key_mgmt=WPA-EAP\n")
		io.write("wpa_pairwise=TKIP CCMP\n")
	elseif iface.encryption == "wpa+ccmp" then
		io.write("auth_algs=1\n")
		io.write("wpa=1\n")
		io.write("wpa_key_mgmt=WPA-EAP\n")
		io.write("wpa_pairwise=CCMP\n")
	elseif iface.encryption == "wpa+tkip" then
		io.write("auth_algs=1\n")
		io.write("wpa=1\n")
		io.write("wpa_key_mgmt=WPA-EAP\n")
		io.write("wpa_pairwise=TKIP\n")
	elseif iface.encryption == "wpa-mixed+tkip+ccmp" then
		io.write("auth_algs=1\n")
		io.write("wpa=3\n")
		io.write("wpa_key_mgmt=WPA-EAP\n")
		io.write("rsn_pairwise=TKIP CCMP\n")
	elseif iface.encryption == "wpa-mixed+tkip" then
		io.write("auth_algs=1\n")
		io.write("wpa=3\n")
		io.write("wpa_key_mgmt=WPA-EAP\n")
		io.write("rsn_pairwise=TKIP\n")
	elseif iface.encryption == "wpa-mixed+ccmp" then
		io.write("auth_algs=1\n")
		io.write("wpa=3\n")
		io.write("wpa_key_mgmt=WPA-EAP\n")
		io.write("rsn_pairwise=CCMP\n")
	elseif iface.encryption == "sae" then
		io.write("auth_algs=1\n")
		io.write("wpa=2\n")
		io.write("wpa_key_mgmt=SAE\n")
		io.write("rsn_pairwise=CCMP\n")
	elseif iface.encryption == "sae-mixed" then
		io.write("auth_algs=1\n")
		io.write("wpa=2\n")
		io.write("wpa_key_mgmt=SAE WPA-PSK\n")
		io.write("rsn_pairwise=CCMP\n")
	elseif iface.encryption == "owe" then
		io.write("auth_algs=1\n")
		io.write("wpa=2\n")
		io.write("wpa_key_mgmt=OWE\n")
		io.write("rsn_pairwise=CCMP\n")
	end

	io.write("wmm_enabled=1\n")

	if iface.ieee80211w ~= nil then
		if tonumber(iface.ieee80211w) >= 0 and tonumber(iface.ieee80211w) <= 2 then
			io.write("ieee80211w=", iface.ieee80211w, "\n")
		end
	end

	local i
	if string.find(iface.encryption, "wep") ~= nil then
		io.write("wep_default_key=", iface.key)
		for i = 0, 3 do
			local key = iface['key'..tostring(i+1)]
			if key then
				local len = #key

				if (len == 10 or len == 26 or len == 32) and key == string.match(key, '%x+') then
					io.write("wep_key", tostring(i), "=", key)
				elseif (len == 5 or len == 13 or len == 16) then
					io.write("wep_key", tostring(i), "=\"", key, "\"")
				end
			else
				io.write("wep_key", tostring(i), "=")
			end
		end
	end

	if string.find(iface.encryption, "wpa") ~= nil or
	   string.find(iface.encryption, "psk") ~= nil or
	   string.find(iface.encryption, "sae") ~= nil then
		io.write("wpa_passphrase=", iface.key, "\n")
	end

	if iface.rekey_interval ~= nil then
		io.write("wpa_group_rekey=", tostring(iface.rekey_interval), "\n")
	end

	if iface.sae_pwe ~= nil and
	   tonumber(iface.sae_pwe) >= 0 and
	   tonumber(iface.sae_pwe) <= 2 then
		io.write("sae_pwe=2\n")
	end
-- TODO
	io.write("eapol_version=2\n")
	io.write("eap_server=1\n")
	io.write("eapol_key_index_workaround=0\n")
	io.write("wps_independent=1\n")
--
	if iface.wps_state ~= nil then
		io.write("wps_state=", iface.wps_state, "\n")
	end

	if iface.ieee8021x ~= nil and
	   iface.ieee8021x ~= '0' then
		io.write("ieee8021x=", tostring(iface.ieee8021x), "\n")
	end

	if iface.auth_server ~= nil and
	   iface.auth_server ~= '0' then
		io.write("auth_server_addr=", iface.auth_server, "\n")

		if iface.auth_port ~= nil and
		   iface.auth_port ~= '0' then
			io.write("auth_server_port=", iface.auth_server, "\n")
		end

		if iface.auth_secret ~= nil then
			io.write("auth_server_shared_secret=", iface.auth_secret, "\n")
		end
	end

	io.write("ctrl_interface=/var/run/hostapd\n")
	io.write("nas_identifier=ap.mtk.com\n")

	io.close()
end


function hostapd_enable_vif(phy, iface)
	local file_name = "/var/run/hostapd/hostapd-"..iface..".conf"

	os.execute("/usr/sbin/hostapd_cli -p /var/run/hostapd -i global raw ADD bss_config="..
		phy..":"..file_name)
end


function hostapd_disable_vif(iface)
	local file_name = "/var/run/hostapd/hostapd-"..iface..".conf"

	os.execute("/usr/sbin/hostapd_cli -p /var/run/hostapd -i global raw REMOVE "..iface)

	os.remove(file_name)
end
