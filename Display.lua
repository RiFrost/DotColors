-- Display.lua
-- Draws the floating numbers, the movable fixed anchor, and turns the
-- game's own damage numbers off and on.

local _, ns = ...
local L = ns.L

local FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local CRIT_SCALE = 1.45        -- crits are drawn this much larger
local FADE_START = 0.6         -- share of the display time after which a number fades out
local START_OFFSET_Y = 12      -- numbers start this far above their anchor
local PREVIEW_STEP = 0.25      -- seconds between numbers in the preview

---------------------------------------------------------------------------
-- Fixed anchor: used when numbers are not attached to a nameplate
---------------------------------------------------------------------------
local anchor = CreateFrame("Frame", "DotColorsAnchor", UIParent)
anchor:SetSize(120, 24)
anchor:SetMovable(true)
anchor:SetClampedToScreen(true)
anchor:RegisterForDrag("LeftButton")

local anchorBox = anchor:CreateTexture(nil, "BACKGROUND")
anchorBox:SetAllPoints()
anchorBox:SetColorTexture(0.6, 0.3, 1, 0.5)
local anchorLabel = anchor:CreateFontString(nil, "OVERLAY", "GameFontNormal")
anchorLabel:SetPoint("CENTER")
anchorLabel:SetText("DotColors")

--- Puts the anchor where the settings say.
function ns.placeAnchor()
  anchor:ClearAllPoints()
  anchor:SetPoint("CENTER", UIParent, "CENTER", ns.db.anchorX, ns.db.anchorY)
end

--- Saves the anchor's position after the player dragged it.
local function saveAnchorPosition()
  anchor:StopMovingOrSizing()
  local x, y = anchor:GetCenter()
  local centerX, centerY = UIParent:GetCenter()
  ns.db.anchorX = math.floor(x - centerX + 0.5)
  ns.db.anchorY = math.floor(y - centerY + 0.5)
  ns.placeAnchor()
  if ns.refreshOptions then ns.refreshOptions() end
end

anchor:SetScript("OnDragStart", anchor.StartMoving)
anchor:SetScript("OnDragStop", saveAnchorPosition)

--- True while the anchor is shown and can be dragged.
function ns.isAnchorUnlocked()
  return anchorBox:IsShown()
end

--- Shows the anchor as a draggable box, or hides it again.
function ns.setAnchorUnlocked(unlocked)
  anchorBox:SetShown(unlocked)
  anchorLabel:SetShown(unlocked)
  anchor:EnableMouse(unlocked)
end

ns.setAnchorUnlocked(false)

---------------------------------------------------------------------------
-- Floating numbers
---------------------------------------------------------------------------
local unusedNumbers = {}
local activeNumbers = {}
-- attachTo frame -> lane offset -> { number, startTime }: the newest number in each column
local newestInColumn = setmetatable({}, { __mode = "k" })

--- A number frame from the pool, or a new one.
local function acquireNumber()
  local number = table.remove(unusedNumbers)
  if number then return number end

  number = CreateFrame("Frame", nil, UIParent)
  number:SetSize(1, 1)
  number:SetFrameStrata("HIGH")
  number.text = number:CreateFontString(nil, "OVERLAY")
  number.text:SetPoint("CENTER")
  number.icon = number:CreateTexture(nil, "OVERLAY")
  number.icon:SetPoint("RIGHT", number.text, "LEFT", -3, 0)
  number.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  return number
end

--- How far a number has risen above its anchor right now.
local function currentHeight(number, now)
  return number.offsetY + ns.db.riseHeight * (now - number.startTime) / ns.db.duration
end

--- The vertical start offset for a new number, so it keeps a gap to the newest
--- number in the same column above the same enemy. That number has already
--- risen a bit; if it is still too close, the new one starts lower. All numbers
--- rise at the same speed, so the gap stays the same all the way up.
--- Also remembers the new number as the column's newest.
local function startOffset(number, attachTo, lane, size, now)
  local columns = newestInColumn[attachTo]
  if not columns then
    columns = {}
    newestInColumn[attachTo] = columns
  end

  local offset = 0
  local newest = columns[lane]
  -- The pool reuses frames, so check it is still the same, still visible number.
  local stillShown = newest and newest.number.startTime == newest.startTime
    and now - newest.startTime < ns.db.duration
  if stillShown then
    local gap = (newest.number.size + size) / 2 + ns.db.numberGap
    offset = math.min(0, currentHeight(newest.number, now) - gap)
  end

  columns[lane] = { number = number, startTime = now }
  return offset
end

--- The visible nameplate of a unit, if numbers should go there.
function ns.nameplateFor(unit)
  if not ns.db.showOnNameplates or not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then return nil end
  local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
  if ok and plate and not ns.isSecret(plate) and plate:IsVisible() then return plate end
end

--- Shows one floating number.
--- amount may be a secret value: it is only passed to SetText, never read.
function ns.showNumber(kind, amount, isCrit, icon, attachTo)
  local number = acquireNumber()
  local color = ns.db.colors[kind] or ns.db.colors.other
  local size = math.floor(ns.db.fontSize * (isCrit and CRIT_SCALE or 1))

  number.text:SetFont(FONT, size, "OUTLINE")
  number.text:SetTextColor(color[1], color[2], color[3])
  if not pcall(number.text.SetText, number.text, amount) then
    number.text:SetText("?")
  end

  if ns.db.showIcons and icon then
    number.icon:SetTexture(icon)
    number.icon:SetSize(size, size)
    number.icon:Show()
  else
    number.icon:Hide()
  end

  local now = GetTime()
  number.attachTo = attachTo or anchor
  local lane = ns.KIND_BY_KEY[kind] and ns.KIND_BY_KEY[kind].lane or 0
  number.offsetX = lane * ns.db.laneSpacing / 100
  number.offsetY = startOffset(number, number.attachTo, lane, size, now)
  number.size = size
  number.startTime = now
  number:SetAlpha(1)
  number:Show()
  activeNumbers[#activeNumbers + 1] = number
end

--- Moves every number up and fades it out; returns finished ones to the pool.
local function animateNumbers()
  if #activeNumbers == 0 then return end
  local now = GetTime()
  for i = #activeNumbers, 1, -1 do
    local number = activeNumbers[i]
    local progress = (now - number.startTime) / ns.db.duration
    if progress >= 1 or not number.attachTo:IsVisible() then
      number:Hide()
      table.remove(activeNumbers, i)
      unusedNumbers[#unusedNumbers + 1] = number
    else
      number:ClearAllPoints()
      number:SetPoint("CENTER", number.attachTo, "TOP", number.offsetX,
        START_OFFSET_Y + number.offsetY + ns.db.riseHeight * progress)
      number:SetAlpha(progress < FADE_START and 1 or (1 - progress) / (1 - FADE_START))
    end
  end
end

CreateFrame("Frame"):SetScript("OnUpdate", animateNumbers)

--- Shows one sample number of every main color, above the target or at the anchor.
function ns.showPreview()
  local attachTo = ns.nameplateFor("target")
  local kinds = { "corruption", "agony", "immolate", "lash", "siphon", "drain", "wrack", "shadow", "physical" }
  for i, kind in ipairs(kinds) do
    C_Timer.After((i - 1) * PREVIEW_STEP, function()
      ns.showNumber(kind, 100 + i * 11, kind == "immolate", nil, attachTo)
    end)
  end
end

--- Shows a single sample number of one hit type.
function ns.showSample(kind)
  ns.showNumber(kind, 123, false, nil, ns.nameplateFor("target"))
end

---------------------------------------------------------------------------
-- Blizzard's own damage numbers
---------------------------------------------------------------------------
-- The modern client uses the "_v2" names; the old names are tried as well.
-- Settings the client doesn't know are skipped.
local BLIZZARD_NUMBER_CVARS = {
  "floatingCombatTextCombatDamage_v2",
  "floatingCombatTextCombatLogPeriodicSpells_v2",
  "floatingCombatTextPetMeleeDamage_v2",
  "floatingCombatTextPetSpellDamage_v2",
  "floatingCombatTextCombatDamage",
  "floatingCombatTextCombatLogPeriodicSpells",
  "floatingCombatTextPetMeleeDamage",
  "floatingCombatTextPetSpellDamage",
}

local function getCVar(name)
  if C_CVar and C_CVar.GetCVar then return ns.safeCall(C_CVar.GetCVar, name) end
  if GetCVar then return ns.safeCall(GetCVar, name) end
end

local function setCVar(name, value)
  if C_CVar and C_CVar.SetCVar then return pcall(C_CVar.SetCVar, name, value) end
  if SetCVar then return pcall(SetCVar, name, value) end
end

--- Turns the game's damage numbers off or back on, following the setting.
--- The values before the change are remembered so they can be restored.
--- With report = true, every setting found is listed in chat.
function ns.applyBlizzardNumbers(report)
  local found = 0
  local saved = ns.db.savedCVars
  for _, name in ipairs(BLIZZARD_NUMBER_CVARS) do
    local before = getCVar(name)
    if before ~= nil then
      found = found + 1
      if ns.db.hideBlizzardNumbers then
        if saved[name] == nil and before ~= "0" then saved[name] = before end
        setCVar(name, "0")
      elseif saved[name] ~= nil then
        setCVar(name, saved[name])
        saved[name] = nil
      end
      if report then
        print("  " .. string.format(L["%s: was %s, now %s"], name, tostring(before), tostring(getCVar(name))))
      end
    end
  end
  if report and found == 0 then
    print("  " .. L["None of the known settings found. Turn the numbers off in the game options."])
  end
end
