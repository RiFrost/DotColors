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
ns.DOTS = {
  corruption = { interval = 3, duration = 18, school = ns.SCHOOL.SHADOW },
  agony      = { interval = 2, duration = 24, school = ns.SCHOOL.SHADOW },
  immolate   = { interval = 3, duration = 15, school = ns.SCHOOL.FIRE },
  siphon     = { interval = 3, duration = 30, school = ns.SCHOOL.SHADOW },
}

-- Spell names (English and German client) that start each DoT.
ns.DOT_BY_SPELL_NAME = {
  ["Corruption"] = "corruption",    ["Verderbnis"] = "corruption",
  ["Bane of Agony"] = "agony",      ["Curse of Agony"] = "agony",
  ["Bann der Pein"] = "agony",      ["Fluch der Pein"] = "agony",
  ["Immolate"] = "immolate",        ["Feuerbrand"] = "immolate",
  ["Siphon Life"] = "siphon",       ["Lebensentzug"] = "siphon",
}

-- Pet spells whose hit arrives together with the pet's cast.
ns.PET_HIT_BY_SPELL_NAME = {
  ["Lash of Pain"] = "lash", ["Schmerzenspeitsche"] = "lash",
  ["Firebolt"] = "petfire",  ["Feuerblitz"] = "petfire",
}

-- Channeled spells: every Shadow hit while channeling belongs to them.
ns.CHANNELED_SPELL_NAMES = {
  ["Drain Life"] = true, ["Blutsauger"] = true,
  ["Drain Soul"] = true, ["Seelendieb"] = true,
}

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
  { key = "shadow",     label = L["Other Shadow"],            lane = 0 },
  { key = "fire",       label = L["Other Fire"],              lane = 0 },
  { key = "physical",   label = L["Physical"],                lane = 0 },
  { key = "other",      label = L["Other"],                   lane = 0 },
}

ns.KIND_BY_KEY = {}
for _, kind in ipairs(ns.KINDS) do
  ns.KIND_BY_KEY[kind.key] = kind
end
