-- DotColors: eigene Schadenszahlen, eingefaerbt nach Warlock-DoT (WoW Forever)
--
-- Prinzip: Forever gibt Addons kein Combat Log. UNIT_COMBAT liefert aber Schadensschule,
-- Krit-Flag und den (geheimen) Betrag, und eigene Casts sind lesbar. Jeder DoT tickt in
-- einem festen Takt ab dem letzten Cast (Agony 2 s, Corruption 3 s, Immolate 3 s).
-- Ein Schattentreffer zur erwarteten Tick-Zeit bekommt die Farbe dieses DoTs.
-- Der geheime Betrag wird nur angezeigt (SetText), nie ausgelesen.

local ADDON, ns = ...

local FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local TOL = 0.35                     -- erlaubte Abweichung vom erwarteten Tick (s)
local SCHOOL_PHYSICAL, SCHOOL_FIRE, SCHOOL_SHADOW = 1, 4, 32

local issecret = issecretvalue
local function isSecret(v)
  if not issecret then return false end
  local ok, r = pcall(issecret, v)
  return ok and r
end

---------------------------------------------------------------------------
-- Zauber-Tabellen (englische und deutsche Namen)
---------------------------------------------------------------------------
local DOT_SPELLS = {
  ["Corruption"] = "corruption",   ["Verderbnis"] = "corruption",
  ["Bane of Agony"] = "agony",     ["Curse of Agony"] = "agony",
  ["Fluch der Pein"] = "agony",    ["Bann der Pein"] = "agony",
  ["Immolate"] = "immolate",       ["Feuerbrand"] = "immolate",
  ["Siphon Life"] = "siphon",      ["Lebensentzug"] = "siphon",
}

local DOT_INFO = {
  corruption = { interval = 3, duration = 18, school = SCHOOL_SHADOW },
  agony      = { interval = 2, duration = 24, school = SCHOOL_SHADOW },
  immolate   = { interval = 3, duration = 15, school = SCHOOL_FIRE },
  siphon     = { interval = 3, duration = 30, school = SCHOOL_SHADOW },
}

local PET_SPELLS = {
  ["Lash of Pain"] = "lash", ["Schmerzenspeitsche"] = "lash",
  ["Firebolt"] = "petfire",  ["Feuerblitz"] = "petfire",
}

local CHANNEL_SPELLS = {
  ["Drain Life"] = true, ["Blutsauger"] = true,
  ["Drain Soul"] = true, ["Seelendieb"] = true,
}

local LABELS = {
  corruption = "Corruption", agony = "Agony", immolate = "Immolate", siphon = "Siphon Life",
  lash = "Lash of Pain (Pet)", petfire = "Firebolt (Pet)", drain = "Drain Life/Soul",
  shadow = "sonstiger Schatten", fire = "sonstiges Feuer", physical = "physisch", other = "sonstiges",
}
local ORDER = { "corruption", "agony", "immolate", "siphon", "lash", "petfire", "drain", "shadow", "fire", "physical", "other" }

-- horizontale Spur pro Typ, damit sich die Zahlen nicht ueberlagern
local LANES = {
  lash = -90, corruption = -50, agony = -15, immolate = 25, siphon = 60, drain = 95,
  petfire = 25, shadow = 0, fire = 0, physical = 0, other = 0,
}

local DEFAULTS = {
  colors = {
    corruption = { 0.72, 0.38, 1.00 },  -- lila
    agony      = { 0.45, 1.00, 0.25 },  -- giftgruen
    immolate   = { 1.00, 0.50, 0.10 },  -- orange
    siphon     = { 0.20, 0.90, 0.80 },  -- tuerkis
    lash       = { 1.00, 0.40, 0.75 },  -- pink
    petfire    = { 1.00, 0.70, 0.30 },
    drain      = { 0.40, 0.60, 1.00 },  -- blau
    shadow     = { 0.65, 0.60, 0.80 },
    fire       = { 1.00, 0.85, 0.30 },
    physical   = { 0.85, 0.85, 0.85 },
    other      = { 1.00, 1.00, 1.00 },
  },
  icons = true,
  plates = true,
  hideBlizzard = true,
  onlyDots = false,
  showPhysical = true,
  debug = false,
  fontSize = 18,
  duration = 1.6,   -- Lebensdauer einer Zahl (s)
  rise = 70,        -- Steighoehe (px)
  x = 0, y = 120,
  prevCVars = {},
}

local db

local function copyDefaults(src, dst)
  for k, v in pairs(src) do
    if type(v) == "table" then
      if type(dst[k]) ~= "table" then dst[k] = {} end
      copyDefaults(v, dst[k])
    elseif dst[k] == nil then
      dst[k] = v
    end
  end
end

local function msg(text) print("|cffb966ffDotColors|r " .. text) end

---------------------------------------------------------------------------
-- Hilfsfunktionen fuer Einheiten und Zauber
---------------------------------------------------------------------------
local function safe(fn, ...)
  local ok, a = pcall(fn, ...)
  if ok and not isSecret(a) then return a end
end

local function unitKey(unit)
  if not safe(UnitExists, unit) then return nil end
  local guid = safe(UnitGUID, unit)
  if guid then return guid end
  if unit == "target" or safe(UnitIsUnit, unit, "target") then return "u:target" end
  return "u:" .. unit
end

local function spellName(id)
  if C_Spell and C_Spell.GetSpellName then
    local n = safe(C_Spell.GetSpellName, id)
    if n then return n end
  end
  if GetSpellInfo then return safe(GetSpellInfo, id) end
end

local function spellIcon(id)
  if C_Spell and C_Spell.GetSpellTexture then
    local t = safe(C_Spell.GetSpellTexture, id)
    if t then return t end
  end
  if GetSpellTexture then return safe(GetSpellTexture, id) end
end

---------------------------------------------------------------------------
-- Zustand pro Gegner: aktive DoTs mit Tick-Uhr
---------------------------------------------------------------------------
local states = {}
local channel   -- { key, icon } waehrend Drain Life / Drain Soul

local function getState(key)
  local s = states[key]
  if not s then
    s = { dots = {} }
    states[key] = s
  end
  s.seen = GetTime()
  return s
end

local function onPlayerCast(spellID)
  local name = spellName(spellID)
  if not name then return end
  local key = unitKey("target")
  if not key then return end
  local now = GetTime()
  local s = getState(key)
  local dot = DOT_SPELLS[name]
  if dot then
    local info = DOT_INFO[dot]
    -- Ein Recast setzt den Tick-Takt zurueck (im DotScout-Log bestaetigt)
    s.dots[dot] = {
      base = now, cast = now, fresh = true,
      expires = now + info.duration + 3,
      icon = spellIcon(spellID),
    }
  else
    s.direct = { t = now, icon = spellIcon(spellID) }
  end
end

local function onPetCast(spellID)
  local name = spellName(spellID)
  local kind = name and PET_SPELLS[name]
  if not kind then return end
  local key = unitKey("pettarget") or unitKey("target")
  if not key then return end
  getState(key).petCast = { t = GetTime(), kind = kind, icon = spellIcon(spellID) }
end

-- Ordnet einen Treffer einem Typ zu. Rueckgabe: typ, icon, abweichung
local function classify(key, school, now)
  local s = states[key]

  if s then
    -- 1) Pet-Zauber: Treffer kommt zeitgleich mit dem Pet-Cast
    local pc = s.petCast
    if pc and not pc.used and now - pc.t < 0.3 then
      if (pc.kind == "lash" and school == SCHOOL_SHADOW) or (pc.kind == "petfire" and school == SCHOOL_FIRE) then
        pc.used = true
        return pc.kind, pc.icon, now - pc.t
      end
    end

    -- 2) DoTs: welcher erwartete Tick passt am besten?
    local best, bestErr
    for dot, d in pairs(s.dots) do
      local info = DOT_INFO[dot]
      if now > d.expires then
        s.dots[dot] = nil
      elseif info.school == school then
        local dt = now - d.base
        local err
        if d.fresh and dt < 0.25 then
          err = dt                              -- Treffer direkt beim Cast
        elseif dt > 0.5 then
          local n = math.floor(dt / info.interval + 0.5)
          if n >= 1 then err = math.abs(dt - n * info.interval) end
        end
        if err and err < TOL and (not bestErr or err < bestErr) then
          best, bestErr = dot, err
        end
      end
    end
    if best then
      local d = s.dots[best]
      if d.fresh and now - d.base < 0.25 then
        d.fresh = false                         -- Direkttreffer: Tick-Uhr laeuft ab Cast weiter
      else
        d.base = now                            -- Tick erkannt: Uhr neu ausrichten (gegen Drift)
        d.fresh = false
      end
      return best, d.icon, bestErr
    end
  end

  -- 3) Kanalisierte Zauber
  if channel and channel.key == key and school == SCHOOL_SHADOW then
    return "drain", channel.icon
  end

  -- 4) Rest nach Schule
  local icon = s and s.direct and now - s.direct.t < 3 and s.direct.icon or nil
  if school == SCHOOL_SHADOW then return "shadow", icon end
  if school == SCHOOL_FIRE then return "fire", icon end
  if school == SCHOOL_PHYSICAL then return "physical" end
  return "other", icon
end

---------------------------------------------------------------------------
-- Anzeige: schwebende Zahlen
---------------------------------------------------------------------------
local anchorFrame = CreateFrame("Frame", "DotColorsAnchor", UIParent)
anchorFrame:SetSize(120, 24)
anchorFrame:SetMovable(true)
anchorFrame:SetClampedToScreen(true)
anchorFrame.bg = anchorFrame:CreateTexture(nil, "BACKGROUND")
anchorFrame.bg:SetAllPoints()
anchorFrame.bg:SetColorTexture(0.6, 0.3, 1, 0.5)
anchorFrame.label = anchorFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
anchorFrame.label:SetPoint("CENTER")
anchorFrame.label:SetText("DotColors")
anchorFrame.bg:Hide()
anchorFrame.label:Hide()
anchorFrame:RegisterForDrag("LeftButton")
anchorFrame:SetScript("OnDragStart", anchorFrame.StartMoving)
anchorFrame:SetScript("OnDragStop", function(self)
  self:StopMovingOrSizing()
  local x, y = self:GetCenter()
  local ux, uy = UIParent:GetCenter()
  db.x, db.y = math.floor(x - ux + 0.5), math.floor(y - uy + 0.5)
  self:ClearAllPoints()
  self:SetPoint("CENTER", UIParent, "CENTER", db.x, db.y)
  if ns.onAnchorMoved then ns.onAnchorMoved() end
end)

local function placeAnchor()
  anchorFrame:ClearAllPoints()
  anchorFrame:SetPoint("CENTER", UIParent, "CENTER", db.x, db.y)
end

local pool, active = {}, {}
local laneLast = {}

local function acquire()
  local f = table.remove(pool)
  if not f then
    f = CreateFrame("Frame", nil, UIParent)
    f:SetSize(1, 1)
    f:SetFrameStrata("HIGH")
    f.text = f:CreateFontString(nil, "OVERLAY")
    f.text:SetPoint("CENTER")
    f.icon = f:CreateTexture(nil, "OVERLAY")
    f.icon:SetPoint("RIGHT", f.text, "LEFT", -3, 0)
    f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  end
  return f
end

local function plateFor(unit)
  if not db.plates or not C_NamePlate or not C_NamePlate.GetNamePlateForUnit then return nil end
  local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
  if ok and plate and not isSecret(plate) and plate:IsVisible() then return plate end
end

local function spawn(kind, amount, crit, icon, anchor)
  local f = acquire()
  local c = db.colors[kind] or db.colors.other
  local size = math.floor(db.fontSize * (crit and 1.45 or 1))

  f.text:SetFont(FONT, size, "OUTLINE")
  f.text:SetTextColor(c[1], c[2], c[3])
  if not pcall(f.text.SetText, f.text, amount) then
    f.text:SetText("?")
  end

  if db.icons and icon then
    f.icon:SetTexture(icon)
    f.icon:SetSize(size, size)
    f.icon:Show()
  else
    f.icon:Hide()
  end

  -- Zahlen, die kurz nacheinander in derselben Spur kommen, etwas versetzen
  local now = GetTime()
  local ll = laneLast[kind]
  local step = 0
  if ll and now - ll.t < 0.35 then step = ll.step + 1 end
  laneLast[kind] = { t = now, step = step }

  f.anchor = anchor or anchorFrame
  f.x = LANES[kind] or 0
  f.yoff = step * (size + 2)
  f.start = now
  f:SetAlpha(1)
  f:Show()
  active[#active + 1] = f
end

local driver = CreateFrame("Frame")
driver:SetScript("OnUpdate", function()
  if #active == 0 then return end
  local now = GetTime()
  for i = #active, 1, -1 do
    local f = active[i]
    local p = (now - f.start) / db.duration
    if p >= 1 or not f.anchor:IsVisible() then
      f:Hide()
      table.remove(active, i)
      pool[#pool + 1] = f
    else
      f:ClearAllPoints()
      f:SetPoint("CENTER", f.anchor, "TOP", f.x, 12 + f.yoff + db.rise * p)
      f:SetAlpha(p < 0.6 and 1 or (1 - p) / 0.4)
    end
  end
end)

---------------------------------------------------------------------------
-- Blizzard-Zahlen fuer ausgehenden Schaden ein-/ausblenden
---------------------------------------------------------------------------
-- Der moderne Client nutzt die Namen mit "_v2"; die alten Namen werden zusaetzlich
-- versucht. Nicht existierende CVars werden einfach uebersprungen.
local FCT_CVARS = {
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
  if C_CVar and C_CVar.GetCVar then return safe(C_CVar.GetCVar, name) end
  if GetCVar then return safe(GetCVar, name) end
end

local function setCVar(name, value)
  if C_CVar and C_CVar.SetCVar then return pcall(C_CVar.SetCVar, name, value) end
  if SetCVar then return pcall(SetCVar, name, value) end
end

local function applyBlizzard(report)
  local found = 0
  for _, cv in ipairs(FCT_CVARS) do
    local cur = getCVar(cv)
    if cur ~= nil then
      found = found + 1
      if db.hideBlizzard then
        if db.prevCVars[cv] == nil and cur ~= "0" then db.prevCVars[cv] = cur end
        setCVar(cv, "0")
      elseif db.prevCVars[cv] ~= nil then
        setCVar(cv, db.prevCVars[cv])
        db.prevCVars[cv] = nil
      end
      if report then
        print(string.format("  %s: vorher %s, jetzt %s", cv, tostring(cur), tostring(getCVar(cv))))
      end
    end
  end
  if report and found == 0 then
    print("  Keine der bekannten Einstellungen gefunden. Bitte im Spielmenue abschalten (siehe Chat-Hilfe).")
  end
  return found
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local ev = CreateFrame("Frame")
local handlers = {}

handlers.ADDON_LOADED = function(name)
  if name ~= ADDON then return end
  DotColorsDB = DotColorsDB or {}
  db = DotColorsDB
  copyDefaults(DEFAULTS, db)
  placeAnchor()
  ev:RegisterEvent("PLAYER_LOGIN")
  ev:RegisterEvent("UNIT_COMBAT")
  ev:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
  ev:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
  ev:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
end

handlers.PLAYER_LOGIN = function()
  applyBlizzard()
  msg("geladen. /dc fuer Befehle, /dc test fuer eine Vorschau.")
end

handlers.UNIT_SPELLCAST_SUCCEEDED = function(unit, _, spellID)
  if unit == "player" then
    onPlayerCast(spellID)
  elseif unit == "pet" then
    onPetCast(spellID)
  end
end

handlers.UNIT_SPELLCAST_CHANNEL_START = function(unit, _, spellID)
  if unit ~= "player" then return end
  local name = spellName(spellID)
  if name and CHANNEL_SPELLS[name] then
    channel = { key = unitKey("target"), icon = spellIcon(spellID) }
  end
end

handlers.UNIT_SPELLCAST_CHANNEL_STOP = function(unit)
  if unit == "player" then channel = nil end
end

handlers.UNIT_COMBAT = function(unit, action, flag, amount, school)
  if action ~= "WOUND" then return end
  local isPlate = unit:match("^nameplate%d+$") ~= nil
  if unit ~= "target" and not isPlate then return end

  -- Doppelte Meldung vermeiden: das Ziel kommt ueber "target" UND ueber seine Nameplate
  if isPlate and safe(UnitExists, "target") then
    local ok, same = pcall(UnitIsUnit, unit, "target")
    if not ok or isSecret(same) or same then return end
  end

  local key = unitKey(unit)
  if not key then return end
  if isSecret(school) then school = 0 end
  local crit = (not isSecret(flag)) and flag == "CRITICAL"

  local now = GetTime()
  local kind, icon, err = classify(key, school, now)

  if db.debug then
    msg(string.format("%s | Schule %s | %s%s", unit, tostring(school), LABELS[kind] or kind,
      err and string.format(" (Abw. %.2fs)", err) or ""))
  end

  if kind == "physical" and not db.showPhysical then return end
  if db.onlyDots and not DOT_INFO[kind] then return end

  spawn(kind, amount, crit, icon, plateFor(unit))
end

ev:RegisterEvent("ADDON_LOADED")
ev:SetScript("OnEvent", function(_, event, ...)
  local h = handlers[event]
  if h then
    local ok, err = pcall(h, ...)
    if not ok and db and db.debug then msg("Fehler in " .. event .. ": " .. tostring(err)) end
  end
end)

-- Alte Gegner regelmaessig vergessen
C_Timer.NewTicker(15, function()
  local cutoff = GetTime() - 60
  for key, s in pairs(states) do
    if (s.seen or 0) < cutoff then states[key] = nil end
  end
end)

---------------------------------------------------------------------------
-- Slash-Befehle
---------------------------------------------------------------------------
local function onOff(v) return v and "|cff40ff40an|r" or "|cffff4040aus|r" end

local function parseHex(hex)
  hex = hex and hex:gsub("#", "")
  if not hex or not hex:match("^%x%x%x%x%x%x$") then return nil end
  return tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255
end

local function toHex(c)
  return string.format("%02x%02x%02x", c[1] * 255 + 0.5, c[2] * 255 + 0.5, c[3] * 255 + 0.5)
end

local function runTest()
  local anchor = plateFor("target")
  local demo = { "corruption", "agony", "immolate", "lash", "siphon", "drain", "shadow", "physical" }
  for i, kind in ipairs(demo) do
    C_Timer.After((i - 1) * 0.25, function()
      spawn(kind, 100 + i * 11, i == 3, nil, anchor)
    end)
  end
end

local function isMoving() return anchorFrame.bg:IsShown() end

local function setMoving(show)
  anchorFrame.bg:SetShown(show)
  anchorFrame.label:SetShown(show)
  anchorFrame:EnableMouse(show)
end

local function resetAll()
  local prev = db.prevCVars
  DotColorsDB = { prevCVars = prev }
  db = DotColorsDB
  copyDefaults(DEFAULTS, db)
  placeAnchor()
end

-- Schnittstelle fuer das Einstellungsfenster (DotColorsOptions.lua)
ns.getDB = function() return db end
ns.defaults = DEFAULTS
ns.labels = LABELS
ns.order = ORDER
ns.msg = msg
ns.runTest = runTest
ns.applyBlizzard = applyBlizzard
ns.placeAnchor = placeAnchor
ns.isMoving = isMoving
ns.setMoving = setMoving
ns.resetAll = resetAll
ns.spawnSample = function(kind) spawn(kind, 123, false, nil, plateFor("target")) end

SLASH_DOTCOLORS1 = "/dc"
SLASH_DOTCOLORS2 = "/dotcolors"
SlashCmdList.DOTCOLORS = function(input)
  local cmd, a, b = (input or ""):match("^(%S*)%s*(%S*)%s*(%S*)")
  cmd = (cmd or ""):lower()

  if cmd == "test" then
    runTest()
  elseif cmd == "blizz" then
    if InCombatLockdown() then msg("Bitte ausserhalb des Kampfes.") return end
    if a == "status" then
      msg("Blizzard-Schadenszahlen ausgeblendet: " .. onOff(db.hideBlizzard))
      applyBlizzard(true)
      return
    end
    db.hideBlizzard = not db.hideBlizzard
    msg("Blizzard-Schadenszahlen ausgeblendet: " .. onOff(db.hideBlizzard))
    applyBlizzard(true)
  elseif cmd == "plates" then
    db.plates = not db.plates
    msg("Zahlen an der Nameplate: " .. onOff(db.plates) .. " (sonst am verschiebbaren Anker)")
  elseif cmd == "" or cmd == "config" or cmd == "options" then
    if ns.toggleOptions then ns.toggleOptions() end
  elseif cmd == "move" then
    local show = not isMoving()
    setMoving(show)
    msg(show and "Anker mit der Maus verschieben, danach /dc move." or "Anker gesperrt.")
  elseif cmd == "icons" then
    db.icons = not db.icons
    msg("Zauber-Icons: " .. onOff(db.icons))
  elseif cmd == "physical" then
    db.showPhysical = not db.showPhysical
    msg("Physischen Schaden (z. B. Pet-Nahkampf) zeigen: " .. onOff(db.showPhysical))
  elseif cmd == "only" then
    db.onlyDots = not db.onlyDots
    msg("Nur erkannte DoTs zeigen: " .. onOff(db.onlyDots))
  elseif cmd == "size" then
    local n = tonumber(a)
    if n and n >= 8 and n <= 48 then
      db.fontSize = n
      msg("Schriftgroesse: " .. n)
    else
      msg("Beispiel: /dc size 20 (erlaubt 8-48)")
    end
  elseif cmd == "color" then
    local key = a and a:lower()
    local r, g, bl = parseHex(b)
    if key and db.colors[key] and r then
      db.colors[key] = { r, g, bl }
      msg(LABELS[key] .. " -> |cff" .. toHex(db.colors[key]) .. b:gsub("#", "") .. "|r")
    else
      msg("Beispiel: /dc color agony 00ff66")
      for _, k in ipairs(ORDER) do
        print(string.format("  |cff%s%s|r = %s", toHex(db.colors[k]), k, LABELS[k]))
      end
    end
  elseif cmd == "debug" then
    db.debug = not db.debug
    msg("Debug-Ausgabe im Chat: " .. onOff(db.debug))
  elseif cmd == "reset" then
    resetAll()
    if ns.refreshOptions then ns.refreshOptions() end
    msg("Einstellungen zurueckgesetzt.")
  else
    msg("Befehle:")
    print("  /dc - Einstellungsfenster oeffnen")
    print("  /dc test - Vorschau aller Farben")
    print("  /dc color [name] [hex] - Farbe aendern (ohne Werte: Liste)")
    print("  /dc size [n] - Schriftgroesse (jetzt " .. db.fontSize .. ")")
    print("  /dc plates - an Nameplate anheften " .. onOff(db.plates))
    print("  /dc move - Ersatz-Anker verschieben")
    print("  /dc icons - Zauber-Icons " .. onOff(db.icons))
    print("  /dc physical - physischen Schaden zeigen " .. onOff(db.showPhysical))
    print("  /dc only - nur erkannte DoTs zeigen " .. onOff(db.onlyDots))
    print("  /dc blizz - Blizzard-Zahlen ausblenden " .. onOff(db.hideBlizzard) .. " (/dc blizz status zeigt Details)")
    print("  /dc debug - Zuordnung im Chat mitlesen " .. onOff(db.debug))
    print("  /dc reset - alles zuruecksetzen")
  end
end
