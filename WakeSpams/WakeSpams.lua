--[[
##############################################
##-
##-  WakeSpams
##-  By Cyrila <Aspire> @ Bloodfeather-EU
##-
##-  Cooldowns For Your Raid
##-
##-
##-   * Copyright (C) 2010  Dan Jacobsen
##-   *
##-   * This program is free software: you can redistribute it and/or modify
##-   * it under the terms of the GNU General Public License as published by
##-   * the Free Software Foundation, either version 3 of the License, or
##-   * (at your option) any later version.
##-   *
##-   * This program is distributed in the hope that it will be useful,
##-   * but WITHOUT ANY WARRANTY; without even the implied warranty of
##-   * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
##-   * GNU General Public License for more details.
##-   *
##-   * You should have received a copy of the GNU General Public License
##-   * along with this program.  If not, see <http://www.gnu.org/licenses/>.
##-
##############################################
]]

local WakeSpams = LibStub("AceAddon-3.0"):NewAddon("WakeSpams", "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0")
_G.WakeSpams = WakeSpams

local _G, type, tonumber, tostring = _G, type, tonumber, tostring;
local tinsert = tinsert;
local format, strsub, strfind, gsub = format, string.sub, string.find, string.gsub;
local ipairs = ipairs;
local ceil = math.ceil;

local UnitName, GetSpellLink, UnitExists, UnitGUID, GetUnitName = _G.UnitName, _G.GetSpellLink, _G.UnitExists, _G.UnitGUID, _G.GetUnitName;
local GetSpellLink, GetSpellInfo, GetTime = _G.GetSpellLink, _G.GetSpellInfo, _G.GetTime;
local IsInInstance = _G.IsInInstance;

--[[ unused globals
--local floor = math.floor;
local wipe, tinsert, tremove, tsort = wipe, tinsert, tremove, table.sort;
local format, strsub, strfind, strlen, strformat, gsub = format, string.sub, string.find, string.len, string.format, string.gsub;
local pairs = pairs;
local sin, ceil = math.sin, math.ceil;

local UnitName, GetSpellLink, UnitExists, UnitGUID, UnitHealthMax, GetUnitName = _G.UnitName, _G.GetSpellLink, _G.UnitExists, _G.UnitGUID, _G.UnitHealthMax, _G.GetUnitName;
]]


-- INCREASE THIS VALUE IF YOU HAVE ISSUES WITH AOE SPELL ANNOUNCING.
-- Warning: Do not set to below 0.1
WakeSpams.Lag = 0.2


-- ------------------------------------------------------------
--  INTERNAL VARIABLES (you might not want to touch these)
-- ------------------------------------------------------------

--[===[@debug@--
local debugmode = true
--end-debug@]===]--

WakeSpams.Flag = 1
WakeSpams.Timer = {}
WakeSpams.LastSent = {0, nil}
WakeSpams.Queue = {}
WakeSpams.Active = {}
WakeSpams.FadedActive = {}
WakeSpams.Detect = {}
WakeSpams.LatestDestName = nil


-- --------------------------------
--  DEFAULTS
-- --------------------------------

local db
local defaults = {
	profile = {
		disabled = false,
		Interval = 0.6,
		aoe = true,
		AbilityStart = "Activated: spell:link spell:durations!",
		AbilityEnd = "Faded: spell:link",
		SpellDB = {},
		EventDB = {
			["SPELL_DISPEL"] = {
				disabled = true,
			},
		},
		OutputFlags = { -- If ChatType/Channel not available, say to SELF
			[1] = { -- Self
				"SELF", nil
			},
			[2] = { -- Party
				"PARTY", nil
			},
			[3] = { -- Raid
				"RAID", nil
			},
			[4] = { -- BG
				"WHISPER", "TARGET"
			},
			[5] = { -- WG/TB
				"WHISPER", "TARGET"
			},
			[6] = { -- Arena
				"PARTY", nil
			},
			[7] = { -- LFG/LFD
				"INSTANCE_CHAT", nil
			},
		},
	},
}

function WakeSpams:OnInitialize()
	-- Init
	self.db = LibStub("AceDB-3.0"):New("WakeSpamsDB", defaults, "Default")
	db = self.db.profile
	
	if(db.version ~= 5100) then
		self.db:ResetProfile()
		self.db.profile.version = 5100
		self:Print("Profile reset to default.")
	end
	
	if not db.disabled then
		self:SetEnabledState(true)
	else
		self:SetEnabledState(false)
	end
	
	self:RegisterChatCommand("wakespams", "SlashHandler");
	self:RegisterChatCommand("ws", "SlashHandler");
	
	StaticPopupDialogs["WS_DETECT_SUCCESS"] = {
	  text = "WakeSpams\n\nSpell detection successful!",
	  button1 = "Okay",
	  OnAccept = function()
		  --InterfaceOptionsFrame_OpenToCategory("WakeSpams")
		  return false
	  end,
	  timeout = 10,
	  whileDead = 1,
	  hideOnEscape = 1
	}
end

function WakeSpams:OnEnable()
	-- ENABLED
	--[[
	StaticPopupDialogs["WS_ALPHA_POPUP"] = {
	  text = "WakeSpams\n\n\nThis version ("..GetAddOnMetadata("WakeSpams", "version")..") is for testing purposes ONLY.\n\nPlease report bugs and feature requests in the ticket tracker on WoWace\n(Url: http://www.wowace.com/addons/wakespams/tickets/)",
	  button1 = "Okay",
	  OnAccept = function()
		  return false
	  end,
	  timeout = 0,
	  whileDead = 1,
	  hideOnEscape = 0
	}
	StaticPopup_Show("WS_ALPHA_POPUP")
	]]
	
	-- Register events
	self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED", "COMBAT_LOG_EVENT_UNFILTERED");
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "UpdateFlag");
	self:RegisterEvent("GROUP_ROSTER_UPDATE", "Event_RosterUpdate");
	self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "Event_ZoneChanged");
	
	self:RegisterEvent("UNIT_SPELLCAST_SENT", "UNIT_SPELLCAST_SENT");
	self:RegisterEvent("UNIT_SPELLCAST_START", "UNIT_SPELLCAST_START");
	--self:RegisterEvent("UNIT_SPELLCAST_STOP", "SpellcastListener");
	--self:RegisterEvent("UNIT_SPELLCAST_FAILED_QUIET", "SpellcastListenerTwo");
end

function WakeSpams:OnDisable()
	-- Do something...
	self:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED");
	self:UnregisterEvent("PLAYER_ENTERING_WORLD");
	self:UnregisterEvent("GROUP_ROSTER_UPDATE");
	self:UnregisterEvent("ZONE_CHANGED_NEW_AREA");
	
	self:UnregisterEvent("UNIT_SPELLCAST_SENT");
	self:UnregisterEvent("UNIT_SPELLCAST_START");
end

--[===[@debug@
function WakeSpams:debug(s)
	if(debugmode) then
		self:Print(s)
	end
end
--@end-debug@]===]


-- ----------------------------
--  Config
-- ----------------------------

function WakeSpams:SlashHandler(input)
	self.Options:ShowConfig()
	--[[
	local newsetting
	input = self:Explode(" ", string.lower(input))
	if(input[1] == "enable") then
		if(db.STANDBY == 0) then
			self:Print("Combat log monitoring is already enabled.")
		else
			db.STANDBY = 0
			self:Print("Combat log monitoring enabled.")
		end
	elseif(input[1] == "disable") then
		if(db.STANDBY == 1) then
			self:Print("Combat log monitoring is already disabled.")
		else
			db.STANDBY = 1
			self:Print("Combat log monitoring disabled.")
		end
	elseif(input[1] == "aoe") then
		db.aoe = (db.aoe == 0) and 1 or 0
		newsetting = (db.aoe == 0) and "Disabled" or "Enabled"
		self:Print(("AoE spell announcing has been >%s<"):format(newsetting))
	elseif(input[1] == "settings") then
		self.Options:ShowConfig()
	else
		DEFAULT_CHAT_FRAME:AddMessage("|cFFFFCC00WakeSpams help:")
		DEFAULT_CHAT_FRAME:AddMessage("|cFFCC9900   Enable|r - Starts combat log monitoring")
		DEFAULT_CHAT_FRAME:AddMessage("|cFFCC9900   Disable|r - Stops combat log monitoring")
		DEFAULT_CHAT_FRAME:AddMessage("|cFFCC9900   Aoe|r - Toggles announcing multitarget spells (such as Shockwave and Howl of Terror)")
		DEFAULT_CHAT_FRAME:AddMessage("|cFFCC9900   Help|r - Shows help")
		DEFAULT_CHAT_FRAME:AddMessage("|cFFCC1100   This addon has no config. You can add and edit spell events in the Lua file.|r")
	end
	]]
end


-- ------------------------------------------------------------
--  HANDLE COMBAT LOG AND SPELLCASTING EVENTS
-- ------------------------------------------------------------
function WakeSpams:COMBAT_LOG_EVENT_UNFILTERED(_, timestamp, event, _, sourceGUID, sourceName, srcFlags, srcRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellid, spellname, _, arg1, arg2)
	-- Nil
	if(sourceGUID ~= UnitGUID("player") and sourceGUID ~= UnitGUID("pet")) then return nil end
	
	local spell
	local msg
	
	-- Prioritize catchall events
	if(self.DefaultEventDB[event]) then
		spell = self.DefaultEventDB[event]
		if(db.EventDB[event]) then
			profile = db.EventDB[event]
			if(profile.disabled) then return nil end
			spell.txt = profile.txt or spell.txt
		end
		spell.isEvent = true
		msg = spell.txt or db.AbilityStart
	elseif(spellid) then
		-- The database does not exist
		if not self.DefaultSpellDB or not db.SpellDB then return nil end
		-- Continue if the spell exists in either the default spell list or in the saved variables
		if(self.DefaultSpellDB[spellid] or db.SpellDB[spellid]) then
			if(db.SpellDB[spellid] and db.SpellDB[spellid].detect) then
				-- Auto detect spell settings.
				if(event ~= "SPELL_CAST_FAILED") then
					self:SpellAutoDetect({timestamp, event, destGUID, destName, spellid, spellname}, true)
				end
				return true
			end
			-- Get the spell table from the spell list if it exists, or
			-- In the case of a custom spell, since it will only exist in saved variables, fetch those
			if(self.DefaultSpellDB[spellid]) then
				spell = self.DefaultSpellDB[spellid]
				if(db.SpellDB[spellid]) then
					profile = db.SpellDB[spellid]
					if(profile.disabled) then return nil end
					spell.txt       = profile.txt       --or spell.txt
					spell.dur       = profile.dur       or 0 --or spell.dur
					spell.txtend    = profile.txtend    --or spell.txtend
					spell.countdown = profile.countdown or 0 --or spell.countdown
					spell.fade      = profile.fade      --or spell.fade
					spell.whisper   = profile.whisper   --or spell.whisper
					spell.fademode  = profile.fademode
					spell.fadearg   = profile.fadearg
				end
			else
				spell = db.SpellDB[spellid]
				if(spell.disabled) then return nil end
			end
			-- 
			if not db.aoe and (spell.aoe) then return nil end
			if not spell.event and (event == "SPELL_AURA_APPLIED" or event == "SPELL_AURA_REMOVED") then
				-- SPELL_AURA
				if(event == "SPELL_AURA_REMOVED") then
					if(spell.countdown and (spell.countdown > 0)) then
						-- Stop timers
						self:CancelTimer(self.Timer[spellid].timer, true)
						self.Timer[spellid] = nil
					end
					if not spell.fade then
						return nil
					end
					msg = spell.txtend or db.AbilityEnd
					spell.faded = true
				else
					msg = spell.txt or db.AbilityStart
					
					if(self:isNumeric(spell.countdown) and spell.countdown > 0) then
						self.Timer[spellid] = {}
						self.Timer[spellid].elapsed = 0
						self.Timer[spellid].timer = self:ScheduleRepeatingTimer("TimerHandle", 1, {spellid, spell.dur, spell.dur-spell.countdown, destName}) -- duration, duration-time to know when to start announcing
					end
				end
			end
			if(spell.event == event) then
				msg = spell.txt or db.AbilityStart
			end
		end
	end
	
	-- Return nil if no message was formatted
	if not msg then return nil end
	
	--spellname = spell.name or GetSpellLink(spellid)
	--msgframe = spell.output or self.MsgFrame
	
	-- Format string
	msg = gsub(msg, "spell:link", function (v)
		local r = ""
		if(spellid~=32747) then
			r = GetSpellLink(spellid) or ""
		end
		return r
	end)
	msg = gsub(msg, "spell:name", spellname or "")
	msg = gsub(msg, "spell:duration", spell.dur or "")
	msg = gsub(msg, "spell:amount", tostring(arg1) or "")
	msg = gsub(msg, "spell:target", function(v)
		if(destName == UnitName("player")) then
			v = "me"
		else
			v = GetUnitName(destName, nil) or destName
			v = self:RaidIconText(self:GetUnitID(destGUID, destName))..v
		end
		return v
	end)
	msg = gsub(msg, "spell:extra:link", function(v)
		if(arg1 and (self:isNumeric(arg1))) then
			v = GetSpellLink(arg1) or ""
		end
		return v
	end)
	msg = gsub(msg, "spell:extra", function(v)
		if(event == "SPELL_MISSED") then
			v = tostring(arg1) or ""
		else
			v = arg2 or ""
		end
		return v
	end)
	
	if(spell.aoe) then
		self:Enqueue(spellid, destName, msg, spell.dur, spell.faded)
		return true
	end
	if(spell.faded and spell.fademode) then
		self:FadedEnqueue({spellid, msg, destName, destGUID, spell.fademode, spell.fadearg}, true)
		return true
	end
	if(spell.fademode == 2) then
		self:FadedEnqueue(spell.fadearg, true)
	end
	
	spellid = (spell.isEvent) and event or spellid
	local isplayer = UnitIsPlayer(self:GetUnitID(destGUID, destName))
	self:Announce(msg, spellid, destName, isplayer)
end

function WakeSpams:UNIT_SPELLCAST_SENT(_, unit, _, _, destName)
	if(unit ~= "player" and unit ~= "pet") then return nil end
	-- Set the latest spell target
	self.LatestDestName = destName
end

function WakeSpams:UNIT_SPELLCAST_START(_, unit, spellname, _, _, spellid)
	if(unit ~= "player" and unit ~= "pet") then return nil end
	
	-- Credits to LibResComm and oRA2
	local target = self.LatestDestName
	if not target or target == UNKNOWN then
	
		if GameTooltipTextLeft1:IsVisible() then
			target = GameTooltipTextLeft1:GetText():match("^" .. CORPSE_TOOLTIP:gsub("%s", "(.+)"))
		end
		
	end
	
	-- Simulate combat log event
	self:COMBAT_LOG_EVENT_UNFILTERED(nil, nil, "UNIT_SPELLCAST_START", _, UnitGUID("player"), UnitName("player"), nil, nil, nil, target, nil, nil, spellid, spellname)
end


--[[
--interrupts
function WakeSpams:SpellcastListener(_, unit, spellname, spellrank, lineid, spellid)
	self:ChatMSG(("Cast STOPPED unit: %s spell: %s id: %d"):format(unit, spellname, spellid), "PARTY")
end

--fails
function WakeSpams:SpellcastListenerTwo(_, unit, spellname, spellrank, lineid, spellid)
	self:ChatMSG(("Cast FAILED (QUIET) unit: %s spell: %s id: %d"):format(unit, spellname, spellid), "PARTY")
end
]]

-- ---------------------------
--  Spell Auto Detection
-- ---------------------------

function WakeSpams:SpellAutoDetect(a, notimer)
	-- 1 = timestamp, 2 = event, 3 = destGUID, 4 = destName, 5 = spellid, 6 = spellname
	StaticPopup_Hide("WS_AUTODETECTSPELL")
	if not notimer then
		local detect = self.Detect[a]
		detect.dur = (detect.dur) and detect.dur or 0
		detect.event = (detect.event == "SPELL_CAST_START") and "UNIT_SPELLCAST_START" or detect.event
		
		-- Default messages for events
		if(detect.event == "SPELL_HEAL" or detect.event == "SPELL_DAMAGE") then
			detect.txt = "Activated: spell:link on spell:target (spell:amount)"
		end
		if(detect.event == "UNIT_SPELLCAST_START") then
			detect.txt = "Casting: spell:link on spell:target"
		end
		
		self.db.profile.SpellDB[a] = {
			detect = nil,
			aoe = (detect.targets > 1) and true or nil,
			event = (detect.event ~= "SPELL_AURA_APPLIED") and detect.event or nil,
			dur = detect.dur,
			fade = (detect.dur >= 5) and true or nil,
			txt = detect.txt,
		}
		StaticPopup_Show("WS_DETECT_SUCCESS")
		self.Detect[a] = false
		return true
	end
	if not self.Detect[a[5]] then
		self.Detect[a[5]] = {
			starttime = a[1],
			destGUID = a[3] or "",
			event = a[2],
			targets = 0,
		}
		self:ScheduleTimer("SpellAutoDetect", 5, a[5])
	end
	if(a[2] == "SPELL_AURA_APPLIED") then
		local unit = self:GetUnitID(a[3], a[4])
		local name, duration, expirationTime, spellId
		name, _, _, _, _, duration, expirationTime, _, _, _, spellId = UnitAura(unit, a[6], nil, "PLAYER")
		if not name then name, _, _, _, _, duration, expirationTime, _, _, _, spellId = UnitAura(unit, a[6], nil, "PLAYER|HARMFUL") end
		self.Detect[a[5]].dur = ceil(duration)
		if(spellId ~= a[5]) then self:Print("Warning: Entered spell ID seems to be differing from ID found in Unit Auras. Recheck Spell ID!") end
		self.Detect[a[5]].event = a[2]
		self.Detect[a[5]].targets = self.Detect[a[5]].targets + 1
	else
		if(a[2] == "SPELL_CAST_FAILED") then
			return nil
		end
		self.Detect[a[5]].event = (self.Detect[a[5]].event == "SPELL_AURA_APPLIED") and self.Detect[a[5]].event or a[2]
	end
end


-- ----------------------------
--  Misc. event handlers
-- ----------------------------
function WakeSpams:Event_RosterUpdate()
	self:UpdateFlag()
end

function WakeSpams:Event_ZoneChanged()
	-- Quote (WoWWiki):
	-- "When this event fires, the UI may still think you're in the zone you just left. Don't depend on GetRealZoneText()
	-- and similar functions to report the new zone in reaction to ZONE_CHANGED_NEW_AREA. (untested for similar events)"
	-- Circumvented by adding a delay to the function
	self:ScheduleTimer("UpdateFlag", 0.1)
end

function WakeSpams:UpdateFlag()
	-- 1: Solo, 2: Party, 3: Raid, 4: Battleground, 5: WG and Tol Barad, 6: Arena
	--[===[@debug@
	self:debug("Updating the State Flag.")
	--@end-debug@]===]
	local _, instanceType = IsInInstance()
	if(instanceType == "arena") then
		self.Flag = 6
		--[===[@debug@
		self:debug("Set to: "..self.Flag)
		--@end-debug@]===]
		return true
	end
	if(GetNumGroupMembers() > 1) then
		-- Credits to Kagaro for locale-independant TB/WG zone detection
		local aid = GetCurrentMapAreaID()
		if (aid == 708 or aid == 709) or (aid == 501) then
			-- your in Tol Brad (has 2 area markers) or WinterGrasp
			self.Flag = 5
			--[===[@debug@
			self:debug("Set to: "..self.Flag)
			--@end-debug@]===]
			return true
		end
		if(IsInGroup(LE_PARTY_CATEGORY_INSTANCE)) then
			self.Flag = 7;
			--[===[@debug@
			self:debug("Set to: "..self.Flag)
			--@end-debug@]===]
			return true
		end
		if(instanceType == "pvp") then
			self.Flag = 4
			--[===[@debug@
			self:debug("Set to: "..self.Flag)
			--@end-debug@]===]
			return true
		end
		
		if(IsInRaid()) then
			self.Flag = 3
			--[===[@debug@
			self:debug("Set to: "..self.Flag)
			--@end-debug@]===]
			return true
		else
			self.Flag = 2
			--[===[@debug@
			self:debug("Set to: "..self.Flag)
			--@end-debug@]===]
			return true
		end
	end
	self.Flag = 1
	--[===[@debug@
	self:debug("Set to: "..self.Flag)
	--@end-debug@]===]
	return true
end


-- ---------------------------
--  Communication
-- ---------------------------

function WakeSpams:FadedEnqueue(args, notimer)
	-- spellid, msg, destName, destGUID, fademode, fadearg
	if(notimer) then
		if(self:isNumeric(args)) then
			-- We got spellid, kill timer
			self:CancelTimer(self.FadedActive[args], true)
			return nil
		end
		if(args[5] == 1) then
			self.FadedActive[args[1]] = self:ScheduleTimer("FadedEnqueue", 0.2, args)
			return nil
		end
		return nil
	end
	local isplayer = UnitIsPlayer(self:GetUnitID(args[4], args[3]))
	self:Announce(args[2], args[1], args[3], isplayer)
end

function WakeSpams:Enqueue(spellID, destName, msg, duration, faded)
	-- Workaround if for some reason an empty destName is returned from combatlog (?)
	if not spellID then return end
	if not destName then destName = "UNKNOWN" end
	
	if not self.Queue[spellID] and not self.Active[spellID] and not faded then
		-- Create new timer
		-- This is terribly programmed. Somebody shoot me and kill this tanglemess.
		self:ScheduleTimer("SendQueue", self.Lag, {spellID, msg})
		duration = (duration >= 1) and duration or 60
		self:ScheduleTimer("SendFadedQueue", duration, {spellID, msg})
		self.Active[spellID] = 0
		self.Queue[spellID] = {}
	end
	if not faded then
		self.Active[spellID] = self.Active[spellID] + 1
		tinsert(self.Queue[spellID], {destName});
		return true
	end
	if(self:isNumeric(self.Active[spellID])) then
		self.Active[spellID] = self.Active[spellID] - 1
		self:SendFadedQueue({spellID, msg}, true)
	end
end

function WakeSpams:SendFadedQueue(args, notimer)
	local spellID, msg = args[1], args[2]
	local spell = (db.SpellDB[spellid]) and db.SpellDB[spellid] or self.DefaultSpellDB[spellID]
	
	if not self:isNumeric(self.Active[spellID]) then return false end
	if(notimer) then
		if(self.Active[spellID] >= 1) then return false end
	end
	
	if(spell.aoe and spell.fade) then
		-- Go!
		if(spell.txtend) then
			msg = spell.txtend
			msg = gsub(msg, "spell:link", GetSpellLink(spellID) or "")
		else
			msg = ("Faded: %s"):format(GetSpellLink(spellID))
		end
		self:Announce(msg, spellID)
	end
	
	self.Active[spellID] = nil
	self.Queue[spellID] = nil
	return true
end

function WakeSpams:SendQueue(args)
	local spellID, msg = args[1], args[2]
	local spell = (db.SpellDB[spellid]) and db.SpellDB[spellid] or self.DefaultSpellDB[spellID]
	if self.Queue[spellID] then
		local total
		local targetN
		for i,v in ipairs(self.Queue[spellID]) do
			total = i
			targetN = (targetN) and (targetN..", "..v[1]) or v[1]
		end
		if(msg and spell.txt) then
			msg = msg
		else
			if(total == 1) then
				msg = (("%s: Hit %d target! (%s)"):format(GetSpellLink(spellID),total,targetN))
			else
				msg = (("%s: Hit %d targets!"):format(GetSpellLink(spellID),total))
			end
		end
		--local msg = "SpellLink: Hit 3 targets (X, Y, Z)"
		self:Announce(msg, spellID)
	end
end

function WakeSpams:TimerHandle(args)
	-- args: 1 = spellid, 2 = d, 3 = ts, 4 = target
	self.Timer[args[1]].elapsed = self.Timer[args[1]].elapsed + 1
	
	if(self.Timer[args[1]].elapsed >= args[3] and self.Timer[args[1]].elapsed < args[2]) then
		self:Announce(""..args[2] - self.Timer[args[1]].elapsed.."", args[1], args[4])
	end
end

function WakeSpams:Announce(msg, spellid, target, isplayer)
	if(GetTime() < self.LastSent[1]+db.Interval and self.LastSent[2] == spellid and self:isNumeric(spellid)) then -- Temporary chat throttle
		return nil
	end
	
	local tmpout = {}
	local typeid, channel
	if(self:isNumeric(spellid)) then
		if(db.SpellDB[spellid] and (db.SpellDB[spellid].OutputFlags)) then
			if(db.SpellDB[spellid].whisper == true) then
				typeid, channel = "WHISPER", "TARGET"
			else
				if(db.SpellDB[spellid].OutputFlags[self.Flag]) then
					typeid, channel = db.SpellDB[spellid].OutputFlags[self.Flag][1], db.SpellDB[spellid].OutputFlags[self.Flag][2]
				else
					typeid, channel = db.OutputFlags[self.Flag][1], db.OutputFlags[self.Flag][2]
				end
			end
		else
			if(self.DefaultSpellDB[spellid] and self.DefaultSpellDB[spellid].whisper) then
				typeid, channel = "WHISPER", "TARGET"
			else
				typeid, channel = db.OutputFlags[self.Flag][1], db.OutputFlags[self.Flag][2]
			end
		end
	else
		typeid, channel = db.OutputFlags[self.Flag][1], db.OutputFlags[self.Flag][2]
	end
	
	tinsert(tmpout, {typeid, channel})
	
	if db.SpellDB[spellid] then
		if db.SpellDB[spellid].output then
			for i,v in ipairs(db.SpellDB[spellid].output) do
				tinsert(tmpout, {v[1], v[2]})
			end
		end
	end
	
	for i,v in ipairs(tmpout) do
		local msg = msg
		if(v[1]) then
		
			if(v[1] == "DISABLE") then
				return true
			end
		
			if(v[1] == "CHANNEL") then
				-- Resolve channel name
				v[2], _, _ = GetChannelName(v[2])
				if(v[2] == 0) then
					v[1] = "SELF"
					self:Print("Custom channel name could not be resolved. You are not in that channel.")
				end
			end
			
			if(v[1] == "WHISPER" and v[2] == "TARGET") then
				-- Filters out if target is not a player
				if(isplayer) then
					v[2] = target
					msg = gsub(msg, target, "YOU")
				else
					v[1] = "SELF"
					v[2] = nil
				end
			end
			
			--[===[@debug@
			self:debug("Announce spell to: "..v[1] or "nil"..", "..v[2] or "nil")
			--@end-debug@]===]
			
			self:ChatMSG(msg, v[1], nil, v[2])
		end
	end
	
	self.LastSent = {GetTime(), spellid}
end

function WakeSpams:ChatMSG(msg, mtype, mlang, marg)
	if(mtype=="SELF") then
		DEFAULT_CHAT_FRAME:AddMessage(msg)
	else
		if(mtype=="WHISPER" and marg==UnitName("player")) then
			DEFAULT_CHAT_FRAME:AddMessage(msg)
		else
			SendChatMessage(msg, mtype, mlang, marg)
		end
	end
end


-- ----------------------------
--  Helper functions
-- ----------------------------

function WakeSpams:ResetSpell(spellid)
	WakeSpams.Spells:InitSpellDB() -- Some strange bug in the config keeps changing the default spell db table, this is a cheap workaround
	self.db.profile.SpellDB[spellid] = self.DefaultSpellDB[spellid] or nil
	if(self.db.profile.SpellDB[spellid]) then 
		self.db.profile.SpellDB[spellid].secout = 0
		self.db.profile.SpellDB[spellid].OutputFlags = {}
	end
end

function WakeSpams:RaidIconText(t)
	local ri = ""
	if UnitExists(t) then
		ri = (GetRaidTargetIndex(t)) and ("{rt%d}"):format(GetRaidTargetIndex(t)) or ri
	end
	return ri
end

function WakeSpams:GetUnitID(GUID, name)
	-- Translates GUID to target (target, focus, mouseover, playername)
	if UnitGUID("focus") == GUID then
		return "focus"
	end
	if UnitGUID("mouseover") == GUID then
		return "mouseover"
	end
	if UnitGUID("target") == GUID then
		return "target"
	end
	if UnitGUID("player") == GUID then
		return "player"
	end
	return name
end

function WakeSpams:isNumeric(a)
    return type(tonumber(a)) == "number"
end

function WakeSpams:Explode(d, str)
	local t, ll
	t={}
	ll=0
	if(#str == 1) then return str end
		while true do
			l=strfind(str, d, ll+1, true)
			if l~=nil then
				tinsert(t, strsub(str, ll, l-1))
				ll=l+1
			else
				tinsert(t, strsub(str,ll))
				break
			end
		end
	return t
end