#!/usr/bin/env lua

--[[
 * A lua library for mtk's wifi driver.
 *
 * Copyright (C) 2019 MediaTek Inc. All Rights Reserved.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License version 2.1
 * as published by the Free Software Foundation
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
]]


require("datconf")
--local ioctl_help = require "ioctl_helper"
local mtkdat = {}
local nixio = require("nixio")

local uciCfgfile = "/etc/config/wireless"
local lastCfgfile = "/tmp/mtk/wifi/wireless.last"


local l1dat_parser = {
    L1_DAT_PATH = "/etc/wireless/l1profile.dat",
    IF_RINDEX = "ifname_ridx",
    DEV_RINDEX = "devname_ridx",
    MAX_NUM_APCLI = 1,
    MAX_NUM_WDS = 4,
    MAX_NUM_MESH = 1,
    MAX_NUM_EXTIF = 16,
    MAX_NUM_DBDC_BAND = 2,
}

local l1cfg_options = {
            ext_ifname="",
            apcli_ifname="apcli",
            wds_ifname="wds",
            mesh_ifname="mesh"
      }


--util functions
local function __cfg2list(str)
    -- delimeter == ";"
    local i = 1
    local list = {}
    if str == nil then return list end
    for k in string.gmatch(str, "([^;]+)") do
        list[i] = k
        i = i + 1
    end
    return list
end

local function __split(s, delimiter)
    if s == nil then s = "" end
    local result = {};
    for match in (s..delimiter):gmatch("(.-)"..delimiter) do
        table.insert(result, match);
    end
    return result;
end

function mtkdat.exist(path)
    if path == nil then return false end
    local fp = io.open(path, "rb")
    if fp then fp:close() end
    return fp ~= nil
end

function mtkdat.trim(s)
  if s then return (s:gsub("^%s*(.-)%s*$", "%1")) end
end

local function token_set(str, n, v)
    -- n start from 1
    -- delimeter == ";"
    if not str then str = "" end
    if not v then v = "" end
    local tmp = __cfg2list(str)
    if type(v) ~= type("") and type(v) ~= type(0) then
        return
    end
    if #tmp < tonumber(n) then
        for i=#tmp, tonumber(n) do
            if not tmp[i] then
                tmp[i] = v -- pad holes with v !
            end
        end
    else
        tmp[n] = v
    end
    return table.concat(tmp, ";"):gsub("^;*(.-);*$", "%1"):gsub(";+",";")
end


local function token_get(str, n, v)
    -- n starts from 1
    -- v is the backup in case token n is nil
    if not str then return v end
    local tmp = __cfg2list(str)
    return tmp[tonumber(n)] or v
end

local function __lines(str)
    local t = {}
    local function helper(line) table.insert(t, line) return "" end
    helper((str:gsub("(.-)\r?\n", helper)))
    return t
end

function string:split(sep)
    local sep, fields = sep or ":", {}
    local pattern = string.format("([^%s]+)", sep)
    self:gsub(pattern, function(c) fields[#fields+1] = c end)
    return fields
end

function mtkdat.spairs(t, order)
    -- collect the keys
    local keys = {}
    for k in pairs(t) do keys[#keys+1] = k end
    table.sort(keys, order)
    -- return the iterator function
    local i = 0
    return function()
        i = i + 1
        if keys[i] then
            return keys[i], t[keys[i]]
        end
    end
end

local function mode2band(mode)
    local i = tonumber(mode)
    if i == 0 or
       i == 1 or
       i == 4 or
       i == 6 or
       i == 7 or
       i == 9 or
       i == 16 or
       i == 22 then
        return "2.4G"
    elseif i == 2 or
           i == 3 or
           i == 5 or
           i == 8 or
           i == 10 or
           i == 11 or
           i == 12 or
           i == 13 or
           i == 14 or
           i == 15 or
           i == 17 or
           i == 23 then
	return "5G"
    elseif i == 18 or
           i == 19 or
           i == 20 or
           i == 21 or
           i == 24 or
           i == 25 or
           i == 26 or
           i == 27 then
        return "6G"
    end
end

function mtkdat.read_pipe(pipe)
    local retry_count = 10
    local fp, txt, err
    repeat  -- fp:read() may return error, "Interrupted system call", and can be recovered by doing it again
        fp = io.popen(pipe)
        txt, err = fp:read("*a")
        fp:close()
        retry_count = retry_count - 1
    until err == nil or retry_count == 0
    return txt
end

local function table_clone(org)
    local copy = {}
    for k, v in pairs(org) do
        copy[k] = v
    end
    return copy
end

local function set_dat_cfg(datfile, cfg, val)
    datobj = datconf.openfile(datfile)
    if datobj then
        datobj:set(cfg, val)
        datobj:commit()
        datobj:close()
    end
end

local function get_dat_cfg(datfile, cfg)
    local val
    datobj = datconf.openfile(datfile)
    if datobj then
        val = datobj:get(cfg)
        datobj:close()
    end

    return val
end

local function get_file_lines(fileName)
    local fd = io.open(fileName, "r")
    if not fd then return end
    local content = fd:read("*all")
    fd:close()
    return __lines(content)
end

local function write_file_lines(fileName, lines)
    local fd = io.open(fileName, "w")
    if not fd then return end
    for _, line in pairs(lines) do
        fd:write(line..'\n')
    end
    fd:close()
end

local function file_is_diff(file1, file2)
    local l1 = get_file_lines(file1)
    local l2 = get_file_lines(file2)

    if (#l1 ~= #l2) then return true end

    for k, v in pairs(l1) do
        if (l1[k] ~= l2[k]) then
            return true
        end
    end

    return false
end

key = ""
local function print_table(table , level)
  level = level or 1
  local indent = ""
  for i = 1, level do
    indent = indent.."  "
  end

  if key ~= "" then
    --print(indent..key.." ".."=".." ".."{")
    print(key.." ".."=".." ".."{")
  else
    --print(indent .. "{")
    print("{")
  end

  key = ""
  for k,v in pairs(table) do
     if type(v) == "table" then
        key = k
        print_table(v, level + 1)
     else
        local content = string.format("%s%s = %s", indent .. "  ",tostring(k), tostring(v))
      print(content)
      end
  end
  print(indent .. "}")

end


local function add_default_value(l1cfg)
    for k, v in ipairs(l1cfg) do

        for opt, default in pairs(l1cfg_options) do
            if ( opt == "ext_ifname" ) then
                v[opt] = v[opt] or v["main_ifname"].."_"
            else
                v[opt] = v[opt] or default..k.."_"
            end
        end
    end

    return l1cfg
end

local function get_value_by_idx(devidx, mainidx, subidx, key)
    --print("Enter get_value_by_idx("..devidx..","..mainidx..", "..subidx..", "..key..")<br>")
    if not devidx or not mainidx or not key then return end

    local devs = load_l1_profile(l1dat_parser.L1_DAT_PATH)
    if not devs then return end

    local dev_ridx = l1dat_parser.DEV_RINDEX
    local sidx = subidx or 1
    local devname1  = devidx.."."..mainidx
    local devname2  = devidx.."."..mainidx.."."..sidx

    --print("devnam1=", devname1, "devname2=", devname2, "<br>")
    return devs[dev_ridx][devname2] and devs[dev_ridx][devname2][key]
           or devs[dev_ridx][devname1] and devs[dev_ridx][devname1][key]
end

-- path to zone is 1 to 1 mapping
local function l1_path_to_zone(path)
    --print("Enter l1_path_to_zone("..path..")<br>")
    if not path then return end

    local devs = load_l1_profile(l1dat_parser.L1_DAT_PATH)
    if not devs then return end

    for _, dev in pairs(devs[l1dat_parser.IF_RINDEX]) do
        if dev.profile_path == path then
            return dev.nvram_zone
        end
    end

    return
end

-- zone to path is 1 to n mapping
local function l1_zone_to_path(zone)
    if not zone then return end

    local devs = load_l1_profile(l1dat_parser.L1_DAT_PATH)
    if not devs then return end

    local plist = {}
    for _, dev in pairs(devs[l1dat_parser.IF_RINDEX]) do
        if dev.nvram_zone == zone then
            if not next(plist) then
                table.insert(plist,dev.profile_path)
            else
                local plist_str = table.concat(plist)
                if not plist_str:match(dev.profile_path) then
                    table.insert(plist,dev.profile_path)
                end
            end
        end
    end

    return next(plist) and plist or nil
end

local function l1_ifname_to_datpath(ifname)
    if not ifname then return end

    local devs = load_l1_profile(l1dat_parser.L1_DAT_PATH)
    if not devs then return end

    local ridx = l1dat_parser.IF_RINDEX
    return devs[ridx][ifname] and devs[ridx][ifname].profile_path
end

local function l1_ifname_to_zone(ifname)
    if not ifname then return end

    local devs = load_l1_profile(l1dat_parser.L1_DAT_PATH)
    if not devs then return end

    local ridx = l1dat_parser.IF_RINDEX
    return devs[ridx][ifname] and devs[ridx][ifname].nvram_zone
end

local function l1_zone_to_ifname(zone)
    if not zone then return end

    local devs = load_l1_profile(l1dat_parser.L1_DAT_PATH)
    if not devs then return end

    local zone_dev
    for _, dev in pairs(devs[l1dat_parser.DEV_RINDEX]) do
        if dev.nvram_zone == zone then
            zone_dev = dev
        end
    end

    if not zone_dev  then
        return nil
    else
        return zone_dev.main_ifname, zone_dev.ext_ifname, zone_dev.apcli_ifname, zone_dev.wds_ifname, zone_dev.mesh_ifname
    end
end


-- input: L1 profile path.
-- output A table, devs, contains
--   1. devs[%d] = table of each INDEX# in the L1 profile
--   2. devs.ifname_ridx[ifname]
--         = table of each ifname and point to relevant contain in dev[$d]
--   3. devs.devname_ridx[devname] similar to devs.ifnameridx, but use devname.
--      devname = INDEX#_value.mainidx(.subidx)
-- Using *_ridx do not need to handle name=k1;k2 case of DBDC card.
local function load_l1_profile(path)
    local devs = setmetatable({}, {__index=
                     function(tbl, key)
                           local util = require("luci.util")
                           --print("metatable function:", util.serialize_data(tbl), key)
                           --print("-----------------------------------------------")
                           if ( string.match(key, "^%d+")) then
                               tbl[key] = {}
                               return tbl[key]
                           end
                     end
                 })
    local chipset_num = {}
    local dir = io.popen("ls /etc/wireless/")
    if not dir then return end
    local fd = io.open(path, "r")
    if not fd then return end

    -- convert l1 profile into lua table
    for line in fd:lines() do
        line = mtkdat.trim(line)
        if string.byte(line) ~= string.byte("#") then
            local i = string.find(line, "=")
            if i then
                local k, v, k1, k2
                k = mtkdat.trim( string.sub(line, 1, i-1) )
                v = mtkdat.trim( string.sub(line, i+1) )
                k1, k2 = string.match(k, "INDEX(%d+)_(.+)")
                if k1 then
                    k1 = tonumber(k1) + 1
                    if devs[k1][k2] then
                        nixio.syslog("warning", "skip repeated key"..line)
                    end
                    devs[k1][k2] = v or ""
                else
                    k1 = string.match(k, "INDEX(%d+)")
                    k1 = tonumber(k1) + 1
                    devs[k1]["INDEX"] = v

                    chipset_num[v] = (not chipset_num[v] and 1) or chipset_num[v] + 1
                    devs[k1]["mainidx"] = chipset_num[v]
                end
            else
                nixio.syslog("warning", "skip line without '=' "..line)
            end
        else
            nixio.syslog("warning", "skip comment line "..line)
        end
    end

    add_default_value(devs)
    --local util = require("luci.util")
    --local seen2 = {}
    -- print("Before setup ridx", util.serialize_data(devs, seen2))

    -- Force to setup reverse indice for quick search.
    -- Benifit:
    --   1. O(1) search with ifname, devname
    --   2. Seperate DBDC name=k1;k2 format in the L1 profile into each
    --      ifname, devname.
    local dbdc_if = {}
    local ridx = l1dat_parser.IF_RINDEX
    local dridx = l1dat_parser.DEV_RINDEX
    local band_num = l1dat_parser.MAX_NUM_DBDC_BAND
    local k, v, dev, i , j, last
    local devname
    devs[ridx] = {}
    devs[dridx] = {}
    for _, dev in ipairs(devs) do
        dbdc_if[band_num] = token_get(dev.main_ifname, band_num, nil)
        if dbdc_if[band_num] then
            for i = 1, band_num - 1 do
                dbdc_if[i] = token_get(dev.main_ifname, i, nil)
            end
            for i = 1, band_num do
                devs[ridx][dbdc_if[i]] = {}
                devs[ridx][dbdc_if[i]]["subidx"] = i

                for k, v in pairs(dev) do
                    if  k == "INDEX" or k == "EEPROM_offset" or k == "EEPROM_size"
                       or k == "mainidx" then
                        devs[ridx][dbdc_if[i]][k] = v
                    else
                        devs[ridx][dbdc_if[i]][k] = token_get(v, i, "")
                    end
                end
                devname = dev.INDEX.."."..dev.mainidx.."."..devs[ridx][dbdc_if[i]]["subidx"]
                devs[dridx][devname] = devs[ridx][dbdc_if[i]]
            end

            local apcli_if, wds_if, ext_if, mesh_if = {}, {}, {}, {}

            for i = 1, band_num do
                ext_if[i] = token_get(dev.ext_ifname, i, nil)
                apcli_if[i] = token_get(dev.apcli_ifname, i, nil)
                wds_if[i] = token_get(dev.wds_ifname, i, nil)
                mesh_if[i] = token_get(dev.mesh_ifname, i, nil)
            end

            for i = 1, l1dat_parser.MAX_NUM_EXTIF - 1 do -- ifname idx is from 0
                for j = 1, band_num do
                    devs[ridx][ext_if[j]..i] = devs[ridx][dbdc_if[j]]
                end
            end

            for i = 0, l1dat_parser.MAX_NUM_APCLI - 1 do
                for j = 1, band_num do
                    devs[ridx][apcli_if[j]..i] = devs[ridx][dbdc_if[j]]
                end
            end

            for i = 0, l1dat_parser.MAX_NUM_WDS - 1 do
                for j = 1, band_num do
                    devs[ridx][wds_if[j]..i] = devs[ridx][dbdc_if[j]]
                end
            end

            for i = 0, l1dat_parser.MAX_NUM_MESH - 1 do
                for j = 1, band_num do
                    if mesh_if[j] then
                        devs[ridx][mesh_if[j]..i] = devs[ridx][dbdc_if[j]]
                    end
                end
            end

        else
            devs[ridx][dev.main_ifname] = dev

            devname = dev.INDEX.."."..dev.mainidx
            devs[dridx][devname] = dev

            for i = 1, l1dat_parser.MAX_NUM_EXTIF - 1 do  -- ifname idx is from 0
                devs[ridx][dev.ext_ifname..i] = dev
            end

            for i = 0, l1dat_parser.MAX_NUM_APCLI - 1 do  -- ifname idx is from 0
                devs[ridx][dev.apcli_ifname..i] = dev
            end

            for i = 0, l1dat_parser.MAX_NUM_WDS - 1 do  -- ifname idx is from 0
                devs[ridx][dev.wds_ifname..i] = dev
            end

            for i = 0, l1dat_parser.MAX_NUM_MESH - 1 do  -- ifname idx is from 0
                devs[ridx][dev.mesh_ifname..i] = dev
            end
        end
    end

    fd:close()
    return devs
end



function mtkdat.create_link_for_nvram( )
    local devs = load_l1_profile(l1dat_parser.L1_DAT_PATH)
    for devname, dev in pairs(devs.devname_ridx) do
        local dev = devs.devname_ridx[devname]
        profile = dev.profile_path
        if not mtkdat.exist("/tmp/mtk/wifi") then
            os.execute("mkdir -p /tmp/mtk/wifi/")
        end
        if dev.nvram_zone == "dev1" then
            os.execute("ln -sf " ..profile.." /tmp/mtk/wifi/2860")
        elseif dev.nvram_zone == "dev2" then
            os.execute("ln -sf " ..profile.." /tmp/mtk/wifi/rtdev")
        elseif dev.nvram_zone == "dev3" then
            os.execute("ln -sf " ..profile.." /tmp/mtk/wifi/wifi3")
        end
    end
end


local function get_table_length(T)
    local count = 0
    for _ in pairs(T) do
        count = count + 1
    end
    return count
end



function mtkdat.__get_l1dat()
    l1dat = load_l1_profile(l1dat_parser.L1_DAT_PATH)

    return l1dat, l1dat_parser
end

function mtkdat.deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[mtkdat.deepcopy(orig_key)] = mtkdat.deepcopy(orig_value)
        end
        setmetatable(copy, mtkdat.deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end


function mtkdat.detect_first_card()
    local profiles = mtkdat.search_dev_and_profile()
    for _, profile in mtkdat.spairs(profiles, function(a,b) return string.upper(a) < string.upper(b) end) do
        return profile
    end
end

function mtkdat.load_profile(path, raw)
    local cfgs = {}

    cfgobj = datconf.openfile(path)
    if cfgobj then
        cfgs = cfgobj:getall()
        cfgobj:close()
    elseif raw then
        cfgs = datconf.parse(raw)
    end

    return cfgs
end


local function save_easymesh_profile_to_nvram()
    if not pcall(require, "mtknvram") then
        return
    end
    local nvram = require("mtknvram")
    local merged_easymesh_dev1_path = "/tmp/mtk/wifi/merged_easymesh_dev1.dat"
    local l1dat = load_l1_profile(l1dat_parser.L1_DAT_PATH)
    local dev1_profile_paths
    local dev1_profile_path_table = l1_zone_to_path("dev1")
    if not next(dev1_profile_path_table) then
        return
    end
    dev1_profile_paths = table.concat(dev1_profile_path_table, " ")
    -- Uncomment below two statements when there is sufficient space in dev1 NVRAM zone to store EasyMesh Agent's BSS Cfgs Settings.
    -- mtkdat.__prepare_easymesh_bss_nvram_cfgs()
    -- os.execute("cat "..dev1_profile_paths.." "..mtkdat.__read_easymesh_profile_path().." "..mtkdat.__easymesh_bss_cfgs_nvram_path().." > "..merged_easymesh_dev1_path.." 2>/dev/null")
    -- Comment or remove below line once above requirement is met.
    os.execute("cat "..dev1_profile_paths.." "..mtkdat.__read_easymesh_profile_path().." > "..merged_easymesh_dev1_path.." 2>/dev/null")
    nvram.nvram_save_profile(merged_easymesh_dev1_path, "dev1")
end

function mtkdat.save_profile(cfgs, path)

    if not cfgs then
        nixio.syslog("err", "configuration was empty, nothing saved")
        return
    end

    -- Keep a backup of last profile settings
    -- if string.match(path, "([^/]+)\.dat") then
       -- os.execute("cp -f "..path.." "..mtkdat.__profile_previous_settings_path(path))
    -- end
    local datobj = datconf.openfile(path)
    datobj:merge(cfgs)
    datobj:close(true) -- means close and commit

    if pcall(require, "mtknvram") then
        local nvram = require("mtknvram")
        local l1dat = load_l1_profile(l1dat_parser.L1_DAT_PATH)
        local zone = l1_path_to_zone(path)

        if pcall(require, "map_helper") and zone == "dev1" then
            save_easymesh_profile_to_nvram()
        else
            if not l1dat then
                nixio.syslog("debug", "save_profile: no l1dat")
                nvram.nvram_save_profile(path)
            else
                if zone then
                    nixio.syslog("debug", "save_profile "..path.." "..zone)
                    nvram.nvram_save_profile(path, zone)
                else
                    nixio.syslog("debug", "save_profile "..path)
                    nvram.nvram_save_profile(path)
                end
            end
        end
    end
end



-- update path1 by path2
local function update_profile(path1, path2)
    local cfg1 = datconf.openfile(path1)
    local cfg2 = datconf.openfile(path2)

    cfg1:merge(cfg2:getall())
    cfg1:close(true)
    cfg2:close()
end


function mtkdat.__profile_previous_settings_path(profile)
    assert(type(profile) == "string")
    local bak = "/tmp/mtk/wifi/"..string.match(profile, "([^/]+)\.dat")..".last"
    if not mtkdat.exist("/tmp/mtk/wifi") then
        os.execute("mkdir -p /tmp/mtk/wifi")
    end
    return bak
end

function mtkdat.__profile_applied_settings_path(profile)
    assert(type(profile) == "string")
    local bak

    if not mtkdat.exist("/tmp/mtk/wifi") then
        os.execute("mkdir -p /tmp/mtk/wifi")
    end

    if string.match(profile, "([^/]+)\.dat") then
        bak = "/tmp/mtk/wifi/"..string.match(profile, "([^/]+)\.dat")..".applied"
    elseif string.match(profile, "([^/]+)\.txt") then
        bak = "/tmp/mtk/wifi/"..string.match(profile, "([^/]+)\.txt")..".applied"
    elseif string.match(profile, "([^/]+)$") then
        bak = "/tmp/mtk/wifi/"..string.match(profile, "([^/]+)$")..".applied"
    else
        bak = ""
    end

    return bak
end

-- if path2 is not given, use backup of path1.
function mtkdat.diff_profile(path1, path2)
    assert(path1)
    if not path2 then
        path2 = mtkdat.__profile_applied_settings_path(path1)
        if not mtkdat.exist(path2) then
            return {}
        end
    end
    assert(path2)

    local cfg1
    local cfg2
    local diff = {}
    if path1 == mtkdat.__easymesh_bss_cfgs_path() then
        cfg1 = get_file_lines(path1) or {}
        cfg2 = get_file_lines(path2) or {}
    else
        cfg1 = mtkdat.load_profile(path1) or {}
        cfg2 = mtkdat.load_profile(path2) or {}
    end

    for k,v in pairs(cfg1) do
        if cfg2[k] ~= cfg1[k] then
            diff[k] = {cfg1[k] or "", cfg2[k] or ""}
        end
    end

    for k,v in pairs(cfg2) do
        if cfg2[k] ~= cfg1[k] then
            diff[k] = {cfg1[k] or "", cfg2[k] or ""}
        end
    end

    return diff
end

local function diff_config(cfg1, cfg2)
    local diff = {}

    for k,v in pairs(cfg1) do
        if cfg2[k] ~= v and not (cfg2[k] == nil and v == '') then
            diff[k] = v
        end
    end

    return diff
end


local function search_dev_and_profile_orig()
    local nixio = require("nixio")
    local dir = io.popen("ls /etc/wireless/")
    if not dir then return end
    local result = {}
    -- case 1: mt76xx.dat (best)
    -- case 2: mt76xx.n.dat (multiple card of same dev)
    -- case 3: mt76xx.n.nG.dat (case 2 plus dbdc and multi-profile, bloody hell....)
    for line in dir:lines() do
        -- nixio.syslog("debug", "scan "..line)
        local tmp = io.popen("find /etc/wireless/"..line.." -type f -name \"*.dat\"")
        for datfile in tmp:lines() do
            -- nixio.syslog("debug", "test "..datfile)

            repeat do
            -- for case 1
            local devname = string.match(datfile, "("..line..").dat")
            if devname then
                result[devname] = datfile
                -- nixio.syslog("debug", "yes "..devname.."="..datfile)
                break
            end
            -- for case 2
            local devname = string.match(datfile, "("..line.."%.%d)%.dat")
            if devname then
                result[devname] = datfile
                -- nixio.syslog("debug", "yes "..devname.."="..datfile)
                break
            end
            -- for case 3
            local devname = string.match(datfile, "("..line.."%.%d%.%dG)%.dat")
            if devname then
                result[devname] = datfile
                -- nixio.syslog("debug", "yes "..devname.."="..datfile)
                break
            end
            end until true
        end
    end

    for k,v in pairs(result) do
        nixio.syslog("debug", "search_dev_and_profile_orig: "..k.."="..v)
    end

    return result
end

local function search_dev_and_profile_l1()
    local l1dat = load_l1_profile(l1dat_parser.L1_DAT_PATH)

    if not l1dat then return end

    local nixio = require("nixio")
    local result = {}
    local dbdc_2nd_if = ""

    for k, dev in ipairs(l1dat) do
        dbdc_2nd_if = token_get(dev.main_ifname, 2, nil)
        if dbdc_2nd_if then
            result[dev["INDEX"].."."..dev["mainidx"]..".1"] = token_get(dev.profile_path, 1, nil)
            result[dev["INDEX"].."."..dev["mainidx"]..".2"] = token_get(dev.profile_path, 2, nil)
        else
            result[dev["INDEX"].."."..dev["mainidx"]] = dev.profile_path
        end
    end

    for k,v in pairs(result) do
        nixio.syslog("debug", "search_dev_and_profile_l1: "..k.."="..v)
    end

    return result
end

function mtkdat.search_dev_and_profile()
    return search_dev_and_profile_l1() or search_dev_and_profile_orig()
end

function mtkdat.__read_easymesh_profile_path()
    return "/etc/map/mapd_cfg"
end

function mtkdat.__write_easymesh_profile_path()
    return "/etc/map/mapd_user.cfg"
end

function mtkdat.__easymesh_mapd_profile_path()
    return "/etc/mapd_strng.conf"
end

function mtkdat.__easymesh_bss_cfgs_path()
    return "/etc/map/wts_bss_info_config"
end

function mtkdat.__easymesh_bss_cfgs_nvram_path()
    local p = "/tmp/mtk/wifi/wts_bss_info_config.nvram"
    if not mtkdat.exist("/tmp/mtk/wifi") then
        os.execute("mkdir -p /tmp/mtk/wifi")
    end
    return p
end

local function get_vifs_by_dev(ucicfg, devname)
    local vifs = {}

    for vifname, vif in pairs(ucicfg["wifi-iface"]) do
        if vif.device == devname and vif.mode == 'ap' then
            if tonumber(vif.vifidx) then
                vifs[tonumber(vif.vifidx)] = vif
            end
        end
    end

    for vifname, vif in pairs(ucicfg["wifi-iface"]) do
        if vif.device == devname and vif.mode == 'ap' then
            if tonumber(vif.vifidx) == nil  then
                vifs[#vifs+1] = vif
            end
        end
    end

    return vifs
end

local function get_iface_prefix(ifname)
    assert(ifname ~= nil)
    local prefix
    local i  = string.find(ifname, "%d+")
    if i ~= nil then
        prefix = string.sub(ifname, 0, i-1)
        i = string.sub(ifname, i, -1)
        i = tonumber(i)
    end

    return prefix, i
end

local uci_dev_options = {
    "type", "vendor", "txpower", "channel", "channel_grp", "autoch", "beacon_int",
    "txpreamble", "dtim_period", "band", "bw", "ht_extcha", "ht_txstream", "ht_rxstream",
    "shortslot", "ht_distkip", "bgprotect", "txburst", "region", "country", "aregion",
    "vht_bw_sig", "pktaggregate", "ht_mcs", "e2p_accessmode", "map_mode", "dbdc_mode",
    "etxbfencond", "itxbfen", "mutxrx_enable", "bss_color", "colocated_bssid",
    "twt_support", "individual_twt_support", "he_ldpc", "txop", "ieee80211h", "dfs_enable",
    "sre_enable", "powerup_enbale", "powerup_cckofdm", "powerup_ht20", "powerup_ht40", "powerup_vht20",
    "powerup_vht40", "powerup_vht80", "powerup_vht160", "vow_airtime_fairness_en",
    "ht_badec", "ht_rdg", "ht_bawinsize", "whnat", "vow_bw_ctrl", "vow_ex_en"
}

local uci_iface_options = {
    "device", "network", "mode", "disabled", "ssid", "bssid", "network", "vifidx", "hidden", "wmm",
    "encryption", "key", "key1", "key2", "key3", "key4", "rekey_interval", "rekey_meth",
    "ieee8021x", "auth_server", "auth_port", "auth_secret", "ownip", "idle_timeout", "session_timeout",
    "preauth", "ieee80211w", "pmf_sha256", "wireless_mode", "mldgroup", "tx_rate", "no_forwarding",
    "rts_threshold", "frag_threshold", "apsd_capable", "vht_bw_signal", "vht_ldpc", "vht_stbc", "vht_sgi",
    "ht_ldpc", "ht_stbc","ht_protect", "ht_gi", "ht_opmode", "ht_amsdu", "ht_autoba",
    "igmpsn_enable", "mumimoul_enable", "mumimodl_enable", "muofdmaul_enable", "muofdmadl_enable",
    "vow_group_max_ratio", "vow_group_min_ratio", "vow_airtime_ctrl_en", "vow_group_max_rate", "vow_group_min_rate",
    "vow_rate_ctrl_en", "pmk_cache_period", "wds", "wdslist", "wds0key", "wds1key", "wds2key", "wds3key",
    "wdsencryptype", "wdsphymode", "wps_state", "wps_pin",  "owetrante", "mac_repeateren", "access_policy", "access_list",
}

local function uci_encode_options(fp, uci_options, cfg_type, tbl)
    fp:write(string.format("config\t%s\t'%s'\n", cfg_type, tbl[".name"]))

    for _, i in pairs(uci_options) do
        if (tbl[i] ~= nil) then
            if type(tbl[i]) == "table" then
                for _, v in pairs(tbl[i]) do
                     fp:write(string.format("\tlist\t%s\t'%s'\n",i,v))
                end
            elseif tbl[i] ~= '' then
                fp:write(string.format("\toption\t%-10s\t'%s'\n", i, tostring(tbl[i])))
            end
        end
    end
    fp:write("\n")
end

local function uci_encode_dev_options(fp, dev)
    uci_encode_options(fp, uci_dev_options, "wifi-device", dev)
end

local function uci_encode_iface_options(fp, iface)
    uci_encode_options(fp, uci_iface_options, "wifi-iface", iface)
end

local function dat2uci_encryption(auth, encr)
    local encryption

    if auth == "OPEN" and encr == "NONE" then
        encryption = "none"
    elseif auth == "OPEN" and encr == "WEP" then
        encryption = "wep-open"
    elseif auth == "SHARED" and encr == "WEP" then
        encryption = "wep-shared"
    elseif auth == "WEPAUTO" and encr == "WEP" then
        encryption = "wep-auto"
    elseif auth == "WPA" and encr == "TKIP" then
        encryption = "wpa+tkip"
    elseif auth == "WPA" and encr == "TKIPAES" then
        encryption = "wpa+tkip+ccmp"
    elseif auth == "WPA" and encr == "AES" then
        encryption = "wpa+ccmp"
    elseif auth == "WPA2" and encr == "TKIP" then
        encryption = "wpa2+tkip"
    elseif auth == "WPA2" and encr == "TKIPAES" then
        encryption = "wpa2+tkip+ccmp"
    elseif auth == "WPA2" and encr == "AES" then
        encryption = "wpa2+ccmp"
    elseif auth == "WPA3" and encr == "AES" then
        encryption = "wpa3"
    elseif auth == "WPA3-192" and encr == "GCMP256"  then
        encryption = "wpa3-192"
    elseif auth == "WPAPSK" and encr == "AES" then
        encryption = "psk+ccmp"
    elseif auth == "WPAPSK" and encr == "TKIP" then
        encryption = "psk+tkip"
    elseif auth == "WPAPSK" and encr == "TKIPAES" then
        encryption = "psk+tkip+ccmp"
    elseif auth == "WPA2PSK" and encr == "AES" then
        encryption = "psk2+ccmp"
    elseif auth == "WPA2PSK" and encr == "TKIP" then
        encryption = "psk2+tkip"
    elseif auth == "WPA2PSK" and encr == "TKIPAES" then
        encryption = "psk2+tkip+ccmp"
    elseif auth == "WPA3PSK" and encr == "AES" then
        encryption = "sae"
    elseif auth == "WPAPSKWPA2PSK" and encr == "TKIP" then
        encryption = "psk-mixed+tkip"
    elseif auth == "WPAPSKWPA2PSK" and encr == "TKIPAES" then
        encryption = "psk-mixed+tkip+ccmp"
    elseif auth == "WPAPSKWPA2PSK" and encr == "AES" then
        encryption = "psk-mixed+ccmp"
    elseif auth == "WPA2PSKWPA3PSK" and encr == "AES" then
        encryption = "sae-mixed"
    elseif auth == "WPA1WPA2" and encr == "TKIP" then
        encryption = "wpa-mixed+tkip"
    elseif auth == "WPA1WPA2" and encr == "AES" then
        encryption = "wpa-mixed+ccmp"
    elseif auth == "WPA1WPA2" and encr == "TKIPAES" then
        encryption = "wpa-mixed+tkip+ccmp"
    elseif auth == "WPA3WPA2" then
        encryption = "wpa3-mixed"
    elseif auth == "OWE" and encr == "AES" then
        encryption = "owe"
    else
        encryption = "none"
    end

    return encryption
end

local function uci2dat_encryption(encryption)
    local auth
    local encr

    if encryption == "none" then
        auth = "OPEN"
        encr = "NONE"
    elseif encryption == "wep-open" then
        auth = "OPEN"
        encr = "WEP"
    elseif encryption == "wep-shared" then
        auth = "SHARED"
        encr = "WEP"
    elseif encryption == "wep-auto" then
        auth = "WEPAUTO"
        encr = "WEP"
    elseif encryption == "wpa+tkip" then
        auth = "WPA"
        encr = "TKIP"
    elseif encryption == "wpa+tkip+ccmp" then
        auth = "WPA"
        encr = "TKIPAES"
    elseif encryption == "wpa+ccmp" then
        auth = "WPA"
        encr = "AES"
    elseif encryption == "wpa2+tkip" then
        auth = "WPA2"
        encr = "TKIP"
    elseif encryption == "wpa2+tkip+ccmp" then
        auth = "WPA2"
        encr = "TKIPAES"
    elseif encryption == "wpa2+ccmp" then
        auth = "WPA2"
        encr = "AES"
    elseif encryption == "wpa3" then
        auth = "WPA3"
        encr = "AES"
    elseif encryption == "wpa3-192" then
        auth = "WPA3-192"
        encr = "GCMP256"
    elseif encryption == "psk+ccmp" then
        auth = "WPAPSK"
        encr = "AES"
    elseif encryption == "psk+tkip" then
        auth = "WPAPSK"
        encr = "TKIP"
    elseif encryption == "psk+tkip+ccmp" then
        auth = "WPAPSK"
        encr = "TKIPAES"
    elseif encryption == "psk2+ccmp" then
        auth = "WPA2PSK"
        encr = "AES"
    elseif encryption == "psk2+tkip" then
        auth = "WPA2PSK"
        encr = "TKIP"
    elseif encryption == "psk2+tkip+ccmp" then
        auth = "WPA2PSK"
        encr = "TKIPAES"
    elseif encryption == "sae" then
        auth = "WPA3PSK"
        encr = "AES"
    elseif encryption == "psk-mixed+tkip" then
        auth = "WPAPSKWPA2PSK"
        encr = "TKIP"
    elseif encryption == "psk-mixed+tkip+ccmp" then
        auth = "WPAPSKWPA2PSK"
        encr = "TKIPAES"
    elseif encryption == "psk-mixed+ccmp" then
        auth = "WPAPSKWPA2PSK"
        encr = "AES"
    elseif encryption == "sae-mixed" then
        auth = "WPA2PSKWPA3PSK"
        encr = "AES"
    elseif encryption == "wpa-mixed+tkip" then
        auth = "WPA1WPA2"
        encr = "TKIP"
    elseif encryption == "wpa-mixed+ccmp" then
        auth = "WPA1WPA2"
        encr = "AES"
    elseif encryption == "wpa-mixed+tkip+ccmp" then
        auth = "WPA1WPA2"
        encr = "TKIPAES"
    elseif encryption == "wpa3-mixed" then
        auth = "WPA3WPA2"
        encr = "AES"
    elseif encryption == "owe" then
        auth = "OWE"
        encr = "AES"
    else
        auth = "OPEN"
        encr = "NONE"
    end

    return auth, encr
end


local function cfg2dev(cfg, devname, dev)
    assert(cfg ~= nil)
    assert(dev ~= nil)

    dev[".name"] = string.gsub(devname, "%.", "_")
    dev.type = "mtkwifi"
    dev.vendor = "mediatek"
    dev.txpower = cfg.TxPower
    dev.channel = cfg.Channel
    dev.channel_grp = cfg.ChannelGrp
    dev.autoch = cfg.AutoChannelSelect
    dev.beacon_int = cfg.BeaconPeriod
    dev.txpreamble = cfg.TxPreamble
    dev.dtim_period = cfg.DtimPeriod

    if cfg.HT_BW == "1" then
        if cfg.VHT_BW == "0" or not cfg.VHT_BW then
            if cfg.HT_BSSCoexistence == '0' or not cfg.HT_BSSCoexistence then
                dev.bw = "40"
            else
                dev.bw = "60"
            end
        elseif cfg.VHT_BW == "1" then
            dev.bw = "80"
        elseif cfg.VHT_BW == "2" then
            if cfg.EHT_ApBw == '3' then
                dev.bw = "160"
            elseif cfg.EHT_ApBw == '4' then
                dev.bw = "320"
            end
        elseif cfg.VHT_BW == "3" then
            dev.bw = "161"
        end
    else
        dev.bw = "20"
    end

    dev.vht_sec80_channel = cfg.VHT_Sec80_Channel
    dev.ht_extcha = cfg.HT_EXTCHA
    dev.ht_txstream = cfg.HT_TxStream
    dev.ht_rxstream = cfg.HT_RxStream
    dev.shortslot = cfg.ShortSlot
    dev.ht_distkip = cfg.HT_DisallowTKIP
    dev.bgprotect = cfg.BGProtection
    dev.txburst = cfg.TxBurst

    dev.band = mode2band(string.split(cfg.WirelessMode,";")[1])

    if dev.band == "2.4G" then
        dev.region = cfg.CountryRegion
    else
        dev.aregion = cfg.CountryRegionABand
    end

    dev.pktaggregate = cfg.PktAggregate
    dev.country = cfg.CountryCode
    dev.ht_mcs = cfg.HT_MCS
    dev.e2p_accessmode = cfg.E2pAccessMode
    dev.map_mode = cfg.MapMode
    dev.dbdc_mode = cfg.DBDC_MODE
    dev.etxbfencond = cfg.ETxBfEnCond
    dev.itxbfen = cfg.ITxBfEn
    dev.mutxrx_enable = cfg.MUTxRxEnable
    dev.bss_color = cfg.BSSColorValue
    dev.colocated_bssid = cfg.CoLocatedBSSID
    dev.twt_support = cfg.TWTSupport
    dev.individual_twt_support = cfg.IndividualTWTSupport
    dev.he_ldpc = cfg.HE_LDPC
    dev.txop = cfg.TxOP
    dev.ieee80211h = cfg.IEEE80211H
    dev.dfs_enable = cfg.DfsEnable
    dev.sre_enable = cfg.SREnable
    dev.powerup_enbale = cfg.PowerUpenable
    dev.powerup_cckofdm = cfg.PowerUpCckOfdm
    dev.powerup_ht20 = cfg.PowerUpHT20
    dev.powerup_ht40 = cfg.PowerUpHT40
    dev.powerup_vht20 = cfg.PowerUpVHT20
    dev.powerup_vht40 = cfg.PowerUpVHT40
    dev.powerup_vht80 = cfg.PowerUpVHT80
    dev.powerup_vht160 = cfg.PowerUpVHT160

    dev.vow_airtime_fairness_en = cfg.VOW_Airtime_Fairness_En
    dev.ht_badec = cfg.HT_BADecline
    dev.ht_rdg = cfg.HT_RDG
    dev.ht_bawinsize = cfg.HT_BAWinSize
    dev.whnat = cfg.WHNAT
    dev.e2p_accessmode = cfg.E2pAccessMode
    dev.vow_bw_ctrl = cfg.VOW_BW_Ctrl
    dev.vow_ex_en = cfg.VOW_RX_En

    return dev
end

local function cfg2iface(cfg, devname, ifname, iface, i)
    assert(cfg ~= nil)
    assert(iface ~= nil)

    local encr_list = cfg.EncrypType:split()
    local auth_list = cfg.AuthMode:split()
    encr_list = encr_list[1]:split(";")
    auth_list = auth_list[1]:split(";")

    iface[".name"] = ifname
    iface.device = devname
    --print("ifname:"..iface[".name"])
    iface.network = "lan"
    iface.mode = "ap"
    iface.disabled = "0"
    iface.ssid = cfg["SSID"..tostring(i)]
    iface.network = "lan"
    iface.vifidx = i
    iface.hidden = token_get(cfg.HideSSID, i, __split(cfg.HideSSID,";")[1])
    iface.wmm = token_get(cfg.WmmCapable, i, __split(cfg.WmmCapable,";")[1])

    iface.encryption = dat2uci_encryption(auth_list[i], encr_list[i])
    iface.key = ""
    if encr_list[i] == "WEP" then
        iface.key = token_get(cfg.DefaultKeyID, i, __split(cfg.DefaultKeyID,";")[1])
    elseif auth_list[i] == "WPA2PSK" or auth_list[i] == "WPA3PSK" or
        auth_list[i] == "WPAPSKWPA2PSK" or auth_list[i] == "WPA2PSKWPA3PSK" then
        iface.key = cfg["WPAPSK"..tostring(i)]
    end

    local j
    for j = 1, 4 do
        iface["key"..tostring(j)] = cfg["Key"..tostring(j).."Str"..tostring(i)] or ''
    end

    iface.rekey_interval = token_get(cfg.RekeyInterval, i, __split(cfg.RekeyInterval,";")[1])
    iface.rekey_meth = token_get(cfg.RekeyMethod, i, __split(cfg.RekeyMethod,";")[1])
    iface.pmk_cache_period = token_get(cfg.PMKCachePeriod, i, __split(cfg.PMKCachePeriod ,";")[1])

    iface.ieee8021x = token_get(cfg.IEEE8021X, i, __split(cfg.IEEE8021X,";")[1])
    iface.auth_server = token_get(cfg.RADIUS_Server, i)
    iface.auth_port = token_get(cfg.RADIUS_Port, i)
    iface.auth_secret = cfg["RADIUS_Key"..tostring(i)]
    iface.ownip =  cfg.own_ip_addr
    iface.idle_timeout = cfg.idle_timeout_interval
    iface.session_timeout = token_get(cfg.session_timeout_interval, i, __split(cfg.session_timeout_interval,";")[1])
    iface.preauth = token_get(cfg.PreAuth, i, __split(cfg.PreAuth,";")[1])

    local pmfmfpc = token_get(cfg.PMFMFPC, i, __split(cfg.PMFMFPC,";")[1])
    local pmfmfpr = token_get(cfg.PMFMFPR, i, __split(cfg.PMFMFPR,";")[1])

    if pmfmfpc == '1' and pmfmfpr == '1' then
        iface.ieee80211w = '2'
    elseif pmfmfpc == '1' then
        iface.ieee80211w = '1'
    else
        iface.ieee80211w = '0'
    end

    iface.pmf_sha256 = token_get(cfg.PMFSHA256, i, __split(cfg.PMFSHA256,";")[1])

    iface.wireless_mode = token_get(cfg.WirelessMode, i, __split(cfg.WirelessMode,";")[1])
    iface.mldgroup = token_get(cfg.MldGroup, i, "")
    iface.tx_rate = token_get(cfg.TxRate, i, __split(cfg.TxRate,";")[1])
    if iface.tx_rate == '' then iface.tx_rate = tostring(0) end
    iface.no_forwarding = token_get(cfg.NoForwarding , i, __split(cfg.NoForwarding ,";")[1])
    iface.rts_threshold = token_get(cfg.RTSThreshold, i, __split(cfg.RTSThreshold,";")[1])
    iface.frag_threshold = token_get(cfg.FragThreshold, i, __split(cfg.FragThreshold,";")[1])
    iface.apsd_capable = token_get(cfg.APSDCapable, i, __split(cfg.APSDCapable,";")[1])
    iface.vht_bw_signal = token_get(cfg.VHT_BW_SIGNAL, i, __split(cfg.VHT_BW_SIGNAL,";")[1])
    iface.vht_ldpc = token_get(cfg.VHT_LDPC, i, __split(cfg.VHT_LDPC,";")[1])
    iface.vht_stbc = token_get(cfg.VHT_STBC, i, __split(cfg.VHT_STBC,";")[1])
    iface.vht_sgi = token_get(cfg.VHT_SGI, i, __split(cfg.VHT_SGI,";")[1])
    iface.ht_ldpc = token_get(cfg.HT_LDPC, i, __split(cfg.HT_LDPC,";")[1])
    iface.ht_stbc = token_get(cfg.HT_STBC, i, __split(cfg.HT_STBC,";")[1])
    iface.ht_protect = token_get(cfg.HT_PROTECT, i, __split(cfg.HT_PROTECT,";")[1])
    iface.ht_gi = token_get(cfg.HT_GI , i, __split(cfg.HT_GI ,";")[1])
    iface.ht_opmode = token_get(cfg.HT_OpMode , i, __split(cfg.HT_OpMode ,";")[1])
    iface.ht_amsdu = token_get(cfg.HT_AMSDU, i, __split(cfg.HT_AMSDU,";")[1])
    iface.ht_autoba = token_get(cfg.HT_AutoBA , i, __split(cfg.HT_AutoBA ,";")[1])
    iface.igmpsn_enable = token_get(cfg.IgmpSnEnable, i, __split(cfg.IgmpSnEnable,";")[1])

    iface.mumimoul_enable = token_get(cfg.MuMimoUlEnable, i, __split(cfg.MuMimoUlEnable,";")[1])
    iface.mumimodl_enable = token_get(cfg.MuMimoDlEnable, i, __split(cfg.MuMimoDlEnable,";")[1])
    iface.muofdmaul_enable = token_get(cfg.MuOfdmaUlEnable, i, __split(cfg.MuOfdmaUlEnable,";")[1])
    iface.muofdmadl_enable = token_get(cfg.MuOfdmaDlEnable, i, __split(cfg.MuOfdmaDlEnable,";")[1])
    iface.vow_group_max_ratio = token_get(cfg.VOW_Group_Max_Ratio, i, __split(cfg.VOW_Group_Max_Ratio,";")[1])
    iface.vow_group_min_ratio = token_get(cfg.VOW_Group_Min_Ratio, i, __split(cfg.VOW_Group_Min_Ratio,";")[1])
    iface.vow_airtime_ctrl_en = token_get(cfg.VOW_Airtime_Ctrl_En, i, __split(cfg.VOW_Airtime_Ctrl_En,";")[1])
    iface.vow_group_max_rate = token_get(cfg.VOW_Group_Max_Rate , i, __split(cfg.VOW_Group_Max_Rate ,";")[1])
    iface.vow_group_min_rate = token_get(cfg.VOW_Group_Min_Rate, i, __split(cfg.VOW_Group_Min_Rate,";")[1])
    iface.vow_rate_ctrl_en = token_get(cfg.VOW_Rate_Ctrl_En, i, __split(cfg.VOW_Rate_Ctrl_En,";")[1])

    iface.wds = token_get(cfg.WdsEnable, i, __split(cfg.WdsEnable,";")[1])
    iface.wdslist = cfg.WdsList
    iface.wds0key = cfg.Wds0Key
    iface.wds1key = cfg.Wds1Key
    iface.wds2key = cfg.Wds2Key
    iface.wds3key = cfg.Wds3Key
    iface.wdsencryptype = cfg.WdsEncrypType
    iface.wdsphymode = cfg.WdsPhyMode

    local wsc_confmode, wsc_confstatus
    wsc_confmode = token_get(cfg.WscConfMode, i, __split(cfg.WscConfMode,";")[1])
    wsc_confmode = tonumber(wsc_confmode)
    wsc_confstatus = token_get(cfg.WscConfStatus, i, __split(cfg.WscConfStatus,";")[1])
    wsc_confstatus = tonumber(wsc_confstatus)

    iface.wps_state = ''
    if wsc_confmode and wsc_confmode ~= 0 then
        if wsc_confstatus == 1 then
            iface.wps_state = '1'
        elseif wsc_confstatus == 2 then
            iface.wps_state = '2'
        end
    end

    iface.wps_pin = token_get(cfg.WscVendorPinCode, i, __split(cfg.WscVendorPinCode,";")[1])

    iface.access_policy = cfg["AccessPolicy"..tostring(i-1)]
    iface.access_list = __cfg2list(cfg["AccessControlList"..tostring(i-1)])

    return iface
end

local function cfg2apcli(cfg, devname, ifname, iface)
    assert(cfg ~= nil)
    assert(iface ~= nil)

    iface[".name"] = ifname
    iface.device = devname
    iface.mode = "sta"
    if cfg.ApCliEnable == "1" then
        iface.disabled = "0"
    else
        iface.disabled = "1"
    end

    iface.ssid = cfg.ApCliSsid
    iface.bssid = cfg.ApCliBssid

    iface.encryption = dat2uci_encryption(cfg.ApCliAuthMode, cfg.ApCliEncrypType)

    iface.key = ""
    if cfg.ApCliEncrypType == "WEP" then
        iface.key = cfg.ApCliDefaultKeyID
    elseif cfg.ApCliAuthMode == "WPA2PSK" or cfg.ApCliAuthMode == "WPA3PSK" or
        cfg.ApCliAuthMode == "WPAPSKWPA2PSK" or cfg.ApCliAuthMode == "WPA2PSKWPA3PSK" then
        iface.key = cfg.ApCliWPAPSK
    end

    if cfg.ApCliPMFMFPC == '1' and cfg.ApCliPMFMFPR == '1' then
        iface.ieee80211w = '2'
    elseif cfg.ApCliPMFMFPC == '1' then
        iface.ieee80211w = '1'
    else
        iface.ieee80211w = '0'
    end

    iface.pmf_sha256 = cfg.ApCliPMFSHA256
    iface.owetrante = cfg.ApCliOWETranIe
    iface.mac_repeateren = cfg.MACRepeaterEn

    local j
    for j = 1, 4 do
        iface["key"..tostring(j)] = cfg["ApCliKey"..tostring(j).."Str"] or ''
    end

    iface.wps_pin = ''

    return iface
end

local function dev2cfg(dev, cfg)
    assert(dev ~= nil)
    assert(cfg ~= nil)

    cfg.TxPower = dev.txpower
    cfg.Channel = dev.channel
    cfg.ChannelGrp = dev.channel_grp
    cfg.AutoChannelSelect = dev.autoch
    cfg.BeaconPeriod = dev.beacon_int
    cfg.TxPreamble = dev.txpreamble
    cfg.DtimPeriod = dev.dtim_period
    cfg.Band = dev.band

    if dev.bw == "20" then
        cfg.HT_BW = "0"
        cfg.VHT_BW = "0"
        cfg.EHT_ApBw = '0'
    else
        cfg.HT_BW = "1"
        if dev.bw == "40" then
            cfg.VHT_BW = "0"
            cfg.EHT_ApBw = '1'
            cfg.HT_BSSCoexistence = '0'
        elseif dev.bw == "60" then
            cfg.VHT_BW = "0"
            cfg.HT_BSSCoexistence = '1'
        elseif dev.bw == "80" then
            cfg.VHT_BW = "1"
            cfg.EHT_ApBw = '2'
        elseif dev.bw == "160" then
            cfg.VHT_BW = "2"
            cfg.EHT_ApBw = '3'
        elseif dev.bw == "161" then
            cfg.VHT_BW = "3"
            cfg.VHT_Sec80_Channel = dev.vht_sec80_channel
        elseif dev.bw == "320" then
            cfg.VHT_BW = "2"
            cfg.EHT_ApBw = '4'
        end
    end

    cfg.HT_EXTCHA = dev.ht_extcha
    cfg.HT_TxStream = dev.ht_txstream
    cfg.HT_RxStream = dev.ht_rxstream
    cfg.ShortSlot = dev.shortslot
    cfg.HT_DisallowTKIP = dev.ht_distkip
    cfg.BGProtection = dev.bgprotect
    cfg.TxBurst = dev.txburst

    if dev.band == "2.4G" then
        cfg.CountryRegion = dev.region
    else
        cfg.CountryRegionABand = dev.aregion
    end

    cfg.PktAggregate = dev.pktaggregate
    cfg.CountryCode = dev.country
    cfg.HT_MCS = dev.ht_mcs
    cfg.E2pAccessMode = dev.e2p_accessmode
    cfg.MapMode = dev.map_mode
    cfg.DBDC_MODE = dev.dbdc_mode
    cfg.ETxBfEnCond = dev.etxbfencond
    cfg.ITxBfEn = dev.itxbfen
    cfg.MUTxRxEnable = dev.mutxrx_enable
    cfg.BSSColorValue = dev.bss_color
    cfg.CoLocatedBSSID = dev.colocated_bssid
    cfg.TWTSupport = dev.twt_support
    cfg.IndividualTWTSupport = dev.individual_twt_support
    cfg.HE_LDPC = dev.he_ldpc
    cfg.TxOP = dev.txop
    cfg.IEEE80211H = dev.ieee80211h
    cfg.DfsEnable = dev.dfs_enable
    cfg.SREnable = dev.sre_enable
    cfg.PowerUpenable = dev.powerup_enbale
    cfg.PowerUpCckOfdm = dev.powerup_cckofdm
    cfg.PowerUpHT20 = dev.powerup_ht20
    cfg.PowerUpHT40 = dev.powerup_ht40
    cfg.PowerUpVHT20 = dev.powerup_vht20
    cfg.PowerUpVHT40 = dev.powerup_vht40
    cfg.PowerUpVHT80 = dev.powerup_vht80
    cfg.PowerUpVHT160 = dev.powerup_vht160

    cfg.VOW_Airtime_Fairness_En = dev.vow_airtime_fairness_en
    cfg.HT_BADecline = dev.ht_badec
    cfg.HT_RDG = dev.ht_rdg
    cfg.HT_BAWinSize = dev.ht_bawinsize
    cfg.WHNAT = dev.whnat
    cfg.E2pAccessMode = dev.e2p_accessmode
    cfg.VOW_BW_Ctrl = dev.vow_bw_ctrl
    cfg.VOW_RX_En = dev.vow_ex_en

    return cfg
end

local function iface2cfg(iface, i, cfg)
    assert(iface ~= nil)
    assert(cfg ~= nil)

    local encr, auth

    cfg["SSID"..tostring(i)] = iface.ssid
    cfg.HideSSID = token_set(cfg.HideSSID, i, iface.hidden)
    cfg.WmmCapable = token_set(cfg.WmmCapable, i, iface.wmm)

    auth, encr = uci2dat_encryption(iface.encryption)

    cfg.AuthMode = token_set(cfg.AuthMode, i, auth)
    cfg.EncrypType = token_set(cfg.EncrypType, i, encr)

    if encr == "WEP" then
        cfg.DefaultKeyID = token_set(cfg.DefaultKeyID, i, iface.key)
    elseif auth == "WPA2PSK" or auth == "WPA3PSK" or
        auth == "WPAPSKWPA2PSK" or auth == "WPA2PSKWPA3PSK" then
        cfg["WPAPSK"..tostring(i)] = iface.key
    end

    local j
    for j = 1, 4 do
        local k = iface["key"..tostring(j)]
        if k then
            local len = #k
            if (len == 10 or len == 26 or len == 32) and k == string.match(k, '%x+') then
                cfg["Key"..tostring(j).."Type"] = token_set(cfg["Key"..tostring(j).."Type"], i, 0)
                cfg["Key"..tostring(j).."Str"..tostring(i)] = k
            elseif (len == 5 or len == 13 or len == 16) then
                cfg["Key"..tostring(j).."Type"] = token_set(cfg["Key"..tostring(j).."Type"], i, 1)
                cfg["Key"..tostring(j).."Str"..tostring(i)] = k
            end
        end
    end

    cfg.RekeyInterval = token_set(cfg.RekeyInterval, i, iface.rekey_interval)
    cfg.RekeyMethod = token_set(cfg.RekeyMethod, i, iface.rekey_meth)
    cfg.PMKCachePeriod = token_set(cfg.PMKCachePeriod, i, iface.pmk_cache_period )

    cfg.IEEE8021X = token_set(cfg.IEEE8021X, i, iface.ieee8021x)
    cfg.RADIUS_Server = token_set(cfg.RADIUS_Server, i, iface.auth_server)
    cfg.RADIUS_Port = token_set(cfg.RADIUS_Port, i, iface.auth_port)
    cfg["RADIUS_Key"..tostring(i)] = iface.auth_secret
    cfg.own_ip_addr = iface.ownip
    cfg.idle_timeout_interval = iface.idle_timeout
    cfg.session_timeout_interval = token_set(cfg.session_timeout_interval, i, iface.session_timeout)
    cfg.PreAuth = token_set(cfg.PreAuth, i, iface.preauth)

    if iface.ieee80211w == '2' then
        cfg.PMFMFPC = token_set(cfg.PMFMFPC, i, '1')
        cfg.PMFMFPR = token_set(cfg.PMFMFPR, i, '1')
    elseif iface.ieee80211w == '1' then
        cfg.PMFMFPC = token_set(cfg.PMFMFPC, i, '1')
        cfg.PMFMFPR = token_set(cfg.PMFMFPR, i, '0')
    elseif iface.ieee80211w == '0' then
        cfg.PMFMFPC = token_set(cfg.PMFMFPC, i, '0')
        cfg.PMFMFPR = token_set(cfg.PMFMFPR, i, '0')
    end

    cfg.PMFSHA256 = token_set(cfg.PMFSHA256, i, iface.pmf_sha256)

    cfg.WirelessMode = token_set(cfg.WirelessMode, i, iface.wireless_mode)
    cfg.MldGroup = token_set(cfg.MldGroup, i, iface.mldgroup)
    cfg.TxRate = token_set(cfg.TxRate, i, iface.tx_rate)
    cfg.NoForwarding = token_set(cfg.NoForwarding, i, iface.no_forwarding)
    cfg.VHT_BW_SIGNAL = token_set(cfg.VHT_BW_SIGNAL, i, iface.vht_bw_signal)
    cfg.VHT_SGI = token_set(cfg.VHT_SGI, i, iface.vht_sgi)
    cfg.RTSThreshold = token_set(cfg.RTSThreshold, i, iface.rts_threshold)
    cfg.FragThreshold = token_set(cfg.FragThreshold, i, iface.frag_threshold)
    cfg.APSDCapable = token_set(cfg.APSDCapable, i, iface.apsd_capable)
    cfg.VHT_LDPC = token_set(cfg.VHT_LDPC, i, iface.vht_ldpc)
    cfg.VHT_STBC = token_set(cfg.VHT_STBC, i, iface.vht_stbc)
    cfg.HT_LDPC = token_set(cfg.HT_STBC, i, iface.ht_ldpc)
    cfg.HT_STBC = token_set(cfg.HT_STBC, i, iface.ht_stbc)
    cfg.HT_PROTECT = token_set(cfg.HT_PROTECT, i, iface.ht_protect)
    cfg.HT_GI = token_set(cfg.HT_GI, i, iface.ht_gi)
    cfg.HT_OpMode = token_set(cfg.HT_OpMode, i, iface.ht_opmode)
    cfg.HT_AMSDU = token_set(cfg.HT_AMSDU, i, iface.ht_amsdu)
    cfg.HT_AutoBA = token_set(cfg.HT_AutoBA, i, iface.ht_autoba)
    cfg.IgmpSnEnable = token_set(cfg.IgmpSnEnable, i, iface.igmpsn_enable)

    cfg.MuMimoUlEnable = token_set(cfg.MuMimoUlEnable, i, iface.mumimoul_enable)
    cfg.MuMimoDlEnable = token_set(cfg.MuMimoDlEnable, i, iface.mumimodl_enable)
    cfg.MuOfdmaUlEnable = token_set(cfg.MuOfdmaUlEnable, i, iface.muofdmaul_enable)
    cfg.MuOfdmaDlEnable = token_set(cfg.MuOfdmaDlEnable, i, iface.muofdmadl_enable)
    cfg.VOW_Group_Max_Ratio = token_set(cfg.VOW_Group_Max_Ratio, i, iface.vow_group_max_ratio)
    cfg.VOW_Group_Min_Ratio = token_set(cfg.VOW_Group_Min_Ratio, i, iface.vow_group_min_ratio)
    cfg.VOW_Airtime_Ctrl_En = token_set(cfg.VOW_Airtime_Ctrl_En, i, iface.vow_airtime_ctrl_en)
    cfg.VOW_Group_Max_Rate = token_set(cfg.VOW_Group_Max_Rate , i, iface.vow_group_max_rate)
    cfg.VOW_Group_Min_Rate = token_set(cfg.VOW_Group_Min_Rate, i, iface.vow_group_min_rate)
    cfg.VOW_Rate_Ctrl_En = token_set(cfg.VOW_Rate_Ctrl_En, i, iface.vow_rate_ctrl_en)

    cfg.WdsEnable = token_set(cfg.WdsEnable, i, iface.wds)
    cfg.WdsList = iface.wdslist
    cfg.Wds0Key = iface.wds0key
    cfg.Wds1Key = iface.wds1key
    cfg.Wds2Key = iface.wds2key
    cfg.Wds3Key = iface.wds3key
    cfg.WdsEncrypType = iface.wdsencryptype
    cfg.WdsPhyMode = iface.wdsphymode

    local wsc_confmode, wsc_confstatus

    if iface.wps_state == '1' then
        wsc_confmode = '7'
        wsc_confstatus = '1'
    elseif iface.wps_state == '2' then
        wsc_confmode = '7'
        wsc_confstatus = '2'
    else
        wsc_confmode = '0'
        wsc_confstatus = '1'
    end

    cfg.WscConfMode = token_set(cfg.WscConfMode, i, wsc_confmode)
    cfg.WscConfStatus = token_set(cfg.WscConfStatus, i, wsc_confstatus)
    cfg.WscVendorPinCode = token_set(cfg.WscVendorPinCode, i, iface.wps_pin)

    cfg["AccessPolicy"..tostring(i-1)] = iface.access_policy
    if iface.access_list ~= nil then
        for j, v in pairs(iface.access_list) do
            cfg["AccessControlList"..tostring(i-1)] = token_set(cfg["AccessControlList"..tostring(i-1)], j, v)
        end
    end

    return cfg
end

local function apcli2cfg(iface, cfg)
    if iface.disabled == nil or tonumber(iface.disabled) == 0 then
        cfg.ApCliEnable = "1"
    else
        cfg.ApCliEnable = "0"
    end

    cfg.ApCliSsid = iface.ssid
    cfg.ApCliBssid = iface.bssid

    auth, encr = uci2dat_encryption(iface.encryption)
    cfg.ApCliAuthMode = auth
    cfg.ApCliEncrypType = encr

    if encr == "WEP" then
        cfg.ApCliDefaultKeyID = iface.key
    elseif auth == "WPA2PSK" or auth == "WPA3PSK" or
        auth == "WPAPSKWPA2PSK" or auth == "WPA2PSKWPA3PSK" then
        cfg.ApCliWPAPSK = iface.key
    end

    if iface.ieee80211w == '2' then
        cfg.ApCliPMFMFPC = '1'
        cfg.ApCliPMFMFPR = '1'
    elseif iface.ieee80211w == '1' then
        cfg.ApCliPMFMFPC = '1'
        cfg.ApCliPMFMFPR = '0'
    elseif iface.ieee80211w == '0' then
        cfg.ApCliPMFMFPC = '0'
        cfg.ApCliPMFMFPR = '0'
    end

    cfg.ApCliPMFSHA256 = iface.pmf_sha256
    cfg.ApCliOWETranIe = iface.owetrante
    cfg.MACRepeaterEn = iface.mac_repeateren

    local j
    for j = 1, 4 do
        local k = iface["key"..tostring(j)]
        if k then
            local len = #k
            if (len == 10 or len == 26 or len == 32) and k == string.match(k, '%x+') then
                cfg["ApCliKey"..tostring(j).."Type"] = '0'
                cfg["ApCliKey"..tostring(j).."Str"] = k
            elseif (len == 5 or len == 13 or len == 16) then
                cfg["ApCliKey"..tostring(j).."Type"] = '1'
                cfg["ApCliKey"..tostring(j).."Str"] = k
            end
        end
    end

    return cfg
end

function mtkdat.dat2uci()
    --local shuci = require("shuci")
    local profiles = mtkdat.search_dev_and_profile()
    local l1dat, l1 = mtkdat.__get_l1dat()
    local dev, ifname, iface, i, j
    local n = 1
    local m = 1

    if ( not profiles or not l1dat) then
        nixio.syslog("err", "search dev profile fail.")
        return
    end

    local fp = io.open(uciCfgfile, "w")
    if fp == nil then return end

    local dridx = l1.DEV_RINDEX

    local uci = {}
    uci["wifi-device"] = {}
    uci["wifi-iface"] = {}

    for devname, profile in mtkdat.spairs(profiles, function(a,b) return string.upper(a) < string.upper(b) end) do
        local cfg = mtkdat.load_profile(profile)
        if (cfg == nil) then
            fp:close()
            nixio.syslog("err", "load profile for "..devname.." fail.")
            return
        end
        --print("devname:"..devname.." profile:"..profile)

        uci["wifi-device"][n] = {}
        dev = uci["wifi-device"][n]
        cfg2dev(cfg, devname, dev)

        local main_ifname = l1dat[dridx][devname].ext_ifname
        local if_num = tonumber(cfg.BssidNum)

        i = 1
        while i <= if_num do
            uci["wifi-iface"][m] = {}
            iface = uci["wifi-iface"][m]
            ifname = main_ifname..(i-1)
            cfg2iface(cfg, dev[".name"], ifname, iface, i)

            m = m + 1
            i = i + 1
        end

        main_ifname = l1dat[dridx][devname].apcli_ifname
        uci["wifi-iface"][m] = {}
        iface = uci["wifi-iface"][m]
        ifname = main_ifname..(0)
        --print("apcli"..ifname)

        cfg2apcli(cfg, dev[".name"], ifname, iface)

        m = m + 1
        n = n + 1
    end
    --print_table(uci)

    for i = 1, n-1 do
        dev = uci["wifi-device"][i]
        uci_encode_dev_options(fp, dev)
        for j = 1, m-1 do
            iface = uci["wifi-iface"][j]
            if iface.device == dev[".name"] then
                uci_encode_iface_options(fp, iface)
            end
        end
    end
    --shuci.encode(uci, '/etc/config/wireless')
    fp:close()
    os.execute("cp "..uciCfgfile.." "..lastCfgfile)
end

function mtkdat.uci2dat()
    if not mtkdat.exist(uciCfgfile) then return end

    local shuci = require("shuci")
    local uci = shuci.decode(uciCfgfile)
    local profiles = mtkdat.search_dev_and_profile()
    local l1dat, l1 = mtkdat.__get_l1dat()

    if not profiles then
        nixio.syslog("err", "unable to get profiles")
        return
    end

    local dridx = l1.DEV_RINDEX

    for _, dev in pairs(uci["wifi-device"]) do
        if dev.type ~= "mtkwifi" then return end
        local devname = string.gsub(dev[".name"], "%_", ".")
        local cfg = mtkdat.load_profile(profiles[devname])
        local old_cfg = table_clone(cfg);
        --print("dev:"..devname)
        dev2cfg(dev, cfg)

        local main_ifname = l1dat[dridx][devname].ext_ifname
        local iface
        local if_num = 0
        local vifs = get_vifs_by_dev(uci, dev[".name"])

        for _, iface in pairs(vifs) do
            local i = string.find(iface[".name"], "%d+")
            i = string.sub(iface[".name"], i, -1)
            i = tonumber(i) + 1
            iface2cfg(iface, i, cfg)

            if_num = if_num + 1
        end

        if not mtkdat.exist(cfgfile) or if_num > tonumber(cfg.BssidNum) then
            cfg.BssidNum = tostring(if_num)
        end

        for _, iface in pairs(uci["wifi-iface"]) do
            if iface.device == dev[".name"] and iface.mode == 'sta' then
                apcli2cfg(iface, cfg)
                break
            end
        end

        diff = diff_config(cfg, old_cfg)
        --print(devname.." diff config\n")
        --print_table(diff)
        for k, v in pairs(diff) do
            if v ~= nil then
                set_dat_cfg(profiles[devname], k, v)
            end
        end
    end

    --update last file
    os.execute("cp "..uciCfgfile.." "..lastCfgfile)

end


function mtkdat.get_iface_cfg(devname, ifname, cfg_name)
    local dev_name
    local profiles = mtkdat.search_dev_and_profile()
    local l1dat, l1 = mtkdat.__get_l1dat()
    local dridx = l1.DEV_RINDEX

    for dev_name, profile in mtkdat.spairs(profiles, function(a,b) return string.upper(a) < string.upper(b) end) do
        if dev_name == devname then
            local cfg = mtkdat.load_profile(profile)
            local i = 1
            local main_ifname = l1dat[dridx][devname].ext_ifname
            while i <= tonumber(cfg.BssidNum) do
                local if_name = main_ifname..(i-1)
                if if_name == ifname then
                    local v = cfg[cfg_name..tostring(i)]
                    if v ~= nil then return v end
                    return token_get(cfg[cfg_name], i, __split(cfg[cfg_name],";")[1])
                end
                i = i + 1
            end
        end
    end

   return nil
end

function mtkdat.cfg_is_diff()
    if not mtkdat.exist(uciCfgfile) then return false end

    local shuci = require("shuci")

    if not mtkdat.exist(lastCfgfile) then
        if not mtkdat.exist("/tmp/mtk/wifi") then
            os.execute("mkdir -p /tmp/mtk/wifi")
        end
        os.execute("cp "..uciCfgfile.." "..lastCfgfile)
        return false
    end

    if file_is_diff(uciCfgfile, lastCfgfile) then
        return true
    end

    return false
end

function mtkdat.get_wifi_ifaces(devname)
    local ifaces = {}
    if not mtkdat.exist(uciCfgfile) then return end
    local shuci = require("shuci")
    local uci = shuci.decode(uciCfgfile)
    local dev
    if devname then
        dev = string.gsub(devname, "%.", "_")
    end

    for _, iface in pairs(uci["wifi-iface"]) do
        if iface.mode ~= 'sta' and (iface.device == dev or not dev) then
            table.insert(ifaces, iface['.name'])
        end
    end

    return ifaces
end

return mtkdat
