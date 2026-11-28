-- Core.lua
-- Shared namespace, saved settings and small helpers used by every file.
--
-- Why DotColors works the way it does:
-- WoW: Forever runs on the modern (Midnight) client and its addon rules.
-- Addons get no combat log, and damage amounts arrive as "secret values"
-- that may be displayed but never read, compared or used in arithmetic.
-- So DotColors cannot ask which spell caused a hit. Instead it watches
-- the player's own casts and the rhythm in which each DoT ticks, and
-- matches every incoming hit to the DoT that was due to tick at that
-- moment (see Matcher.lua).

local ADDON, ns = ...
local L = ns.L

ns.ADDON = ADDON

-- The version comes from the git tag: the packager writes it into the .toc.
-- A copy straight from the repository still holds the "@...@" placeholder.
-- The placeholder is not spelled out here, because the packager would replace it in this file too.
ns.VERSION = (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON, "Version"))
  or (GetAddOnMetadata and GetAddOnMetadata(ADDON, "Version"))
if not ns.VERSION or ns.VERSION:sub(1, 1) == "@" then
  ns.VERSION = "dev"
end

ns.DEFAULTS = {
  colors = {
    corruption = { 0.72, 0.38, 1.00 }, -- purple
    agony      = { 0.45, 1.00, 0.25 }, -- poison green
    immolate   = { 1.00, 0.50, 0.10 }, -- orange
    siphon     = { 0.20, 0.90, 0.80 }, -- teal
    lash       = { 1.00, 0.40, 0.75 }, -- pink
    petfire    = { 1.00, 0.70, 0.30 },
    drain      = { 0.40, 0.60, 1.00 }, -- blue
    wrack      = { 0.95, 0.25, 0.35 }, -- crimson
    shadow     = { 0.65, 0.60, 0.80 },
    fire       = { 1.00, 0.85, 0.30 },
    physical   = { 0.85, 0.85, 0.85 },
    other      = { 1.00, 1.00, 1.00 },
  },
  showIcons = true,
  showOnNameplates = true,
  hideBlizzardNumbers = true,
  onlyDots = false,
  showPhysical = true,
  debug = false,
  fontSize = 18,
  duration = 1.6,       -- seconds a number stays on screen
  riseHeight = 70,      -- pixels a number floats up
  laneSpacing = 100,    -- percent of the normal side-by-side distance between hit types
  numberGap = 4,        -- pixels between numbers stacked in the same column
  anchorX = 0,
  anchorY = 120,
  minimap = { show = true, angle = 200 },  -- angle in degrees around the minimap
  savedCVars = {},      -- Blizzard settings before we changed them, to restore them later
}

--- Copies every default the saved settings don't have yet (nested tables too).
local function fillDefaults(defaults, target)
  for key, value in pairs(defaults) do
    if type(value) == "table" then
      if type(target[key]) ~= "table" then target[key] = {} end
      fillDefaults(value, target[key])
    elseif target[key] == nil then
      target[key] = value
    end
  end
end

-- Setting names used up to version 0.4, mapped to their current names.
local RENAMED_SETTINGS = {
  icons = "showIcons",
  plates = "showOnNameplates",
  hideBlizzard = "hideBlizzardNumbers",
  rise = "riseHeight",
  x = "anchorX",
  y = "anchorY",
  prevCVars = "savedCVars",
}

--- Moves settings saved under an old name to their current name.
local function migrateSettings(saved)
  for oldName, newName in pairs(RENAMED_SETTINGS) do
    if saved[oldName] ~= nil then
      if saved[newName] == nil then saved[newName] = saved[oldName] end
      saved[oldName] = nil
    end
  end
end

--- Loads the saved settings into ns.db, filling in anything missing.
function ns.loadSettings()
  DotColorsDB = DotColorsDB or {}
  migrateSettings(DotColorsDB)
  fillDefaults(ns.DEFAULTS, DotColorsDB)
  ns.db = DotColorsDB
end

--- Resets every setting except the remembered Blizzard CVars,
--- which are still needed to restore the game's own numbers.
function ns.resetSettings()
  DotColorsDB = { savedCVars = ns.db.savedCVars }
  ns.loadSettings()
end

--- True if the value is a secret the addon is not allowed to read.
function ns.isSecret(value)
  if not issecretvalue then return false end
  local ok, secret = pcall(issecretvalue, value)
  return ok and secret
end

--- Calls a game function and returns its first result, or nil if the
--- call fails or the result is secret.
function ns.safeCall(fn, ...)
  local ok, result = pcall(fn, ...)
  if ok and not ns.isSecret(result) then return result end
end

--- Prints a message to chat with the addon's name in front.
function ns.print(message)
  print("|cffb966ffDotColors|r " .. message)
end

--- Prints only when the debug option is on.
function ns.debug(message)
  if ns.db and ns.db.debug then ns.print(message) end
end

--- "on" or "off", colored, for chat messages.
function ns.onOff(value)
  return value and ("|cff40ff40" .. L["on"] .. "|r") or ("|cffff4040" .. L["off"] .. "|r")
end

--- Converts a color { r, g, b } to "rrggbb".
function ns.toHex(color)
  local function byte(channel) return math.floor(channel * 255 + 0.5) end
  return string.format("%02x%02x%02x", byte(color[1]), byte(color[2]), byte(color[3]))
end

--- Converts "rrggbb" or "#rrggbb" to r, g, b (0-1), or nil if it is not a color.
function ns.fromHex(hex)
  hex = hex and hex:gsub("#", "")
  if not hex or not hex:match("^%x%x%x%x%x%x$") then return nil end
  return tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255
end
