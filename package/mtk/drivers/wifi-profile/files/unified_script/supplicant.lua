#!/usr/bin/env lua


function supp_setup_vif(dev, iface)
	local file_name = "/var/run/wpa_supplicant/wpa_supplicant-"..iface[".name"]..".conf"
	local file

	file = io.open(file_name, "w+")

	io.output(file)
	io.write("ctrl_interface=/var/run/wpa_supplicant\n\n")
	if iface.ssid == nil or iface.ssid == "" then
		io.close()
		return
	end
	io.write("network={\n")
	io.write("\tssid=\""..iface.ssid.."\"\n")

	if iface.encryption == "none" or
		iface.encryption == nil then
		io.write("\tkey_mgmt=NONE\n")
	elseif iface.encryption == "psk+tkip+ccmp" then
		io.write("\tkey_mgmt=WPA-PSK\n")
		io.write("\tproto=WPA\n")
		io.write("\tpsk=\""..iface.key.."\"\n")
		io.write("\tpairwise=CCMP TKIP\n")
		io.write("\tgroup=CCMP TKIP\n")
	elseif iface.encryption == "psk+tkip" then
		io.write("\tkey_mgmt=WPA-PSK\n")
		io.write("\tproto=WPA\n")
		io.write("\tpsk=\""..iface.key.."\"\n")
		io.write("\tpairwise=TKIP\n")
		io.write("\tgroup=TKIP\n")
	elseif iface.encryption == "psk+ccmp" then
		io.write("\tkey_mgmt=WPA-PSK\n")
		io.write("\tproto=WPA\n")
		io.write("\tpsk=\""..iface.key.."\"\n")
		io.write("\tpairwise=CCMP\n")
		io.write("\tgroup=CCMP\n")
	elseif iface.encryption == "psk2+tkip+ccmp" then
		io.write("\tkey_mgmt=WPA-PSK\n")
		io.write("\tproto=RSN\n")
		io.write("\tpsk=\""..iface.key.."\"\n")
		io.write("\tpairwise=CCMP TKIP\n")
		io.write("\tgroup=CCMP TKIP\n")
	elseif iface.encryption == "psk2+tkip" then
		io.write("\tkey_mgmt=WPA-PSK\n")
		io.write("\tproto=RSN\n")
		io.write("\tpsk=\""..iface.key.."\"\n")
		io.write("\tpairwise=TKIP\n")
		io.write("\tgroup=TKIP\n")
	elseif iface.encryption == "psk2+ccmp" then
		io.write("\tkey_mgmt=WPA-PSK\n")
		io.write("\tproto=RSN\n")
		io.write("\tpsk=\""..iface.key.."\"\n")
		io.write("\tpairwise=CCMP\n")
		io.write("\tgroup=CCMP\n")
	elseif iface.encryption == "psk2-mixed+tkip+ccmp" then
		io.write("\tkey_mgmt=WPA-PSK\n")
		io.write("\tproto=WPA RSN\n")
		io.write("\tpsk=\""..iface.key.."\"\n")
		io.write("\tpairwise=CCMP TKIP\n")
		io.write("\tgroup=CCMP TKIP\n")
	elseif iface.encryption == "psk2-mixed+tkip" then
		io.write("\tkey_mgmt=WPA-PSK\n")
		io.write("\tproto=WPA RSN\n")
		io.write("\tpsk=\""..iface.key.."\"\n")
		io.write("\tpairwise=TKIP\n")
		io.write("\tgroup=TKIP\n")
	elseif iface.encryption == "psk2-mixed+ccmp" then
		io.write("\tkey_mgmt=WPA-PSK\n")
		io.write("\tproto=WPA RSN\n")
		io.write("\tpsk=\""..iface.key.."\"\n")
		io.write("\tpairwise=CCMP\n")
		io.write("\tgroup=CCMP\n")
	elseif iface.encryption == "psk-mixed+tkip+ccmp" then
		io.write("\tkey_mgmt=WPA-PSK\n")
		io.write("\tproto=RSN\n")
		io.write("\tpsk=\""..iface.key.."\"\n")
		io.write("\tpairwise=CCMP TKIP\n")
		io.write("\tgroup=CCMP TKIP\n")
	elseif iface.encryption == "sae" then
		io.write("\tkey_mgmt=SAE\n")
		io.write("\tproto=RSN\n")
		if iface.sae_password then
			io.write("\tsae_password=\""..iface.key.."\"\n")
		else
			io.write("\tpsk=\""..iface.key.."\"\n")
		end
		io.write("\tpairwise=CCMP\n")
		io.write("\tgroup=CCMP\n")
	elseif iface.encryption == "sae-mixed" then
		io.write("\tkey_mgmt=WPA-PSK SAE\n")
		io.write("\tproto=RSN\n")
		if iface.sae_password then
			io.write("\tsae_password=\""..iface.key.."\"\n")
		else
			io.write("\tpsk=\""..iface.key.."\"\n")
		end
		io.write("\tpairwise=CCMP\n")
		io.write("\tgroup=CCMP\n")
	elseif iface.encryption == "owe" then
		io.write("\tkey_mgmt=OWE\n")
		io.write("\tproto=RSN\n")
	elseif iface.encryption == "wep" or
	       iface.encryption == "wep+open" then
		io.write("\tkey_mgmt=NONE\n")
		io.write("\tauth_alg=OPEN\n")
	elseif iface.encryption == "wep+shared" then
		io.write("\tkey_mgmt=NONE\n")
		io.write("\tauth_alg=SHARED\n")
	elseif iface.encryption == "wep+auto" then
		io.write("\tkey_mgmt=NONE\n")
	end

	if string.find(iface.encryption, "wep") ~= nil then
		for i = 1, 4 do
			key = iface['key'..tostring(i)]
			if key and key ~= '' then
				io.write("\twep_key"..tostring(i).."=\""..key.."\"\n")
			end
		end
		if iface.key ~= nil then
			io.write("\twep_tx_keyidx=0\n")
		else
			io.write("\twep_tx_keyidx="..iface.key.."\n")
		end
	end



	io.write("}\n")

	io.close()
end

function supp_enable_vif(iface)
	local file_name = "/var/run/wpa_supplicant/wpa_supplicant-"..iface..".conf"

	os.execute("/usr/sbin/wpa_cli -p /var/run/wpa_supplicant -i global interface_add "..iface.." "..file_name)
end

function supp_disable_vif(iface)
	local file_name = "/var/run/wpa_supplicant/wpa_supplicant-"..iface..".conf"

	os.execute("/usr/sbin/wpa_cli -p /var/run/wpa_supplicant -i global interface_remove "..iface)

	os.remove(file_name)
end
