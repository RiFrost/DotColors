-- Spells.lua
-- What DotColors knows about Warlock spells: which casts start a DoT,
-- how often each DoT ticks, and how every hit type is labeled and placed.

local _, ns = ...
local L = ns.L

ns.SCHOOL = {
  PHYSICAL = 1,
  FIRE = 4,
  SHADOW = 32,
}

-- DoTs by kind. interval: seconds between ticks; duration: how long the DoT lasts.
-- The rhythm was measured in game: Agony ticks every 2 s, the others every 3 s.
-- fasterDuringWrack: the DoT ticks twice as fast on the target while Wrack is channeled.
ns.DOTS = {
  corruption = { interval = 3, duration = 18, school = ns.SCHOOL.SHADOW, fasterDuringWrack = true },
  agony      = { interval = 2, duration = 24, school = ns.SCHOOL.SHADOW, fasterDuringWrack = true },
  immolate   = { interval = 3, duration = 15, school = ns.SCHOOL.FIRE },
  siphon     = { interval = 3, duration = 30, school = ns.SCHOOL.SHADOW, fasterDuringWrack = true },
}

-- One spell ID per spell. Every rank has its own ID, but all ranks share
-- the spell's name. So the name the game returns for one of these IDs,
-- in the client's language, recognizes every rank in every language.
-- Forever uses the classic spell IDs (6223, 6217, 2941 and 7815 were seen in game logs).

-- Spells that start each DoT.
local DOT_SPELL_IDS = {
  corruption = 6223,
  agony = 6217,
  immolate = 2941,
  siphon = 18265,
}

-- Pet spells whose hit arrives together with the pet's cast.
local PET_SPELL_IDS = {
  lash = 7815,     -- Lash of Pain (Succubus)
  petfire = 3110,  -- Firebolt (Imp)
}

-- Channeled spells: every Shadow hit on the target while channeling belongs to them.
local CHANNELED_SPELL_IDS = {
  [689] = "drain",       -- Drain Life
  [1120] = "drain",      -- Drain Soul
  [1316697] = "wrack",   -- Wrack (Affliction talent, new in Forever)
}

-- Name lookups, filled by ns.loadSpellNames() once the game shares spell names.
ns.DOT_BY_SPELL_NAME = {}
ns.PET_HIT_BY_SPELL_NAME = {}
ns.CHANNELED_SPELL_NAMES = {}

--- The spell's name in the client's language, if the game shares it.
function ns.spellName(spellID)
  if C_Spell and C_Spell.GetSpellName then
    return ns.safeCall(C_Spell.GetSpellName, spellID)
  end
  if GetSpellInfo then return ns.safeCall(GetSpellInfo, spellID) end
end

--- Adds the name of one spell ID to a lookup table.
--- An ID the game doesn't know is reported in debug mode instead of failing silently.
local function addSpellName(names, spellID, value)
  local name = ns.spellName(spellID)
  if name then
    names[name] = value
  else
    ns.debug(string.format(L["Unknown spell ID %d"], spellID))
  end
end

--- Fills the name lookups from the spell IDs above.
function ns.loadSpellNames()
  for kind, spellID in pairs(DOT_SPELL_IDS) do
    addSpellName(ns.DOT_BY_SPELL_NAME, spellID, kind)
  end
  for kind, spellID in pairs(PET_SPELL_IDS) do
    addSpellName(ns.PET_HIT_BY_SPELL_NAME, spellID, kind)
  end
  for spellID, kind in pairs(CHANNELED_SPELL_IDS) do
    addSpellName(ns.CHANNELED_SPELL_NAMES, spellID, kind)
  end
end

-- Every hit type in display order, with its label and horizontal lane offset.
-- Lanes keep numbers of different types from covering each other.
ns.KINDS = {
  { key = "corruption", label = L["Corruption"],              lane = -50 },
  { key = "agony",      label = L["Bane of Agony"],           lane = -15 },
  { key = "immolate",   label = L["Immolate"],                lane = 25 },
  { key = "siphon",     label = L["Siphon Life"],             lane = 60 },
  { key = "lash",       label = L["Lash of Pain (pet)"],      lane = -90 },
  { key = "petfire",    label = L["Firebolt (pet)"],          lane = 25 },
  { key = "drain",      label = L["Drain Life / Drain Soul"], lane = 95 },
  { key = "wrack",      label = L["Wrack"],                   lane = 95 },  -- never channeled together with Drain
  { key = "shadow",     label = L["Other Shadow"],            lane = 0 },
  { key = "fire",       label = L["Other Fire"],              lane = 0 },
  { key = "physical",   label = L["Physical"],                lane = 0 },
  { key = "other",      label = L["Other"],                   lane = 0 },
}

ns.KIND_BY_KEY = {}
for _, kind in ipairs(ns.KINDS) do
  ns.KIND_BY_KEY[kind.key] = kind
end
