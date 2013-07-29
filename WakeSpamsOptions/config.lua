local addon = WakeSpams
local module = addon:NewModule("Options")
WakeSpams.Options = module

local _G = _G
local pairs = pairs
local format, tonumber = format, tonumber
local GetSpellLink, GetSpellInfo = _G.GetSpellLink, _G.GetSpellInfo;

local ACD = LibStub("AceConfigDialog-3.0")
local ACR = LibStub("AceConfigRegistry-3.0")
local db

local options
local helptext = "spell:name = spellname,\
spell:link = spell link,\
spell:seconds = duration in seconds (without formatting),\
spell:duration = duration in hours>minutes>seconds (with formatting),\
spell:target = targetname,\
\
spell:amount = amount (heal, damage, etc),\
spell:extra = resist type for resists, spell names for interrupted spells, etc.\
spell:extra:link = same as above, but with spell links if available."
	
function module:PopulateSpellList()
	local tbl = {}
	for i,v in pairs(addon.DefaultSpellDB) do
		local spellname, _, icon, _, _, _, _, _, _ = GetSpellInfo(i)
		local spell = addon.DefaultSpellDB[i]
		spellname = spell.configname or spellname
		tbl[tostring(i)] = {
			name = spell.configname or spellname,
			type = "group",
			inline = true,
			order = i,
			args = {
				description = {
					name = "",
					type = "description",
					order = 1,
					image = icon,
					width = "half",
					imageCoords = {0.1,0.9,0.1,0.9},
					imageWidth = 18,
					imageHeight = 18,
				},
				toggleSpell = {
					name = "Enable",
					type = "toggle",
					order = 3,
					width = "half",
					desc = ('Enable/disable announcing for "%s"'):format(spellname),
					--descStyle = "inline",
					set = function(info,val)
						if not db.profile.SpellDB[i] then
							db.profile.SpellDB[i] = {}
						end
						db.profile.SpellDB[i].disabled = not val
					end,
					get = function()
						if not db.profile.SpellDB[i] then
							return true
						else
							return not db.profile.SpellDB[i].disabled
						end
					end,
				},
				editSpell = {
					name = "Edit",
					type = "execute",
					order = 2,
					width = "half",
					desc = ('Edit "%s"'):format(spellname),
					func = function()
						if not db.profile.SpellDB[i] then
							db.profile.SpellDB[i] = spell
						end
						if(options.args.spells.args.oldlist) then
							options.args.spells.args.list = options.args.spells.args.oldlist
							options.args.spells.args.oldlist = nil
						else
							options.args.spells.args.oldlist = options.args.spells.args.list
							options.args.spells.args.list = nil
						end
						options.args.spells.args.edit = module:EditSpell(i)
					end,
				}
			}
		}
	end
	
	for i,v in pairs(addon.db.profile.SpellDB) do
		if not addon.DefaultSpellDB[i] then
			if not tbl.custom then
				tbl.custom = {
					name = "Custom Spells",
					order = -999999,
					type = "header",
				}
			end
			local spellname, _, icon, _, _, _, _, _, _ = GetSpellInfo(i)
			local spell = db.profile.SpellDB[i]
			tbl[tostring(i)] = {
				name = spell.configname or spellname,
				type = "group",
				inline = true,
				order = -i,
				args = {
					description = {
						name = "",
						type = "description",
						order = 1,
						image = icon,
						width = "half",
						imageCoords = {0.1,0.9,0.1,0.9},
						imageWidth = 18,
						imageHeight = 18,
					},
					toggleSpell = {
						name = "Enable",
						type = "toggle",
						order = 4,
						width = "half",
						desc = ('Enable/disable announcing for "%s"'):format(spellname),
						--descStyle = "inline",
						set = function(info,val)
							if not db.profile.SpellDB[i] then
								db.profile.SpellDB[i] = {}
							end
							db.profile.SpellDB[i].disabled = not val
						end,
						get = function()
							if not db.profile.SpellDB[i] then
								return true
							else
								return not db.profile.SpellDB[i].disabled
							end
						end,
					},
					editSpell = {
						name = "Edit",
						type = "execute",
						order = 2,
						width = "half",
						desc = ('Edit "%s"'):format(spellname),
						func = function()
							if not db.profile.SpellDB[i] then
								db.profile.SpellDB[i] = spell
							end
							if(options.args.spells.args.oldlist) then
								options.args.spells.args.list = options.args.spells.args.oldlist
								options.args.spells.args.oldlist = nil
							else
								options.args.spells.args.oldlist = options.args.spells.args.list
								options.args.spells.args.list = nil
							end
							options.args.spells.args.edit = module:EditSpell(i)
						end,
					},
					--[[deleteSpell = {
						name = "Delete",
						type = "execute",
						order = 3,
						width = "half",
						desc = GetSpellLink(i)..' Delete this spell.',
						confirm = function() return ("Are you sure you wish to remove %s?"):format(spellname) end,
						func = function()
							addon.db.profile.SpellDB[i] = false
						end,
					}]]
				}
			}
		end
	end
	return tbl
end

function module:PopulateEventList()
	local tbl = {}
	for i,v in pairs(addon.DefaultEventDB) do
		local event = addon.DefaultEventDB[i]
		if not db.profile.EventDB[i] then db.profile.EventDB[i] = event end
		local eventname = event.configname or i
		tbl[tostring(i)] = {
			name = eventname,
			type = "group",
			inline = true,
			order = 1,
			args = {
				txt = {
					name = "Format message.",
					type = "input",
					order = 1,
					width = "full",
					--disabled = function() return (db.profile.SpellDB[spellid].aoe) and true or nil end,
					set = function(info,val) db.profile.EventDB[i].txt = (val ~= "") and val or v.txt end,
					get = function() return db.profile.EventDB[i].txt or v.txt end,
				},
			},
		}
	end
	return tbl
end

function module:EditSpell(spellid)
	db.profile.SpellDB[spellid].secout = db.profile.SpellDB[spellid].secout or 0
	
	local function AddSecondaryOutput(n)
		local tbl = {
			select = {
				name = "Announcing method",
				type = "select",
				order = 2,
				values = {
					["1"] = "Whisper specific player",
					["2"] = "Select channel from list",
					["3"] = "Reroute to another addon",
				},
				style = "dropdown",
				width = "normal",
				set = function(info,val) db.profile.SpellDB[spellid].outputcfg[n].mode = val end,
				get = function() return db.profile.SpellDB[spellid].outputcfg[n].mode or "0" end,
			},
			whisperoutput = {
				name = "Name of player:",
				type = "input",
				order = 3,
				width = "full",
				hidden = function() return (db.profile.SpellDB[spellid].outputcfg[n].mode ~= "1") and true or nil end,
				--disabled = function() return (db.profile.SpellDB[spellid].aoe) and true or nil end,
				set = function(info,val) db.profile.SpellDB[spellid].output[n] = (val ~= "") and { "WHISPER", val } or nil end,
				get = function() local name
					if(db.profile.SpellDB[spellid].output[n]) then
						if(db.profile.SpellDB[spellid].output[n][2]) then
							name = db.profile.SpellDB[spellid].output[n][2]
						end
					end
				return name end,
			},
			chanoutput = {
				name = "Announce to:",
				type = "select",
				order = 3,
				values = module:OutputVals(spellid),
				style = "dropdown",
				width = "normal",
				set = function(info,val)
					val = module:SetChannelForm(val) 
					if(spellid) then
						if(val[1] == "GLOBAL") then val = nil end
						db.profile.SpellDB[spellid].output[n] = val or nil
					end
				end,
				get = function()
					local v
					if(spellid) then
						if not db.profile.SpellDB[spellid].output[n] then
							v = "!0_GLOBAL"
						else
							v = module:GetChannelForm(db.profile.SpellDB[spellid].output[n])
						end
					end
					return v
				end,
				hidden = function() return (db.profile.SpellDB[spellid].outputcfg[n].mode ~= "2") and true or nil end,
			},
		}
		return tbl
	end
	
	local spellname, _, icon, _, _, _, _, _, _ = GetSpellInfo(spellid)
	spellname = db.profile.SpellDB[spellid].configname or spellname
	local tbl = {
		name = "Edit Spell",
		type = "group",
		order = 1,
		disabled = function() return (db.profile.SpellDB[spellid].fademode == 2) and true or nil end,
		args = {
			description = {
				name = spellname,
				fontSize = "large",
				type = "description",
				order = 1,
				width = "full",
				image = icon,
				imageCoords = {0.1,0.9,0.1,0.9},
				imageWidth = 20,
				imageHeight = 20,
			},
			desctwo = {
				name = ("|cffffae00Spell ID: %d|r"):format(spellid),
				fontSize = "",
				type = "description",
				order = 2,
				width = "full",
			},
			spacerone = {
				name = "Spell Behaviour",
				type = "header",
				order = 3,
			},
			duration = {
				name = "Duration of the spell (in seconds)",
				desc = "Enter the duration of the spell here. The addon doesn't look up durations automatically, so if you have a talent that increases the duration, you will have to change it manually.",
				type = "range",
				min = 0,
				max = 1800,
				softMax = 40,
				step = 1,
				order = 30,
				set = function(info,val) db.profile.SpellDB[spellid].dur = val end,
				get = function() return db.profile.SpellDB[spellid].dur end,
			},
			aoe = {
				name = "AoE spell",
				desc = "Toggle this if it's a spell that hits multiple targets. Toggling this will also ignore custom start and end messages.",
				type = "toggle",
				order = 31,
				disabled = function() return (addon.DefaultSpellDB[spellid]) and true or nil end,
				set = function(info,val) db.profile.SpellDB[spellid].aoe = val end,
				get = function() return db.profile.SpellDB[spellid].aoe end,
			},
			countdown = {
				name = "Countdown in chat",
				desc = "Counts down in the chat when the spell is about to fade. Set to 0 for no countdown.",
				type = "range",
				min = 0,
				max = 5,
				step = 1,
				order = 32,
				set = function(info,val) db.profile.SpellDB[spellid].countdown = val end,
				get = function() return db.profile.SpellDB[spellid].countdown end,
			},
			spellfade = {
				name = "Announce when the spell fades",
				desc = "Toggle to announce when the spell fades.",
				type = "toggle",
				order = 33,
				set = function(info,val) db.profile.SpellDB[spellid].fade = val end,
				get = function() return db.profile.SpellDB[spellid].fade end,
			},
			spacertwo = {
				name = "Chat Customization",
				type = "header",
				order = 49,
			},
			txt = {
				name = "Start message of spell. Leave blank for default.",
				type = "input",
				order = 50,
				width = "full",
				--disabled = function() return (db.profile.SpellDB[spellid].aoe) and true or nil end,
				set = function(info,val) db.profile.SpellDB[spellid].txt = (val ~= "") and val or nil end,
				get = function() return db.profile.SpellDB[spellid].txt end,
			},
			txttwo = {
				name = "Fade message of spell. Leave blank for default.",
				type = "input",
				order = 51,
				width = "full",
				hidden = function() return (db.profile.SpellDB[spellid].advfade) and true or nil end,
				--disabled = function() return (db.profile.SpellDB[spellid].aoe) and true or nil end,
				set = function(info,val) db.profile.SpellDB[spellid].txtend = (val ~= "") and val or nil end,
				get = function() return db.profile.SpellDB[spellid].txtend end,
			},
			advfadetoggle = {
				name = "Advanced fading",
				desc = "Toggle to use one of WakeSpams' advanced fade modes for this spell.",
				type = "toggle",
				order = 52,
				set = function(info,val) db.profile.SpellDB[spellid].advfade = val end,
				get = function() return db.profile.SpellDB[spellid].advfade end,
			},
			advfadecontent = {
				name = "",
				type = "group",
				order = 53,
				inline = true,
				hidden = function() return (not db.profile.SpellDB[spellid].advfade) and true or nil end,
				args = {
					header = {
						name = "Advanced Fading",
						type = "header",
						order = 1,
					},
					fademode = {
						name = "Fading mode",
						type = "select",
						order = 2,
						values = {
							["0"] = ">> Select mode <<",
							["1"] = "Link with secondary spell",
							["3"] = "Scan for early fade (cc break etc)",
						},
						style = "dropdown",
						width = "normal",
						set = function(info,val) db.profile.SpellDB[spellid].advfade = val end,
						get = function() return db.profile.SpellDB[spellid].advfade or "0" end,
					},
					fademodeOneContent = {
						name = "Settings for linking with a secondary spell.",
						type = "group",
						order = 3,
						inline = true,
						hidden = function() return (db.profile.SpellDB[spellid].advfade ~= "1") and true or nil end,
						args = {
							helptxt = {
								name = "Please note: The secondary spell you wish to use must be present in the custom WakeSpams spell list. Make sure it's available before you proceed. IF THE SPELL YOU WISH TO USE IS IN YOUR SPELL LIST, BUT YOU CAN NOT SEE IT IN THE DROP DOWN, CLICK EDIT ON IT ONCE IN THE SPELL LIST (YOU DO NOT HAVE TO EDIT ANYTHING) AND IT WILL BE AVAILABLE.\
										Upon linking this primary spell with a secondary spell, spell settings for the secondary spell will become unavailable. Make sure announcement for secondary spell works as you desire before completing this step.",
								type = "description",
								order = 1,
							},
							advspellid = {
								name = "Select secondary spell.",
								type = "select",
								order = 2,
								values = function()
										local vtbl = {}
										vtbl["0"] = ">> Please select spell <<"
										for i,v in pairs(addon.db.profile.SpellDB) do
											local spellname, _, _, _, _, _, _, _, _ = GetSpellInfo(i)
											vtbl[tostring(i)] = v.configname or spellname
										end
										return vtbl
									end,
								style = "dropdown",
								width = "normal",
								set = function(info,val)
										val = tonumber(val)
										if(addon:isNumeric(val) and val>=1) then
											--Reset old spell if existing
											if(db.profile.SpellDB[spellid].fademode == 1) then
												if(db.profile.SpellDB[db.profile.SpellDB[spellid].fadearg]) then
													db.profile.SpellDB[db.profile.SpellDB[spellid].fadearg].fademode = nil
													db.profile.SpellDB[db.profile.SpellDB[spellid].fadearg].fadearg = nil
												end
											end
											
											db.profile.SpellDB[spellid].fademode = 1
											db.profile.SpellDB[spellid].fadearg = val
											
											db.profile.SpellDB[val].fademode = 2
											db.profile.SpellDB[val].fadearg = spellid
										end
									end,
								get = function() return (db.profile.SpellDB[spellid].fademode == 1) and tostring(db.profile.SpellDB[spellid].fadearg) or "0" end,
							},
							advfadetxtsec = {
								name = "Fade message if secondary spell is activated before primary spell fades:",
								type = "input",
								order = 50,
								width = "full",
								--disabled = function() return (db.profile.SpellDB[spellid].aoe) and true or nil end,
								set = function(info,val) db.profile.SpellDB[db.profile.SpellDB[spellid].fadearg].txt = (val ~= "") and val or nil end,
								get = function() if(db.profile.SpellDB[spellid].fadearg) then return db.profile.SpellDB[db.profile.SpellDB[spellid].fadearg].txt end end,
							},
							advfadetxtpri = {
								name = "Fade message if primary spell fades normally and secondary spell is not found:",
								type = "input",
								order = 51,
								width = "full",
								--disabled = function() return (db.profile.SpellDB[spellid].aoe) and true or nil end,
								set = function(info,val) db.profile.SpellDB[spellid].txtend = (val ~= "") and val or nil end,
								get = function() return db.profile.SpellDB[spellid].txtend end,
							},
						},
					},
				},
			},
			output = {
				name = "",
				type = "group",
				order = 60,
				inline = true,
				disabled = function() return (db.profile.SpellDB[spellid].whisper) and true or nil end,
				args = module:SetupOutputOptions(spellid),
			},
			secondaryOutToggle = {
				name = "Secondary Output",
				desc = "Toggle to make this spell announce in additional channels.",
				type = "toggle",
				order = 81,
				set = function(info,val) if val then
						if not db.profile.SpellDB[spellid].output then db.profile.SpellDB[spellid].output = {} end
						if not db.profile.SpellDB[spellid].outputcfg then db.profile.SpellDB[spellid].outputcfg = {} end
						if not db.profile.SpellDB[spellid].outputcfg[1] then db.profile.SpellDB[spellid].outputcfg[1] = {} end
						
						db.profile.SpellDB[spellid].secout = 1
					else
						db.profile.SpellDB[spellid].output = nil
						db.profile.SpellDB[spellid].outputcfg = nil
						
						db.profile.SpellDB[spellid].secout = 0
					end
				end,
				get = function() return (db.profile.SpellDB[spellid].secout>=1) and true or nil end,
			},
			secondaryOut = {
				name = "",
				type = "group",
				order = 82,
				inline = true,
				hidden = function() return (db.profile.SpellDB[spellid].secout<1) and true or nil end,
				args = {
					header = {
						name = "Secondary Output",
						type = "header",
						order = 1,
					},
					buttonAdd = {
						name = "Add",
						type = "execute",
						order = 2,
						width = "half",
						func = function()
							if db.profile.SpellDB[spellid].secout < 5 then
								local num = db.profile.SpellDB[spellid].secout
								
								if not db.profile.SpellDB[spellid].outputcfg[num+1] then db.profile.SpellDB[spellid].outputcfg[num+1] = {} end
		
								db.profile.SpellDB[spellid].secout = num+1
							end
						end,
					},
					buttonRemove = {
						name = "Remove",
						type = "execute",
						order = 2,
						width = "half",
						func = function()
							if db.profile.SpellDB[spellid].secout > 1 then
								local num = db.profile.SpellDB[spellid].secout
								
								db.profile.SpellDB[spellid].output[num] = nil
								db.profile.SpellDB[spellid].outputcfg[num] = nil
								
								db.profile.SpellDB[spellid].secout = num-1
							end
						end,
					},
					out1 = {
						name = "Secondary Output Method 1",
						type = "group",
						order = 3,
						inline = true,
						hidden = function() return (db.profile.SpellDB[spellid].secout < 1) and true or nil end,
						args = AddSecondaryOutput(1),
					},
					out2 = {
						name = "Secondary Output Method 2",
						type = "group",
						order = 4,
						inline = true,
						hidden = function() return (db.profile.SpellDB[spellid].secout < 2) and true or nil end,
						args = AddSecondaryOutput(2),
					},
					out3 = {
						name = "Secondary Output Method 3",
						type = "group",
						order = 5,
						inline = true,
						hidden = function() return (db.profile.SpellDB[spellid].secout < 3) and true or nil end,
						args = AddSecondaryOutput(3),
					},
					out4 = {
						name = "Secondary Output Method 4",
						type = "group",
						order = 6,
						inline = true,
						hidden = function() return (db.profile.SpellDB[spellid].secout < 4) and true or nil end,
						args = AddSecondaryOutput(4),
					},
					out5 = {
						name = "Secondary Output Method 5",
						type = "group",
						order = 7,
						inline = true,
						hidden = function() return (db.profile.SpellDB[spellid].secout < 5) and true or nil end,
						args = AddSecondaryOutput(5),
					},
				},
			},
			buttonOkay = {
				name = "Okay",
				type = "execute",
				order = 100,
				width = "half",
				func = function()
					options.args.spells.args.edit = nil
				end,
			},
			buttonDefaults = {
				name = "Defaults",
				type = "execute",
				order = 101,
				width = "half",
				func = function() addon:ResetSpell(spellid) end,
			},
		},
	}
	tbl.args.output.args.whisper = {
		name = "Always whisper target",
		desc = "Toggle this if you wish to whisper the target of the spell.",
		type = "toggle",
		order = 10,
		disabled = function() return (db.profile.SpellDB[spellid].aoe) and true or nil end,
		set = function(info,val) db.profile.SpellDB[spellid].whisper = val end,
		get = function() return db.profile.SpellDB[spellid].whisper end,
	}
	if not addon.DefaultSpellDB[spellid] then
		-- custom spell
		tbl.args.event = {
			name = "Combat Log Event",
			desc = "Combat Log Event to catch, i.e SPELL_CAST_START. Leave blank if the spell is a buff or debuff!",
			type = "input",
			order = 34,
			width = "normal",
			set = function(info,val) db.profile.SpellDB[spellid].event = (val ~= "") and val or nil end,
			get = function() return db.profile.SpellDB[spellid].event end,
		}
		tbl.args.buttonDefaults = {
			name = "Delete",
			desc = "Remove spell",
			type = "execute",
			order = 101,
			width = "half",
			func = function()
				options.args.spells.args.edit = nil
				
				addon:ResetSpell(spellid)
				
				if(options.args.spells.args.oldlist) then
					options.args.spells.args.list = options.args.spells.args.oldlist
					options.args.spells.args.oldlist = nil
				end
				options.args.spells.args.list.args = module:PopulateSpellList()
			end,
		}
	end
	return tbl
end

function module:SetChannelForm(name)
	local arg = ""
	name = addon:Explode("_", name) -- Underscore is OK since channel names can't contain them
	if(name[1] == "CHANNEL") then
		-- Custom channel
		arg = name[2]
		name = name[1]
	end
	name = (name[2]) and name[2] or name
	if(name == "WHISPER") then
		arg = "TARGET"
	end
	arg = {name, arg}
	return arg
end

function module:GetChannelForm(name)
	local arg = name[2]
	name = name[1]
	if(name == "DISABLE") 		then return ("!0_%s"):format(name) end
	if(name == "GLOBAL") 		then return ("!0_%s"):format(name) end
	if(name == "SELF") 			then return ("!1_%s"):format(name) end
	if(name == "SAY") 			then return ("!2_%s"):format(name) end
	if(name == "YELL") 			then return ("!3_%s"):format(name) end
	if(name == "PARTY") 		then return ("!4_%s"):format(name) end
	if(name == "RAID") 			then return ("!5_%s"):format(name) end
	if(name == "BATTLEGROUND") 	then return ("!6_%s"):format(name) end
	if(name == "WHISPER") 		then return ("!7_%s"):format(name) end
	return ("%s_%s"):format(name,arg)
end

function module:OutputVals(spellid)
	local valtbl = {
		["!0_DISABLE"] = "[Disable]",
		["!1_SELF"] = "Self",
		["!2_SAY"] = "Say",
		["!3_YELL"] = "|cffff4040Yell|r",
		["!4_PARTY"] = "|cffababffParty|r",
		["!5_RAID"] = "|cffff8000Raid|r",
		["!6_BATTLEGROUND"] = "|cffff3d00Battleground|r",
		["!7_WHISPER"] = "Whisper Target",
		["!8_CHANNEL"] = "------------------------------",
	}
	if(spellid) then
		if db.profile.SpellDB[spellid].aoe then
			valtbl["!7_WHISPER"] = nil
		end
		valtbl["!0_GLOBAL"] = "[GLOBAL]"
	end
	-- Find current custom channels
	for i = 1, 20 do
		local name, _, _, _, _, _, category, _, _ = GetChannelDisplayInfo(i);
		if not name then
			break
		end
		if(category == "CHANNEL_CATEGORY_CUSTOM") then
			valtbl["CHANNEL_"..name] = name
		end
	end
	
	return valtbl
end

function module:SetupOutputOptions(spellid)
	if(spellid) then
		if not db.profile.SpellDB[spellid].OutputFlags then
			db.profile.SpellDB[spellid].OutputFlags = {}
		end
	end
	local tbl = {
		header = {
			name = "Output Options",
			type = "header",
			order = 1,
		},
		solo = {
			name = "When Solo:",
			type = "select",
			order = 2,
			values = module:OutputVals(spellid),
			style = "dropdown",
			width = "normal",
			set = function(info,val)
				val = module:SetChannelForm(val) 
				if(spellid) then
					if(val[1] == "GLOBAL") then val = nil end
					db.profile.SpellDB[spellid].OutputFlags[1] = val or nil
				else
					db.profile.OutputFlags[1] = val or nil
				end
			end,
			get = function()
				local v
				if(spellid) then
					if not db.profile.SpellDB[spellid].OutputFlags[1] then
						v = "!0_GLOBAL"
					else
						v = module:GetChannelForm(db.profile.SpellDB[spellid].OutputFlags[1])
					end
				else
					v = module:GetChannelForm(db.profile.OutputFlags[1])
				end
				return v
			end,
		},
		party = {
			name = "When in a Party:",
			type = "select",
			order = 3,
			values = module:OutputVals(spellid),
			style = "dropdown",
			width = "normal",
			set = function(info,val)
				val = module:SetChannelForm(val) 
				if(spellid) then
					if(val[1] == "GLOBAL") then val = nil end
					db.profile.SpellDB[spellid].OutputFlags[2] = val or nil
				else
					db.profile.OutputFlags[2] = val or nil
				end
			end,
			get = function()
				local v
				if(spellid) then
					if not db.profile.SpellDB[spellid].OutputFlags[2] then
						v = "!0_GLOBAL"
					else
						v = module:GetChannelForm(db.profile.SpellDB[spellid].OutputFlags[2])
					end
				else
					v = module:GetChannelForm(db.profile.OutputFlags[2])
				end
				return v
			end,
		},
		raid = {
			name = "When in a Raid:",
			type = "select",
			order = 4,
			values = module:OutputVals(spellid),
			style = "dropdown",
			width = "normal",
			set = function(info,val)
				val = module:SetChannelForm(val) 
				if(spellid) then
					if(val[1] == "GLOBAL") then val = nil end
					db.profile.SpellDB[spellid].OutputFlags[3] = val or nil
				else
					db.profile.OutputFlags[3] = val or nil
				end
			end,
			get = function()
				local v
				if(spellid) then
					if not db.profile.SpellDB[spellid].OutputFlags[3] then
						v = "!0_GLOBAL"
					else
						v = module:GetChannelForm(db.profile.SpellDB[spellid].OutputFlags[3])
					end
				else
					v = module:GetChannelForm(db.profile.OutputFlags[3])
				end
				return v
			end,
		},
		bg = {
			name = "When in a Battleground:",
			type = "select",
			order = 6,
			values = module:OutputVals(spellid),
			style = "dropdown",
			width = "normal",
			set = function(info,val)
				val = module:SetChannelForm(val) 
				if(spellid) then
					if(val[1] == "GLOBAL") then val = nil end
					db.profile.SpellDB[spellid].OutputFlags[4] = val or nil
				else
					db.profile.OutputFlags[4] = val or nil
				end
			end,
			get = function()
				local v
				if(spellid) then
					if not db.profile.SpellDB[spellid].OutputFlags[4] then
						v = "!0_GLOBAL"
					else
						v = module:GetChannelForm(db.profile.SpellDB[spellid].OutputFlags[4])
					end
				else
					v = module:GetChannelForm(db.profile.OutputFlags[4])
				end
				return v
			end,
		},
		wg = {
			name = "When in Wintergrasp or Tol Barad:",
			type = "select",
			order = 7,
			values = module:OutputVals(spellid),
			style = "dropdown",
			width = "normal",
			set = function(info,val)
				val = module:SetChannelForm(val) 
				if(spellid) then
					if(val[1] == "GLOBAL") then val = nil end
					db.profile.SpellDB[spellid].OutputFlags[5] = val or nil
				else
					db.profile.OutputFlags[5] = val or nil
				end
			end,
			get = function()
				local v
				if(spellid) then
					if not db.profile.SpellDB[spellid].OutputFlags[5] then
						v = "!0_GLOBAL"
					else
						v = module:GetChannelForm(db.profile.SpellDB[spellid].OutputFlags[5])
					end
				else
					v = module:GetChannelForm(db.profile.OutputFlags[5])
				end
				return v
			end,
		},
		arena = {
			name = "When in Arena:",
			type = "select",
			order = 5,
			values = module:OutputVals(spellid),
			style = "dropdown",
			width = "normal",
			set = function(info,val)
				val = module:SetChannelForm(val) 
				if(spellid) then
					if(val[1] == "GLOBAL") then val = nil end
					db.profile.SpellDB[spellid].OutputFlags[6] = val or nil
				else
					db.profile.OutputFlags[6] = val or nil
				end
			end,
			get = function()
				local v
				if(spellid) then
					if not db.profile.SpellDB[spellid].OutputFlags[6] then
						v = "!0_GLOBAL"
					else
						v = module:GetChannelForm(db.profile.SpellDB[spellid].OutputFlags[6])
					end
				else
					v = module:GetChannelForm(db.profile.OutputFlags[6])
				end
				return v
			end,
		},
	}
	return tbl
end

function module:RegisterOptions()
	-- xD
	
	options = {
		name = 'WakeSpams',
		type = "group",
		args = {
			general = {
				name = 'WakeSpams',
				type = "group",
				args = {
					enabled = {
						order = 1,
						type = "toggle",
						name = "Enabled",
						desc = "Enable or disable addon.",
						descStyle = "inline",
						set = function(i,v)
							if addon:IsEnabled() then
								addon:Disable()
								db.profile.disabled = true
							else
								addon:Enable()
								db.profile.disabled = false
							end
						end,
						get = function() return addon:IsEnabled() end,
					},
					spellheader = {
						name = "Spell Announcements",
						type = "header",
						order = 10,
					},
					aoe = {
						order = 11,
						type = "toggle",
						name = "AoE",
						desc = "Enable or disable announcements for multitarget spells.",
						descStyle = "inline",
						set = function(v) db.profile.aoe = not db.profile.aoe end,
						get = function() return db.profile.aoe end,
					},
					interrupts = {
						order = 12,
						type = "toggle",
						name = "Interrupts",
						desc = "Enable or disable announcements for interrupts.",
						descStyle = "inline",
						set = function(i,v)
							if not db.profile.EventDB["SPELL_INTERRUPT"] then
								db.profile.EventDB["SPELL_INTERRUPT"] = {}
							end
							db.profile.EventDB["SPELL_INTERRUPT"].disabled = not v
						end,
						get = function()
							if not db.profile.EventDB["SPELL_INTERRUPT"] then
								return true
							else
								return not db.profile.EventDB["SPELL_INTERRUPT"].disabled
							end
						end,
					},
					dispels = {
						order = 13,
						type = "toggle",
						name = "Dispels",
						desc = "Enable or disable announcements for successful dispels.",
						descStyle = "inline",
						set = function(i,v)
							if not db.profile.EventDB["SPELL_DISPEL"] then
								db.profile.EventDB["SPELL_DISPEL"] = {}
							end
							db.profile.EventDB["SPELL_DISPEL"].disabled = not v
						end,
						get = function()
							if not db.profile.EventDB["SPELL_DISPEL"] then
								return true
							else
								return not db.profile.EventDB["SPELL_DISPEL"].disabled
							end
						end,
					},
					dispelresists = {
						order = 14,
						type = "toggle",
						name = "Dispel Resists",
						desc = "Enable or disable announcements for dispel resists.",
						descStyle = "inline",
						set = function(i,v)
							if not db.profile.EventDB["SPELL_DISPEL_FAILED"] then
								db.profile.EventDB["SPELL_DISPEL_FAILED"] = {}
							end
							db.profile.EventDB["SPELL_DISPEL_FAILED"].disabled = not v
						end,
						get = function()
							if not db.profile.EventDB["SPELL_DISPEL_FAILED"] then
								return true
							else
								return not db.profile.EventDB["SPELL_DISPEL_FAILED"].disabled
							end
						end,
					},
					defaults = {
						name = "Edit Defaults",
						type = "header",
						order = 20,
					},
					AbilityStart = {
						name = "",
						type = "group",
						inline = true,
						order = 21,
						args = {
							input = {
								order = 3,
								type = "input",
								name = "Default ability start message",
								desc = "Settings specific to spells override this.",
								width = "full",
								set = function(i,v) db.profile.AbilityStart = (v ~= "") and v or db.profile.AbilityStart end,
								get = function() return db.profile.AbilityStart end,
							},
						},
					},
					AbilityEnd = {
						name = "",
						type = "group",
						inline = true,
						order = 22,
						args = {
							input = {
								order = 3,
								type = "input",
								name = "Default ability end message",
								desc = "Settings specific to spells override this.",
								width = "full",
								set = function(i,v) db.profile.AbilityEnd = (v ~= "") and v or db.profile.AbilityEnd end,
								get = function() return db.profile.AbilityEnd end,
							},
						},
					},
					strreplace = {
						name = "Message Formating Help",
						type = "header",
						order = 30,
					},
					strreplacedesc = {
						name = helptext,
						type = "description",
						fontSize = "medium",
						order = 31,
					},
					output = {
						name = "",
						type = "group",
						order = 35,
						inline = true,
						args = module:SetupOutputOptions(),
					},
					resetheader = {
						name = "Reset To Defaults",
						type = "header",
						order = 40,
					},
					resetbtn = {
						name = "Reset all",
						type = "execute",
						order = 100,
						width = "half",
						confirm = function() return "Reset all WakeSpams settings to default? This also removes any custom spell settings you might have." end,
						func = function()
							db:ResetProfile()
							options.args.spells.args.edit = nil
							if(options.args.spells.args.oldlist) then
								options.args.spells.args.list = options.args.spells.args.oldlist
								options.args.spells.args.oldlist = nil
							end
							options.args.spells.args.list.args = module:PopulateSpellList()
						end,
					},
				},
			},
		},
	}
	
	local function AddSpellDetails(spellid)
		local tbl
		local spell
		spellid = tonumber(spellid)
		if not addon:isNumeric(spellid) then -- Not a number
			tbl = {
				name = "Error: The entered Spell ID is not a number.",
				type = "description",
				order = 2,
				fontSize = "large",
			}
		elseif not GetSpellInfo(spellid) then -- Spell does not exist
			tbl = {
				name = ("Error: Could not find spell with the following Spell ID: %s"):format(spellid),
				type = "description",
				order = 2,
				fontSize = "large",
			}
		elseif ((addon.DefaultSpellDB[spellid]) or (db.profile.SpellDB[spellid])) then -- Already in the list
			spell = GetSpellInfo(spellid)
			tbl = {
				name = "",
				type = "group",
				inline = true,
				order = 2,
				args = {
					description = {
						name = ("Error: \"%s\" is already in the spell list. Do you wish to edit that spell instead?"):format(spell),
						type = "description",
						order = 1,
						fontSize = "large",
					},
					editbtn = {
						name = "Edit",
						type = "execute",
						order = 2,
						func = function()
							if(options.args.spells.args.oldlist) then
								options.args.spells.args.list = options.args.spells.args.oldlist
								options.args.spells.args.oldlist = nil
							else
								options.args.spells.args.oldlist = options.args.spells.args.list
								options.args.spells.args.list = nil
							end
							options.args.spells.args.edit = module:EditSpell(spellid)
						end,
					},
				},
			}
		else
			spell = GetSpellInfo(spellid)
			tbl = {
				name = spell,
				type = "group",
				inline = true,
				order = 2,
				args = {
					description = {
						name = ("Do you wish to let WakeSpams automatically detect the best settings for %s?"):format(spell),
						type = "description",
						order = 1,
						fontSize = "medium",
					},
					autobtn = {
						name = "Automatic",
						type = "execute",
						order = 2,
						func = function()
							addon.db.profile.SpellDB[spellid] = {
								detect = true,
								dur = 0,
								countdown = 0,
							}
							if(options.args.spells.args.oldlist) then
								options.args.spells.args.list = options.args.spells.args.oldlist
								options.args.spells.args.oldlist = nil
							end
							options.args.spells.args.list.args = module:PopulateSpellList()
							options.args.spells.args.add.args.spellDetails = nil
							
							InterfaceOptionsFrame_Show ();
							HideUIPanel(GameMenuFrame);
							StaticPopupDialogs["WS_AUTODETECTSPELL"] = {
							  text = ("WakeSpams\n\nPlease cast %s ONCE."):format(spell),
							  --[[button1 = "Okay",
							  OnAccept = function()
								  return false
							  end,]]
							  timeout = 15,
							  whileDead = 1,
							  hideOnEscape = 1
							}
							StaticPopup_Show("WS_AUTODETECTSPELL")
						end,
					},
					manualbtn = {
						name = "Manual",
						type = "execute",
						order = 3,
						func = function()
							addon.db.profile.SpellDB[spellid] = {
								dur = 0,
								countdown = 0,
							}
							if(options.args.spells.args.oldlist) then
								options.args.spells.args.list = options.args.spells.args.oldlist
								options.args.spells.args.oldlist = nil
							end
							options.args.spells.args.list.args = module:PopulateSpellList()
							options.args.spells.args.add.args.spellDetails = nil
							
							options.args.spells.args.edit = module:EditSpell(spellid)
						end,
					},
				},
			}
		end
		return tbl
	end
	
	local function AddSpell()
		local spellid
		local tbl = {}
		tbl = {
			description = {
				name = "Add Spell",
				type = "group",
				inline = true,
				order = 1,
				args = {
					spellid = {
						name = "Spell ID. You can find Spell IDs for specific spells on WoWhead.",
						type = "input",
						order = 1,
						width = "full",
						get = function() return spellid or "Enter Spell ID #" end,
						set = function(i,v) spellid = v tbl.spellDetails = AddSpellDetails(spellid) return v end,
					},
				},
			},
		}
		return tbl
	end
	
	local function PopulateClassOptions()
		local tbl
		tbl = {
			name = 'spells',
			type = "group",
			desc = "Spells",
			childGroups = "tab",
			args = {
				add = {
					name = "Add Spell",
					type = "group",
					desc = "Add spell",
					order = 3,
					args = AddSpell(),
				},
				list = {
					name = "Spell List",
					type = "group",
					desc = "Spell list",
					order = 2,
					args = module:PopulateSpellList(),
				},
			},
		}
		if not addon.DefaultSpellDB then
			local class, _ = UnitClass("player");
			tbl.args.list.args.info = {
				type = "description",
				name = ("There are no preconfigured %s spells. To add a spell, click the  \"Add Spell\" button."):format(class),
				order = 100,
			}
		end
		return tbl
	end
	
	local function PopulateEventOptions()
		local tbl
		tbl = {
			name = 'event',
			type = "group",
			desc = "Event Announcement",
			childGroups = "tab",
			args = module:PopulateEventList(),
		}
		tbl.args.strreplace = {
			name = "Message Formating Help",
			type = "header",
			order = 30,
		}
		tbl.args.strreplacedesc = {
			name = helptext,
			type = "description",
			fontSize = "medium",
			order = 31,
		}
		return tbl
	end
	
	options.args.spells = PopulateClassOptions()
	
	options.args.events = PopulateEventOptions()
	
	options.args.help = {
		type = "group",
		name = "Help",
		args = {
			strreplace = {
				name = "Message Formating Help",
				type = "header",
				order = 1,
			},
			strreplacedesc = {
				name = helptext,
				type = "description",
				fontSize = "medium",
				order = 2,
			},
		},
	}
	
	options.args.profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(db)
end

function module:ShowConfig()
	InterfaceOptionsFrame_OpenToCategory(self.InterfaceOptions)
end

function module:OnInitialize()
	db = addon.db
	self:RegisterOptions()
	ACR:RegisterOptionsTable("WakeSpams", options)
	
	self.InterfaceOptions = ACD:AddToBlizOptions("WakeSpams", "WakeSpams", nil, "general")
	ACD:AddToBlizOptions("WakeSpams", "Event Announcement", "WakeSpams", "events")
	local class, _ = UnitClass("player");
	ACD:AddToBlizOptions("WakeSpams", class, "WakeSpams", "spells")
	ACD:AddToBlizOptions("WakeSpams", "Help", "WakeSpams", "help")
	ACD:AddToBlizOptions("WakeSpams", "Profiles", "WakeSpams", "profiles")
	LibStub("LibAboutPanel").new("WakeSpams", "WakeSpams")
end