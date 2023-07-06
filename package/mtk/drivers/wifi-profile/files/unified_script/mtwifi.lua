#!/usr/bin/lua
-- Alternative for OpenWrt's /sbin/wifi.
-- Copyright Not Reserved.
-- Hua Shao <nossiac@163.com>

package.path = '/lib/wifi/?.lua;'..package.path


local mtkdat = require("mtkdat")
local nixio = require("nixio")
local shuci = require("shuci")
local hostapd = require("hostapd")
local supplicant = require("supplicant")

local function esc(x)
   return (x:gsub('%%', '%%%%')
            :gsub('^%^', '%%^')
            :gsub('%$$', '%%$')
            :gsub('%(', '%%(')
            :gsub('%)', '%%)')
            :gsub('%.', '%%.')
            :gsub('%[', '%%[')
            :gsub('%]', '%%]')
            :gsub('%*', '%%*')
            :gsub('%+', '%%+')
            :gsub('%-', '%%-')
            :gsub('%?', '%%?'))
end

local function add_vif_into_lan(vif)
    nixio.syslog("debug", "add "..vif.." into lan")
--    os.execute("ubus call network.interface.lan add_device \"{\\\"name\\\":\\\""..vif.."\\\"}\"")
    os.execute("brctl addif br-lan "..vif.." 2> /dev/null")
    if mtkdat.exist("/proc/sys/net/ipv6/conf/"..vif.."/disable_ipv6") then
        os.execute("echo 1 > /proc/sys/net/ipv6/conf/"..vif.."/disable_ipv6")
    end
end

local function del_vif_from_lan(vif)
    nixio.syslog("debug", "del "..vif.." from lan")
    for _,brif in ipairs(string.split(mtkdat.read_pipe("ls /sys/class/net/br-lan/brif"), "\n")) do
        if brif == vif then
            if mtkdat.exist("/proc/sys/net/ipv6/conf/"..vif.."/disable_ipv6") then
                os.execute("echo 0 > /proc/sys/net/ipv6/conf/"..vif.."/disable_ipv6")
            end
            os.execute("brctl delif br-lan "..vif.." 2> /dev/null")
            return
        end
    end
end

local function uci_get_dev_by_dev_name(uci, devname)
    for _, dev in pairs(uci["wifi-device"]) do
        if dev[".name"] == devname then
            return dev
        end
    end
    return nil
end

local function uci_get_vifs_by_dev_name(uci, devname)
    local vifs = {}

    for vifname, vif in pairs(uci["wifi-iface"]) do
        if vif.device == devname then
            if tonumber(vif.vifidx) then
                vifs[tonumber(vif.vifidx)] = vif
            end
        end
    end

    for vifname, vif in pairs(uci["wifi-iface"]) do
        if vif.device == devname then
            if tonumber(vif.vifidx) == nil  then
                vifs[#vifs+1] = vif
            end
        end
    end

    return vifs
end


local function uci_get_vif_by_vif_name(uci, vifname)
    for _, vif in pairs(uci["wifi-iface"]) do
        if vif[".name"] == vifname then
            return vif
        end
    end
    return nil
end

function mtwifi_up(devname)
    local wifi_services_exist = false
    local l1profile = "/etc/wireless/l1profile.dat"
    local uci = shuci.decode("/etc/config/wireless")

    if devname then
        local profiles = mtkdat.search_dev_and_profile()
        local path = profiles[devname]
        if not mtkdat.exist("/tmp/mtk/wifi/"..string.match(path, "([^/]+)\.dat")..".last") then
            os.execute("cp -f "..path.." "..mtkdat.__profile_previous_settings_path(path))
        end
    end

    if mtkdat.cfg_is_diff() then
        mtkdat.uci2dat()
    end

    if  mtkdat.exist("/lib/wifi/wifi_services.lua") then
        wifi_services_exist = require("wifi_services")
    end

    nixio.syslog("debug", "mtwifi called!")

    local devs, l1parser = mtkdat.__get_l1dat()
    -- l1 profile present, good!
    if l1parser and devs then
        dev = devs.devname_ridx[devname]
        if not dev then
            nixio.syslog("err", "mtwifi: dev "..devname.." not found!")
            return
        end

        local devname2 = string.gsub(devname, "%.", "_")
        local uci_dev = uci_get_dev_by_dev_name(uci, devname2)
        local profile = mtkdat.search_dev_and_profile()[devname]
        local cfgs = mtkdat.load_profile(profile)
        -- we have to bring up main_ifname first, main_ifname will create all other vifs.
        if mtkdat.exist("/sys/class/net/"..dev.main_ifname) then
            nixio.syslog("debug", "mtwifi_up: ifconfig "..dev.main_ifname.." up")
            if not mtkdat.exist("/etc/init.d/wpad") then
                os.execute("ifconfig "..dev.main_ifname.." up")
                add_vif_into_lan(dev.main_ifname)
            else
                local uci_vif = uci_get_vif_by_vif_name(uci, dev.main_ifname)

                if uci_vif.disabled == nil or uci_vif.disabled ~= '1' then
                    if uci_vif.mode == "ap" then
                        hostapd_setup_vif(uci_dev, uci_vif)
                        hostapd_enable_vif(dev.main_ifname, uci_vif[".name"])
                    end
                end
            end
        else
            nixio.syslog("err", "mtwifi_up: main_ifname "..dev.main_ifname.." missing, quit!")
            return
        end
        for _,vif in ipairs(string.split(mtkdat.read_pipe("ls /sys/class/net"), "\n"))
        do
            if vif ~= dev.main_ifname then
                if string.match(vif, esc(dev.apcli_ifname).."[0-9]+") then
                    if not mtkdat.exist("/etc/init.d/wpad") then
                        nixio.syslog("debug", "mtwifi_up: ifconfig "..vif.." up")
                        os.execute("ifconfig "..vif.." up")
                        add_vif_into_lan(vif)
                    else
                        local uci_vif = uci_get_vif_by_vif_name(uci, vif)

                        if uci_vif.mode == "sta" then
                            supp_setup_vif(uci_dev, uci_vif)
                            supp_enable_vif(uci_vif[".name"])
                            if uci_vif.disabled ~= nil and uci_vif.disabled == '1' then
                                os.execute("ifconfig "..vif.." down")
                            end
                            add_vif_into_lan(vif)
                        end
                    end
                elseif (string.match(vif, esc(dev.wds_ifname).."[0-9]+") and
                        cfgs.WdsEnable ~= "0" and cfgs.WdsEnable ~= "") or
                       string.match(vif, esc(dev.mesh_ifname).."[0-9]+") then
                    nixio.syslog("debug", "mtwifi_up: ifconfig "..vif.." up")
                    os.execute("ifconfig "..vif.." up")
                    add_vif_into_lan(vif)
                end
            -- else nixio.syslog("debug", "mtwifi_up: skip "..vif..", prefix not match "..pre)
            end
        end
        if mtkdat.exist("/etc/init.d/wpad") then
            local uci_vifs = uci_get_vifs_by_dev_name(uci, devname2)
            for _, uci_vif in pairs(uci_vifs)
            do
                if uci_vif[".name"] ~= dev.main_ifname and
                   string.match(uci_vif[".name"], esc(dev.ext_ifname).."[0-9]+") then
                    if uci_vif.disabled == nil or uci_vif.disabled ~= '1' then
                        if uci_vif.mode == "ap" then
                            hostapd_setup_vif(uci_dev, uci_vif)
                            hostapd_enable_vif(dev.main_ifname, uci_vif[".name"])
                        end
                    end
                end
            end
        end
    else nixio.syslog("debug", "mtwifi_up: skip "..devname..", config(l1profile) not exist")
    end

    os.execute(" rm -rf /tmp/mtk/wifi/mtwifi*.need_reload")
end

local function get_vifs_by_phy(phyname)
    local devs={}

    for filename in io.popen("ls /sys/class/net"):lines() do
        local parent=io.open("/sys/class/net/"..filename.."/phy80211/name")
        if parent ~= nil then
            local name=parent:read "*a"

            if string.match(name, phyname) then
                table.insert(devs, filename)
            end
            io.close(parent)
        end
    end
    return devs
end

function mtwifi_down(devname)
    os.execute("echo wifi down > /dev/console")
    local wifi_services_exist = false
    if  mtkdat.exist("/lib/wifi/wifi_services.lua") then
        wifi_services_exist = require("wifi_services")
    end

    nixio.syslog("debug", "mtwifi_down called!")

    -- M.A.N service
    if mtkdat.exist("/etc/init.d/man") then
        os.execute("/etc/init.d/man stop")
    end


    local devs, l1parser = mtkdat.__get_l1dat()
    -- l1 profile present, good!
    if l1parser and devs then
        dev = devs.devname_ridx[devname]
        if not dev then
            nixio.syslog("err", "mtwifi_down: dev "..devname.." not found!")
            return
        end
        if not mtkdat.exist("/sys/class/net/"..dev.main_ifname) then
            nixio.syslog("err", "mtwifi_down: main_ifname "..dev.main_ifname.." missing, quit!")
            return
        end
        os.execute("mwctl "..dev.main_ifname.." set hw_nat_register=0")
        for _,vif in ipairs(string.split(mtkdat.read_pipe("ls /sys/class/net"), "\n"))
        do
            if vif == dev.main_ifname or
               string.match(vif, esc(dev.ext_ifname).."[0-9]+") then
                hostapd_disable_vif(vif)
                os.execute("ifconfig "..vif.." down")
                del_vif_from_lan(vif)
            elseif string.match(vif, esc(dev.apcli_ifname).."[0-9]+") then
                supp_disable_vif(vif)
                os.execute("ifconfig "..vif.." down")
                del_vif_from_lan(vif)
            elseif string.match(vif, esc(dev.wds_ifname).."[0-9]+") or
                   string.match(vif, esc(dev.mesh_ifname).."[0-9]+") then
                nixio.syslog("debug", "mtwifi_down: ifconfig "..vif.." down")
                os.execute("ifconfig "..vif.." down")
                del_vif_from_lan(vif)
            -- else nixio.syslog("debug", "mtwifi_down: skip "..vif..", prefix not match "..pre)
            end
        end
    else nixio.syslog("debug", "mtwifi_down: skip "..devname..", config not exist")
    end

    os.execute(" rm -rf /tmp/mtk/wifi/mtwifi*.need_reload")
end

function mtwifi_reload(devname)
    local normal_reload = true
    local qsetting = false
    local path, profiles
    local devs, l1parser = mtkdat.__get_l1dat()
    nixio.syslog("debug", "mtwifi_reload called!")

    if mtkdat.exist("/lib/wifi/quick_setting.lua") then
        qsetting = true
        profiles = mtkdat.search_dev_and_profile()
    end

    for devname, dev in mtkdat.spairs(devs.devname_ridx) do
        if qsetting then
            -- Create devname.last for quick setting
            path = profiles[devname]
            os.execute("cp -f "..path..
                " "..mtkdat.__profile_previous_settings_path(path))
        end
    end

    if mtkdat.cfg_is_diff() then
        mtkdat.uci2dat()
    end

    -- For one card , all interface should be down, then up
    if not devname then
        for devname, dev in pairs(devs.devname_ridx) do
                mtwifi_down(devname)
        end
        for devname, dev in mtkdat.spairs(devs.devname_ridx) do
            if qsetting then
                -- Create devname.last for quick setting
                path = profiles[devname]
                if not mtkdat.exist("/tmp/mtk/wifi/"..string.match(path, "([^/]+)\.dat")..".applied") then
                    os.execute("cp -f "..path.." "..mtkdat.__profile_applied_settings_path(path))
                else
                    os.execute("cp -f "..mtkdat.__profile_applied_settings_path(path)..
                        " "..mtkdat.__profile_previous_settings_path(path))
                end
            end
            mtwifi_up(devname)
        end
    else
        if qsetting then
            path = profiles[devname]
            normal_reload = quick_settings(devname, path)
        end

        if normal_reload then
            local dev = devs.devname_ridx[devname]
            --assert(exist(dev.init_script))
            local compatname = dev.init_compatible
            -- Different cards do not affect each other
            if not string.find(dev.profile_path, "dbdc") then
                if dev.init_compatible == compatname then
                    mtwifi_down(devname)
                    mtwifi_up(devname)
                end
            --If the reloaded device belongs to dbdc, then another device on dbdc also need to be reloaded
            else
                for devname, dev in pairs(devs.devname_ridx) do
                    if dev.init_compatible == compatname then mtwifi_down(devname) end
                end
                for devname, dev in mtkdat.__spairs(devs.devname_ridx) do
                    if dev.init_compatible == compatname then mtwifi_up(devname) end
                end
            end
        end
    end

    -- for ax7800 project, close the ra0.
    if string.find(dev.profile_path, "ax7800") then
        os.execute("ifconfig ra0 down")
    end
end

function mtwifi_restart(devname)
    local uci  = require "luci.model.uci".cursor()
    local devs, l1parser = mtkdat.__get_l1dat()

    if mtkdat.cfg_is_diff() then
        mtkdat.uci2dat()
    end

    local profiles = mtkdat.search_dev_and_profile()
    for devname, dev in mtkdat.spairs(devs.devname_ridx) do
        path = profiles[devname]
        os.execute("cp -f "..path..
            " "..mtkdat.__profile_previous_settings_path(path))
    end

    -- for AX8400 add 5G interface
    local isRoot = false
    if devname then
        local dev, path, diff
        local is7915 = false
        dev = devs.devname_ridx[devname]
        path = dev.profile_path
        if path then
            is7915 = string.find(path, "mt7915")
            diff =  mtkdat.diff_profile(path)
            if is7915 and diff.BssidNum then
                isRoot = true
            end
        end
    end

    nixio.syslog("debug", "mtwifi_restart called!")

    -- if wifi driver is built-in, it's necessary action to reboot the device
    if mtkdat.exist("/sys/module/mt_wifi") == false or isRoot then
        os.execute("echo reboot_required > /tmp/mtk/wifi/reboot_required")
        return
    end

    if devname then
        local dev = devs.devname_ridx[devname]
        --assert(mtkdat.exist(dev.init_script))
        local compatname = dev.init_compatible
        for devname, dev in pairs(devs.devname_ridx) do
            if dev.init_compatible == compatname then
                mtwifi_down(devname)
            end
        end
    else
         for devname, dev in pairs(devs.devname_ridx) do
             mtwifi_down(devname)
         end
    end
    os.execute("rmmod mt_whnat")
    os.execute("/etc/init.d/fwdd stop")
    os.execute("rmmod mtfwd")
    os.execute("rmmod mtk_warp_proxy")
    -- warp.ko actually no need to unload , due to sqc wifi restart may encounter the WO load fail
    -- keep the workaround until the warp / WO module init flow PASS in SQC env.
    -- os.execute("rmmod mtk_warp")
    -- mt7915_mt_wifi is for dual ko only
    os.execute("rmmod mt7915_mt_wifi")
    os.execute("rmmod mt_wifi")

    os.execute("modprobe mt_wifi")
    os.execute("modprobe mt7915_mt_wifi")
    -- os.execute("modprobe mtk_warp")
    os.execute("modprobe mtk_warp_proxy")
    os.execute("modprobe mtfwd")
    os.execute("/etc/init.d/fwdd start")
    os.execute("modprobe mt_whnat")
    if devname then
        local dev = devs.devname_ridx[devname]
        --assert(mtkdat.exist(dev.init_script))
        local compatname = dev.init_compatible
        for devname, dev in pairs(devs.devname_ridx) do
            if dev.init_compatible == compatname then
                mtwifi_up(devname)
            end
        end
    else
        for devname, dev in pairs(devs.devname_ridx) do
            mtwifi_up(devname)
        end
    end
end

function mtwifi_reset(devname)
    nixio.syslog("debug", "mtwifi_reset called!")
    if mtkdat.exist("/rom/etc/wireless/mediatek/") then
        os.execute("rm -rf /etc/wireless/mediatek/")
        os.execute("cp -rf /rom/etc/wireless/mediatek/ /etc/wireless/")
        if mtkdat.exist("/etc/config/wireless") then
            os.execute("rm -rf /etc/config/wireless")
            mtwifi_detect(devname)
        end
        mtwifi_reload(devname)
    else
        nixio.syslog("debug", "mtwifi_reset: /rom"..profile.." missing, unable to reset!")
    end
end

function mtwifi_status(devname)
    return wifi_common_status()
end

function mtwifi_hello(devname)
   os.execute("echo mtwifi_hello: "..devname)
end

function mtwifi_detect(devname)
    nixio.syslog("debug", "mtwifi_detect")
    mtkdat.dat2uci()
end

function mtwifi_save(devname)
    mtkdat.uci2dat()
end

