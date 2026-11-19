-- DreamScore spec weights (generated from guide research; weights are judgment calls, see each source line).
-- SPECS[CLASS][talent tree] = { name, source, w = { statKey = weight } }; BEAR is the Feral bear-form variant.
local DS = DreamSuite
local S = {}

do
local t = (function()
return {
  WARRIOR = {
    [1] = { name = "Arms", source = "Icy Veins + Legacy-WoW/Warcraft Tavern (WotLK stat priority); numeric spacing is a judgment call", w = {
        ITEM_MOD_ATTACK_POWER_SHORT = 1.0,
        ITEM_MOD_STRENGTH_SHORT = 2.2,            -- 2 AP per Str plus raid buffs
        ITEM_MOD_AGILITY_SHORT = 1.4,             -- AP + crit
        ITEM_MOD_HIT_RATING_SHORT = 2.5,          -- normal pre-cap value (cap 8% / 263)
        ITEM_MOD_EXPERTISE_RATING_SHORT = 1.8,    -- target ~18 expertise
        ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT = 1.4,
        ITEM_MOD_CRIT_RATING_SHORT = 1.5,
        ITEM_MOD_HASTE_RATING_SHORT = 0.6,        -- lowest priority for Arms
        ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 8.0,   -- slow 2H weapon; estimate
        RESISTANCE0_NAME = 0.03,                  -- Armored to the Teeth: 3 AP / 108 armor
    } },
    [2] = { name = "Fury", source = "Icy Veins + Warcraft Tavern (WotLK stat priority); numeric spacing is a judgment call", w = {
        ITEM_MOD_ATTACK_POWER_SHORT = 1.0,
        ITEM_MOD_STRENGTH_SHORT = 2.4,            -- ~2.64 AP/Str with talents + Kings per Tavern
        ITEM_MOD_AGILITY_SHORT = 1.5,
        ITEM_MOD_HIT_RATING_SHORT = 2.6,          -- cap 8% (263) less Precision
        ITEM_MOD_EXPERTISE_RATING_SHORT = 2.2,
        ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT = 1.5,
        ITEM_MOD_CRIT_RATING_SHORT = 1.6,
        ITEM_MOD_HASTE_RATING_SHORT = 0.9,
        ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 5.0,   -- dual wield; estimate
        RESISTANCE0_NAME = 0.028,
    } },
    [3] = { name = "Protection", source = "Icy Veins + Warcraft Tavern (WotLK tank stat priority); numeric spacing is a judgment call", w = {
        ITEM_MOD_DEFENSE_SKILL_RATING_SHORT = 1.0, -- 1.0 stat: defense rating (540 crit immunity)
        ITEM_MOD_STAMINA_SHORT = 0.9,
        RESISTANCE0_NAME = 0.06,
        ITEM_MOD_HIT_RATING_SHORT = 0.7,
        ITEM_MOD_EXPERTISE_RATING_SHORT = 0.6,
        ITEM_MOD_BLOCK_RATING_SHORT = 0.5,
        ITEM_MOD_BLOCK_VALUE_SHORT = 0.4,
        ITEM_MOD_DODGE_RATING_SHORT = 0.5,
        ITEM_MOD_PARRY_RATING_SHORT = 0.4,
        ITEM_MOD_STRENGTH_SHORT = 0.35,
        ITEM_MOD_AGILITY_SHORT = 0.5,
        ITEM_MOD_ATTACK_POWER_SHORT = 0.15,
        ITEM_MOD_CRIT_RATING_SHORT = 0.25,
    } },
  },
  PALADIN = {
    [1] = { name = "Holy", source = "Icy Veins + Warcraft Tavern (WotLK healer stat priority); numeric spacing is a judgment call", w = {
        ITEM_MOD_SPELL_POWER_SHORT = 1.0,
        ITEM_MOD_INTELLECT_SHORT = 1.2,           -- mana + crit + Holy Guidance (20% of Int as SP)
        ITEM_MOD_HASTE_RATING_SHORT = 0.9,
        ITEM_MOD_MANA_REGENERATION_SHORT = 0.8,   -- mp5
        ITEM_MOD_CRIT_RATING_SHORT = 0.5,         -- low priority
    } },
    [2] = { name = "Protection", source = "Icy Veins + Warcraft Tavern (WotLK tank stat priority); numeric spacing is a judgment call", w = {
        ITEM_MOD_DEFENSE_SKILL_RATING_SHORT = 1.0, -- 1.0 stat: defense rating (540 cap)
        ITEM_MOD_STAMINA_SHORT = 0.9,
        ITEM_MOD_BLOCK_RATING_SHORT = 0.8,
        ITEM_MOD_BLOCK_VALUE_SHORT = 0.6,
        ITEM_MOD_HIT_RATING_SHORT = 0.8,          -- Tavern ranks hit/expertise first for threat
        ITEM_MOD_EXPERTISE_RATING_SHORT = 0.7,
        ITEM_MOD_DODGE_RATING_SHORT = 0.7,
        ITEM_MOD_PARRY_RATING_SHORT = 0.5,
        RESISTANCE0_NAME = 0.06,
        ITEM_MOD_STRENGTH_SHORT = 0.5,
        ITEM_MOD_AGILITY_SHORT = 0.4,
        ITEM_MOD_ATTACK_POWER_SHORT = 0.2,
        ITEM_MOD_SPELL_POWER_SHORT = 0.25,
    } },
    [3] = { name = "Retribution", source = "Icy Veins + Warcraft Tavern (WotLK stat priority); numeric spacing is a judgment call", w = {
        ITEM_MOD_ATTACK_POWER_SHORT = 1.0,
        ITEM_MOD_STRENGTH_SHORT = 2.2,            -- 2.2 AP/Str with Divine Strength (Icy Veins)
        ITEM_MOD_AGILITY_SHORT = 1.3,
        ITEM_MOD_HIT_RATING_SHORT = 2.5,
        ITEM_MOD_EXPERTISE_RATING_SHORT = 2.2,
        ITEM_MOD_CRIT_RATING_SHORT = 1.5,
        ITEM_MOD_HASTE_RATING_SHORT = 1.2,
        ITEM_MOD_SPELL_POWER_SHORT = 0.35,
        ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT = 0.7, -- last on both guides
        ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 7.0,   -- estimate
    } },
  },
}
end)()
for k, v in pairs(t) do
  if S[k] then for tab, e in pairs(v) do S[k][tab] = e end else S[k] = v end
end
end

do
local t = (function()
return {
  HUNTER = {
    [1] = { name = "Beast Mastery", source = "Icy Veins + Warcraft Tavern (WotLK Classic stat priority)", w = {
        ITEM_MOD_ATTACK_POWER_SHORT = 1.0,
        ITEM_MOD_RANGED_ATTACK_POWER_SHORT = 1.0,
        ITEM_MOD_AGILITY_SHORT = 2.0,   -- guides: ~2 AP per agi on gear budget
        ITEM_MOD_HIT_RATING_SHORT = 2.4, -- pre-cap, top priority
        ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT = 1.0,
        ITEM_MOD_CRIT_RATING_SHORT = 1.1,
        ITEM_MOD_HASTE_RATING_SHORT = 0.6, -- weakest
        ITEM_MOD_INTELLECT_SHORT = 0.3,
        ITEM_MOD_STAMINA_SHORT = 0.1,
        ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 8.0, -- ranged weapon DPS (judgment)
    } },
    [2] = { name = "Marksmanship", source = "Icy Veins + Warcraft Tavern (WotLK Classic stat priority)", w = {
        ITEM_MOD_ATTACK_POWER_SHORT = 1.0,
        ITEM_MOD_RANGED_ATTACK_POWER_SHORT = 1.0,
        ITEM_MOD_AGILITY_SHORT = 2.2,
        ITEM_MOD_HIT_RATING_SHORT = 2.4,
        ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT = 1.5, -- best secondary for MM
        ITEM_MOD_CRIT_RATING_SHORT = 1.2,
        ITEM_MOD_HASTE_RATING_SHORT = 0.6,
        ITEM_MOD_INTELLECT_SHORT = 0.3,
        ITEM_MOD_STAMINA_SHORT = 0.1,
        ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 8.0,
    } },
    [3] = { name = "Survival", source = "Icy Veins + Warcraft Tavern (WotLK Classic stat priority)", w = {
        ITEM_MOD_ATTACK_POWER_SHORT = 1.0,
        ITEM_MOD_RANGED_ATTACK_POWER_SHORT = 1.0,
        ITEM_MOD_AGILITY_SHORT = 2.4,   -- "best stat by a mile"
        ITEM_MOD_HIT_RATING_SHORT = 2.4,
        ITEM_MOD_CRIT_RATING_SHORT = 1.6,
        ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT = 0.6, -- low value for Survival
        ITEM_MOD_HASTE_RATING_SHORT = 0.5,
        ITEM_MOD_INTELLECT_SHORT = 0.3,
        ITEM_MOD_STAMINA_SHORT = 0.35,  -- Survival converts stamina to AP (judgment)
        ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 8.0,
    } },
  },
  ROGUE = {
    [1] = { name = "Assassination", source = "Icy Veins + Warcraft Tavern (WotLK Classic stat priority)", w = {
        ITEM_MOD_ATTACK_POWER_SHORT = 1.0,
        ITEM_MOD_AGILITY_SHORT = 1.8,
        ITEM_MOD_STRENGTH_SHORT = 0.9,
        ITEM_MOD_HIT_RATING_SHORT = 2.5,
        ITEM_MOD_EXPERTISE_RATING_SHORT = 2.0,
        ITEM_MOD_HASTE_RATING_SHORT = 1.5,
        ITEM_MOD_CRIT_RATING_SHORT = 1.2,
        ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT = 0.7, -- sources agree it is low for Assassination
        ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 4.0, -- judgment (dagger DPS)
    } },
    [2] = { name = "Combat", source = "Icy Veins + Warcraft Tavern (WotLK Classic stat priority)", w = {
        ITEM_MOD_ATTACK_POWER_SHORT = 1.0,
        ITEM_MOD_AGILITY_SHORT = 1.8,
        ITEM_MOD_STRENGTH_SHORT = 0.9,
        ITEM_MOD_HIT_RATING_SHORT = 2.5,
        ITEM_MOD_EXPERTISE_RATING_SHORT = 2.2,
        ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT = 1.6,
        ITEM_MOD_HASTE_RATING_SHORT = 1.3,
        ITEM_MOD_CRIT_RATING_SHORT = 1.1,
        ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 5.0,
    } },
    [3] = { name = "Subtlety", source = "Icy Veins (WotLK Classic stat priority); no second source fetched", w = {
        ITEM_MOD_ATTACK_POWER_SHORT = 1.0,
        ITEM_MOD_AGILITY_SHORT = 1.8,
        ITEM_MOD_STRENGTH_SHORT = 0.9,
        ITEM_MOD_HIT_RATING_SHORT = 2.5,
        ITEM_MOD_EXPERTISE_RATING_SHORT = 2.0,
        ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT = 1.4,
        ITEM_MOD_HASTE_RATING_SHORT = 1.3,
        ITEM_MOD_CRIT_RATING_SHORT = 1.1,
        ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 4.5,
    } },
  },
}
end)()
for k, v in pairs(t) do
  if S[k] then for tab, e in pairs(v) do S[k][tab] = e end else S[k] = v end
end
end

do
local t = (function()
return {
  PRIEST = {
    [1] = { name = "Discipline", source = "Icy Veins + Warcraft Tavern (WotLK Classic stat priority)", w = {
        ITEM_MOD_SPELL_POWER_SHORT = 1.0,
        ITEM_MOD_HASTE_RATING_SHORT = 1.0,   -- #1 until soft cap (154-434 rating), judgment: ~SP
        ITEM_MOD_CRIT_RATING_SHORT = 0.8,
        ITEM_MOD_INTELLECT_SHORT = 0.6,
        ITEM_MOD_SPIRIT_SHORT = 0.4,
        ITEM_MOD_MANA_REGENERATION_SHORT = 0.3,
    } },
    [2] = { name = "Holy", source = "Icy Veins + Warcraft Tavern (WotLK Classic stat priority)", w = {
        ITEM_MOD_SPELL_POWER_SHORT = 1.0,
        ITEM_MOD_HASTE_RATING_SHORT = 1.1,   -- Icy: haste > int > SP > spirit > crit > mp5
        ITEM_MOD_INTELLECT_SHORT = 1.05,     -- Tavern ranks SP first; compromise
        ITEM_MOD_SPIRIT_SHORT = 0.8,
        ITEM_MOD_CRIT_RATING_SHORT = 0.7,
        ITEM_MOD_MANA_REGENERATION_SHORT = 0.35,
    } },
    [3] = { name = "Shadow", source = "Icy Veins + Warcraft Tavern (WotLK Classic stat priority)", w = {
        ITEM_MOD_SPELL_POWER_SHORT = 1.0,
        ITEM_MOD_HIT_RATING_SHORT = 1.3,     -- pre-cap value (cap 263-289 rating)
        ITEM_MOD_HASTE_RATING_SHORT = 0.85,
        ITEM_MOD_CRIT_RATING_SHORT = 0.65,
        ITEM_MOD_SPIRIT_SHORT = 0.3,         -- 1 Spirit = 0.2 SP (Icy) plus some regen
        ITEM_MOD_INTELLECT_SHORT = 0.45,
    } },
  },
  DEATHKNIGHT = {
    -- Blood = TANK; Defense rating = 1.0
    [1] = { name = "Blood", source = "Icy Veins + Warcraft Tavern (WotLK Classic tank stat priority)", w = {
        ITEM_MOD_DEFENSE_SKILL_RATING_SHORT = 1.0,
        ITEM_MOD_HIT_RATING_SHORT = 0.8,     -- taunt/spell hit cap; Tavern ranks it #1
        ITEM_MOD_STAMINA_SHORT = 0.8,
        ITEM_MOD_EXPERTISE_RATING_SHORT = 0.7,
        ITEM_MOD_DODGE_RATING_SHORT = 0.7,
        ITEM_MOD_PARRY_RATING_SHORT = 0.6,
        ITEM_MOD_STRENGTH_SHORT = 0.5,       -- Strength gives parry + AP; Tavern ranks below parry/dodge
        ITEM_MOD_AGILITY_SHORT = 0.4,
        ITEM_MOD_ATTACK_POWER_SHORT = 0.15,
        ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT = 0.1,
        RESISTANCE0_NAME = 0.05,
    } },
    [2] = { name = "Frost", source = "Icy Veins + Warcraft Tavern (WotLK Classic stat priority)", w = {
        ITEM_MOD_ATTACK_POWER_SHORT = 1.0,
        ITEM_MOD_STRENGTH_SHORT = 2.4,       -- 2 AP per point + Unbreakable Armor/buffs
        ITEM_MOD_HIT_RATING_SHORT = 2.0,
        ITEM_MOD_EXPERTISE_RATING_SHORT = 1.9,
        ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT = 1.0,
        ITEM_MOD_CRIT_RATING_SHORT = 0.9,
        ITEM_MOD_AGILITY_SHORT = 0.8,
        ITEM_MOD_HASTE_RATING_SHORT = 0.7,
        ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 2.5, -- judgment call; guides give no number
    } },
    [3] = { name = "Unholy", source = "Icy Veins + Warcraft Tavern (WotLK Classic stat priority)", w = {
        ITEM_MOD_ATTACK_POWER_SHORT = 1.0,
        ITEM_MOD_STRENGTH_SHORT = 2.4,
        ITEM_MOD_HIT_RATING_SHORT = 2.0,
        ITEM_MOD_HASTE_RATING_SHORT = 1.0,   -- Icy #3; minions get full benefit
        ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT = 0.9,
        ITEM_MOD_CRIT_RATING_SHORT = 0.85,
        ITEM_MOD_EXPERTISE_RATING_SHORT = 1.4, -- Icy last, Tavern #2; compromise
        ITEM_MOD_AGILITY_SHORT = 0.6,
        ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 2.5, -- judgment call
    } },
  },
}
end)()
for k, v in pairs(t) do
  if S[k] then for tab, e in pairs(v) do S[k][tab] = e end else S[k] = v end
end
end

do
local t = (function()
return {
  SHAMAN = {
    [1] = { name = "Elemental", source = "Icy Veins + Warcraft Tavern (WotLK Classic stat priority)", w = {
        ITEM_MOD_SPELL_POWER_SHORT = 1.0,
        ITEM_MOD_HIT_RATING_SHORT = 1.3,        -- both sources rank hit first (pre-cap value)
        ITEM_MOD_HASTE_RATING_SHORT = 0.95,
        ITEM_MOD_CRIT_RATING_SHORT = 0.7,
        ITEM_MOD_INTELLECT_SHORT = 0.45,
        ITEM_MOD_MANA_REGENERATION_SHORT = 0.1, -- Icy Veins lists mp5 last
    } },
    [2] = { name = "Enhancement", source = "Icy Veins + Warcraft Tavern (WotLK Classic stat priority)", w = {
        ITEM_MOD_ATTACK_POWER_SHORT = 1.0,
        ITEM_MOD_HIT_RATING_SHORT = 2.2,
        ITEM_MOD_EXPERTISE_RATING_SHORT = 2.0,
        ITEM_MOD_HASTE_RATING_SHORT = 1.6,
        ITEM_MOD_AGILITY_SHORT = 1.5,
        ITEM_MOD_CRIT_RATING_SHORT = 1.2,
        ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT = 0.8,
        ITEM_MOD_STRENGTH_SHORT = 0.7,
        ITEM_MOD_INTELLECT_SHORT = 0.5,
        ITEM_MOD_SPELL_POWER_SHORT = 0.4,
        ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 6.0, -- judgment call; no source gives a number
    } },
    [3] = { name = "Restoration", source = "Icy Veins + Warcraft Tavern (WotLK Classic stat priority)", w = {
        ITEM_MOD_SPELL_POWER_SHORT = 1.0,
        ITEM_MOD_INTELLECT_SHORT = 1.1,
        ITEM_MOD_HASTE_RATING_SHORT = 1.0,
        ITEM_MOD_MANA_REGENERATION_SHORT = 0.9, -- one source 1.5, other ranks it last; compromise
        ITEM_MOD_CRIT_RATING_SHORT = 0.8,
        ITEM_MOD_SPIRIT_SHORT = 0.1,            -- "generally avoid"
    } },
  },
  MAGE = {
    [1] = { name = "Arcane", source = "Icy Veins + Warcraft Tavern (WotLK Classic stat priority)", w = {
        ITEM_MOD_SPELL_POWER_SHORT = 1.0,
        ITEM_MOD_HIT_RATING_SHORT = 1.6,
        ITEM_MOD_CRIT_RATING_SHORT = 0.8,
        ITEM_MOD_HASTE_RATING_SHORT = 0.8,
        ITEM_MOD_SPIRIT_SHORT = 0.6,
        ITEM_MOD_INTELLECT_SHORT = 0.7,         -- Mind Mastery makes int better than listed rank suggests
        ITEM_MOD_MANA_REGENERATION_SHORT = 0.3,
    } },
    [2] = { name = "Fire", source = "Icy Veins + Warcraft Tavern (WotLK Classic stat priority)", w = {
        ITEM_MOD_SPELL_POWER_SHORT = 1.0,
        ITEM_MOD_HIT_RATING_SHORT = 1.7,
        ITEM_MOD_CRIT_RATING_SHORT = 0.85,
        ITEM_MOD_HASTE_RATING_SHORT = 0.8,
        ITEM_MOD_SPIRIT_SHORT = 0.5,            -- Molten Armor converts spirit to crit
        ITEM_MOD_INTELLECT_SHORT = 0.7,
    } },
    [3] = { name = "Frost", source = "Icy Veins + Warcraft Tavern (WotLK Classic stat priority)", w = {
        ITEM_MOD_SPELL_POWER_SHORT = 1.0,
        ITEM_MOD_HIT_RATING_SHORT = 1.7,
        ITEM_MOD_HASTE_RATING_SHORT = 0.9,
        ITEM_MOD_CRIT_RATING_SHORT = 0.8,
        ITEM_MOD_SPIRIT_SHORT = 0.45,
        ITEM_MOD_INTELLECT_SHORT = 0.65,
    } },
  },
}
end)()
for k, v in pairs(t) do
  if S[k] then for tab, e in pairs(v) do S[k][tab] = e end else S[k] = v end
end
end

do
local t = (function()
return {
  WARLOCK = {
    [1] = { name = "Affliction", source = "Icy Veins + Warcraft Tavern (WotLK Classic stat priority)", w = {
        ITEM_MOD_SPELL_POWER_SHORT = 1.0,
        ITEM_MOD_HIT_RATING_SHORT = 1.6,   -- pre-cap value; priority #1 to cap
        ITEM_MOD_HASTE_RATING_SHORT = 0.95,
        ITEM_MOD_CRIT_RATING_SHORT = 0.75,
        ITEM_MOD_SPIRIT_SHORT = 0.45,      -- ~0.5 SP via Fel Armor + Glyph of Life Tap (Tavern 0.55)
        ITEM_MOD_INTELLECT_SHORT = 0.25,
    } },
    [2] = { name = "Demonology", source = "Icy Veins + Warcraft Tavern (WotLK Classic stat priority)", w = {
        ITEM_MOD_SPELL_POWER_SHORT = 1.0,  -- also feeds Demonic Pact
        ITEM_MOD_HIT_RATING_SHORT = 1.6,
        ITEM_MOD_HASTE_RATING_SHORT = 0.9,
        ITEM_MOD_SPIRIT_SHORT = 0.6,       -- Tavern ~0.59 SP/spirit (support spec, Demonic Pact)
        ITEM_MOD_CRIT_RATING_SHORT = 0.75,
        ITEM_MOD_INTELLECT_SHORT = 0.3,
    } },
    [3] = { name = "Destruction", source = "Warcraft Tavern (WotLK Classic stat priority); Icy Veins page for Destro not fetchable", w = {
        ITEM_MOD_SPELL_POWER_SHORT = 1.0,
        ITEM_MOD_HIT_RATING_SHORT = 1.6,
        ITEM_MOD_HASTE_RATING_SHORT = 1.0, -- haste ~ crit, haste better in later gear
        ITEM_MOD_CRIT_RATING_SHORT = 0.9,
        ITEM_MOD_SPIRIT_SHORT = 0.4,       -- Tavern ~0.3-0.5 SP/spirit
        ITEM_MOD_INTELLECT_SHORT = 0.3,
    } },
  },
  DRUID = {
    [1] = { name = "Balance", source = "Icy Veins + Warcraft Tavern (WotLK Classic stat priority)", w = {
        ITEM_MOD_SPELL_POWER_SHORT = 1.0,
        ITEM_MOD_HIT_RATING_SHORT = 1.6,   -- pre-cap value
        ITEM_MOD_HASTE_RATING_SHORT = 1.0, -- soft cap ~401-585 rating, not modelled
        ITEM_MOD_CRIT_RATING_SHORT = 0.85,
        ITEM_MOD_INTELLECT_SHORT = 0.5,    -- crit + Lunar Guidance 12% to SP
        ITEM_MOD_SPIRIT_SHORT = 0.35,      -- Imp. Moonkin Form 30% to SP
        ITEM_MOD_MANA_REGENERATION_SHORT = 0.1,
    } },
    [2] = { name = "Feral (cat)", source = "Warcraft Tavern sim values (DPS per point, normalized to AP) cross-checked with Icy Veins priority", w = {
        ITEM_MOD_ATTACK_POWER_SHORT = 1.0,
        ITEM_MOD_FERAL_ATTACK_POWER_SHORT = 1.2,
        ITEM_MOD_STRENGTH_SHORT = 2.4,
        ITEM_MOD_AGILITY_SHORT = 2.45,
        ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT = 2.5, -- sim 3.0; tempered since 1400 cap is hard to reach
        ITEM_MOD_HIT_RATING_SHORT = 2.8,
        ITEM_MOD_EXPERTISE_RATING_SHORT = 2.8,
        ITEM_MOD_CRIT_RATING_SHORT = 1.9,
        ITEM_MOD_HASTE_RATING_SHORT = 1.8,
    } },
  },
  DRUID_BEAR = { name = "Feral (bear)", source = "Icy Veins + Warcraft Tavern (WotLK Classic); Stamina = 1.0", w = {
        ITEM_MOD_STAMINA_SHORT = 1.0,
        ITEM_MOD_EXPERTISE_RATING_SHORT = 0.9,
        ITEM_MOD_AGILITY_SHORT = 0.8,
        ITEM_MOD_HIT_RATING_SHORT = 0.55,
        RESISTANCE0_NAME = 0.25,           -- per armor point (bear multipliers; non-leather weaker, not distinguishable)
        ITEM_MOD_DODGE_RATING_SHORT = 0.4,
        ITEM_MOD_DEFENSE_SKILL_RATING_SHORT = 0.3,
        ITEM_MOD_STRENGTH_SHORT = 0.35,
        ITEM_MOD_HASTE_RATING_SHORT = 0.3,
        ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT = 0.3,
        ITEM_MOD_CRIT_RATING_SHORT = 0.25,
        ITEM_MOD_FERAL_ATTACK_POWER_SHORT = 0.12,
        ITEM_MOD_ATTACK_POWER_SHORT = 0.1,
  } },
}
end)()
for k, v in pairs(t) do
  if S[k] then for tab, e in pairs(v) do S[k][tab] = e end else S[k] = v end
end
end

S.DRUID = S.DRUID or {}
S.DRUID[3] = {
    name = "Restoration",
    source = "IcyVeins, WotLK Classic Restoration Druid stat priority",
    w = {
        ITEM_MOD_MANA_REGENERATION_SHORT = 0.5,      -- mp5: IcyVeins says 2.0, but other guides rank it last or treat it as a target
        ITEM_MOD_SPELL_POWER_SHORT       = 1.0,
        ITEM_MOD_HEALING_POWER_SHORT     = 1.0,
        ITEM_MOD_HASTE_RATING_SHORT      = 1.0,
        ITEM_MOD_INTELLECT_SHORT         = 1.0,
        ITEM_MOD_SPIRIT_SHORT            = 0.9,
        ITEM_MOD_CRIT_RATING_SHORT       = 0.1,
    },
}
DS.DreamScoreSpecs = S
