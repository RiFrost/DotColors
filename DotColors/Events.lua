-- Events.lua
-- Connects the game's events to the matcher and the display.

local ADDON, ns = ...
local L = ns.L

local FORGET_CHECK_INTERVAL = 15  -- seconds between clean-ups of old enemies

local events = CreateFrame("Frame")
local handlers = {}

function handlers.ADDON_LOADED(name)
  if name ~= ADDON then return end
  ns.loadSettings()
  ns.placeAnchor()
  events:RegisterEvent("PLAYER_LOGIN")
  events:RegisterEvent("UNIT_COMBAT")
  events:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
  events:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
  events:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
end

function handlers.PLAYER_LOGIN()
  ns.applyBlizzardNumbers()
  ns.createMinimapButton()
  if ns.registerSettingsPanel then pcall(ns.registerSettingsPanel) end
  ns.print(L["Loaded. Type /dc for options."])
end

function handlers.UNIT_SPELLCAST_SUCCEEDED(unit, _, spellID)
  if unit == "player" then
    ns.onPlayerCast(spellID)
  elseif unit == "pet" then
    ns.onPetCast(spellID)
  end
end

function handlers.UNIT_SPELLCAST_CHANNEL_START(unit, _, spellID)
  if unit == "player" then ns.onChannelStart(spellID) end
end

function handlers.UNIT_SPELLCAST_CHANNEL_STOP(unit)
  if unit == "player" then ns.onChannelStop() end
end

--- True if this nameplate belongs to the current target. The target's hits
--- arrive both as "target" and as its nameplate; only one may count.
local function isTargetsNameplate(unit)
  if not ns.safeCall(UnitExists, "target") then return false end
  local ok, same = pcall(UnitIsUnit, unit, "target")
  return not ok or ns.isSecret(same) or same
end

-- Damage taken by a unit. amount is a secret value and is only displayed.
function handlers.UNIT_COMBAT(unit, action, flag, amount, school)
  if action ~= "WOUND" then return end
  local isNameplate = unit:match("^nameplate%d+$") ~= nil
  if unit ~= "target" and not isNameplate then return end
  if isNameplate and isTargetsNameplate(unit) then return end

  local key = ns.enemyKey(unit)
  if not key then return end
  if ns.isSecret(school) then school = 0 end
  local isCrit = not ns.isSecret(flag) and flag == "CRITICAL"

  local kind, icon, offBy = ns.classifyHit(key, school, GetTime())
  ns.debug(string.format(L["%s | school %s | %s"], unit, tostring(school), ns.KIND_BY_KEY[kind].label)
    .. (offBy and string.format(L[" (off by %.2fs)"], offBy) or ""))

  if kind == "physical" and not ns.db.showPhysical then return end
  if ns.db.onlyDots and not ns.DOTS[kind] then return end

  ns.showNumber(kind, amount, isCrit, icon, ns.nameplateFor(unit))
end

events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(_, event, ...)
  local ok, err = pcall(handlers[event], ...)
  if not ok then ns.debug(string.format(L["Error in %s: %s"], event, tostring(err))) end
end)

C_Timer.NewTicker(FORGET_CHECK_INTERVAL, ns.forgetOldEnemies)
