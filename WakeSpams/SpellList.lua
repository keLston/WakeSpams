local addon = WakeSpams
local module = addon:NewModule("Spells")
WakeSpams.Spells = module

function module:InitSpellDB()
	local _, class = UnitClass("player");
	assert(class, "Error: WakeSpams was unable to retrieve player englishclass.")
	
	--[[
		SpellList args:
		Spell ID {
			disabled = boolean
			name = string (optional) custom spell name
			txt = string (optional) message on start
			txtend = string (optional) message on end8
			dur = int (optional) spell duration
			countdown = int (optional) fade countdown in chat
			fade = boolean (optional) announce when spell fades
			whisper = boolean
			aoe = boolean
			output = string (optional) output channel
			event = string (optional) event name
			configname = string (optional) name that will show up in the config
			
			hastarget = boolean
			hasextra = boolean
			hasduration = boolean
			
			fademode = int (optional) 1 = check other spell. Currently: Other spell must be present as DB spell.
										  If other spell fires, it will use message FROM THAT SPELL. Fade message from original spell wont fire. This is cheap, but easy.
									  2 = Check previous spell
			[	fadearg = str/int/bool - If fademode = 1, then fadearg must be spell ID (int)]
		}
	]]
	addon.DefaultSpellDB = {}
	
	if(class == "DEATHKNIGHT") then
		addon.DefaultSpellDB = {
			[48792] = { -- Icebound Fortitude
				dur = 12,
				countdown = 0,
				fade = true,
			},
			[55233] = { -- Vampiric Blood
				dur = 10,
				countdown = 0,
				fade = true,
			},
			[56222] = { -- Dark Command taunt
				txt = "Taunt Failed: spell:link on spell:target (spell:extra)",
				event = "SPELL_MISSED",
			},
			[49560] = { -- Death Grip (taunt component)
				txt = "Taunt Failed: spell:link on spell:target (spell:extra)",
				event = "SPELL_MISSED",
			},
			[49016] = { -- Unholy Frenzy (whisper)
				txt = "Activated: spell:link on spell:target - spell:durations!",
				dur = 30,
				whisper = true,
				countdown = 0,
				fade = true,
			},
			[47476] = { -- Strangulate
				txt = "spell:link: spell:target",
			},
		}
	end
	
	if(class == "DRUID") then
		addon.DefaultSpellDB = {
			[22812] = { -- Barkskin
				dur = 12,
				countdown = 0,
				fade = true,
			},
			[61336] = { -- Survival Instincts
				dur = 12,
				countdown = 0,
				fade = true,
			},
			[29166] = { -- Innervate (whisper)
				txt = "Activated: spell:link on spell:target - spell:durations!",
				dur = 10,
				countdown = 0,
				fade = true,
				whisper = true,
			},
			[5211] = { -- Bash
				txt = "Activated: spell:link on spell:target!",
				countdown = 0,
				fade = true,
			},
			[20484] = { -- Rebirth
				txt = "spell:link on spell:target!",
				event = "SPELL_RESURRECT",
			},
			[50769] = { -- Revive
				txt = "Casting: spell:link on spell:target",
				event = "UNIT_SPELLCAST_START",
			},
		}
	end
	
	if(class == "HUNTER") then
		addon.DefaultSpellDB = {
			[34477] = { -- Misdirection (cast... Not tested)
				txt = "spell:link on spell:target!",
				event = "SPELL_CAST_SUCCESS",
				whisper = true,
			},
			-- Pet Abilities
			[90355] = { -- Ancient Hysteria
				txt = "Activated: spell:link spell:durations!",
				dur = 40,
				countdown = 0,
				aoe = true,
			},
			[53480] = { -- Roar of Sacrifice
				txt = "Activated: spell:link on spell:target - spell:durations!",
				dur = 12,
				countdown = 0,
			},
		}
	end
	
	if(class == "MAGE") then
		addon.DefaultSpellDB = {
			[80353] = { -- Time warp
				txt = "Activated: spell:link spell:durations!",
				dur = 40,
				countdown = 0,
				aoe = true,
			},
		}
	end
	
	if(class == "PALADIN") then
		addon.DefaultSpellDB = {
			--[[
			[20233] = { -- Lay on Hands (holy phys. damage reduction only. Right spell id?)
				txt = "Activated: spell:link on spell:target - spell:durations!",
				dur = 15,
				countdown = 0,
				fade = true,
			},]]
			[31821] = { -- Devotion Aura
				dur = 6,
				countdown = 0,
				fade = true,
			},
			[498] = { -- Divine Protection
				dur = 10,
				countdown = 0,
				fade = true,
			},
			[66235] = { -- Ardent Defender proc
				txt = "spell:link saved me! Healed spell:amount!",
				event = "SPELL_HEAL",
			},
			[853] = { -- Hammer of Justice
				txt = "Activated: spell:link on spell:target!",
				countdown = 0,
				fade = true,
			},
			[2812] = { -- Holy Wrath
				dur = 3,
				countdown = 0,
				fade = true,
				aoe = true,
			},
			[1044] = { -- Hand of Freedom
				txt = "spell:link on spell:target - spell:durations!",
				dur = 6,
				whisper = true,
			},
			[1022] = { -- Hand of Protection
				txt = "Activated: spell:link on spell:target - spell:durations!",
				dur = 10,
			},
			[6940] = { -- Hand of Sacrifice
				txt = "Activated: spell:link on spell:target - spell:durations!",
				dur = 12,
				countdown = 0,
				fade = true,
			},
			[1038] = { -- Hand of Salvation (whisper)
				dur = 10,
				txt = "Activated: spell:link on spell:target - spell:durations!",
				countdown = 0,
				fade = true,
				whisper = true,
			},
			[7328] = { -- Redemption
				txt = "Casting: spell:link on spell:target",
				event = "UNIT_SPELLCAST_START",
			},
		}
	end
	
	if(class == "PRIEST") then
		addon.DefaultSpellDB = {
			[65081] = { -- Body and Soul (target effect triggered by body and soul)
				txt = "spell:link on spell:target - meep meep!",
				dur = 4,
				whisper = true,
			},
			[8122] = { -- Psychic Scream
				dur = 8,
				aoe = true,
			},
			[10060] = { -- Power Infusion
				txt = "Activated: spell:link spell:durations!",
				dur = 20,
				fade = true,
			},
			[64901] = { -- Hymn of Hope
				txt = "Activated: spell:link!",
				event = "SPELL_CAST_SUCCESS",
			},
			[47788] = { -- Guardian Spirit
				txt = "Activated: spell:link on spell:target - spell:durations!",
				txtend = "Faded (normal): spell:link from spell:target",
				dur = 10,
				countdown = 2,
				fade = true,
				advfade = "1",
				fademode = 1,
				fadearg = 48153,
			},
			[48153] = { -- Guardian Spirit (heal)
				txt = "Faded (PROCCED): spell:link healed spell:target for spell:amount",
				event = "SPELL_HEAL",
				configname = "Guardian Spirit (heal effect)",
				fademode = 2,
				fadearg = 47788,
			},
			[33206] = { -- Pain Suppression
				txt = "Activated: spell:link on spell:target - spell:durations!",
				dur = 8,
				fade = true,
			},
			[64843] = { -- Divine Hymn
				txt = "Activated: spell:link!",
				event = "SPELL_CAST_SUCCESS",
			},
			[2006] = { -- Resurrection
				txt = "Casting: spell:link on spell:target",
				event = "UNIT_SPELLCAST_START",
			},
		}
	end
	
	if(class == "ROGUE") then
		addon.DefaultSpellDB = {
			[57934] = { -- Tricks of the Trade (cast... Not tested)
				txt = "spell:link on spell:target!",
				dur = 6,
				event = "SPELL_CAST_SUCCESS",
				whisper = true,
			},
			[1833] = { -- Cheap Shot
				txt = "Activated: spell:link on spell:target!",
				countdown = 0,
				fade = true,
			},
			[408] = { -- Kidney Shot
				txt = "Activated: spell:link on spell:target!",
				countdown = 0,
				fade = true,
			},
		}
	end
	
	if(class == "SHAMAN") then
		addon.DefaultSpellDB = {
			[2825] = { -- Bloodlust
				txt = "Activated: spell:link spell:durations!",
				dur = 40,
				countdown = 0,
				aoe = true,
			},
			[32182] = { -- Heroism
				txt = "Activated: spell:link spell:durations!",
				dur = 40,
				countdown = 0,
				aoe = true,
			},
			[2008] = { -- Ancestral Spirit
				txt = "Casting: spell:link on spell:target",
				event = "UNIT_SPELLCAST_START",
			},
		}
	end
	
	if(class == "WARRIOR") then
		addon.DefaultSpellDB = {
			[355] = { -- Taunt taunt
				txt = "Taunt Failed: spell:link on spell:target (spell:extra)",
				event = "SPELL_MISSED",
			},
			[871] = { -- Shield Wall
				dur = 12,
				countdown = 0,
				fade = true,
			},
			[12975] = { -- Last Stand
				dur = 20,
				countdown = 0,
				fade = true,
			},
			[46968] = { -- Shockwave
				dur = 4,
				countdown = 0,
				fade = true,
				aoe = true,
			},
		}
	end
	
	if(class == "WARLOCK") then
		addon.DefaultSpellDB = {
			[1122] = { -- Summon Infernal
				txt = "Activated: spell:link!",
				countdown = 0,
				fade = true,
				event = "SPELL_CAST_SUCCESS",
			},
			[5484] = { -- Howl of Terror
				dur = 8,
				aoe = true,
			},
		}
	end
	
	addon.DefaultEventDB = {
		["SPELL_DISPEL"] = {
			configname = "Dispels                (Event: SPELL_DISPEL)",
			txt = "spell:link Removed: spell:extra:link from spell:target",
		},
		["SPELL_DISPEL_FAILED"] = {
			configname = "Dispel Resists         (Event: SPELL_DISPEL_FAILED)",
			txt = "spell:link Dispel Failed: spell:extra:link from spell:target",
		},
		["SPELL_INTERRUPT"] = {
			configname = "Interrupts             (Event: SPELL_INTERRUPT)",
			txt = "spell:link Interrupted: spell:target spell:extra:link",
		},
	}
end

module:InitSpellDB()
