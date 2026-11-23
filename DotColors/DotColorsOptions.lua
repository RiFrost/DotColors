-- DotColors: Einstellungsfenster im klassischen Stil
-- (dunkler Marmor, goldener Dialograhmen, Titelplakette, Seitenliste links)
local ADDON, ns = ...

local VERSION = "0.4"
local BACKDROP_TEMPLATE = BackdropTemplateMixin and "BackdropTemplate" or nil
local W, H, NAV_W = 640, 460, 160

local controls = {}
local frame

local function db() return ns.getDB() end

local function refreshAll()
  for _, c in ipairs(controls) do c.refresh() end
end

---------------------------------------------------------------------------
-- Bausteine
---------------------------------------------------------------------------
local function tryTemplate(kind, parent, template)
  local ok, f = pcall(CreateFrame, kind, nil, parent, template)
  if ok and f then return f, true end
  return CreateFrame(kind, nil, parent), false
end

local function tip(widget, title, text)
  widget:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(title, 1, 0.82, 0)
    if text then GameTooltip:AddLine(text, 1, 1, 1, true) end
    GameTooltip:Show()
  end)
  widget:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function makeButton(parent, label, width, onClick)
  local b, templated = tryTemplate("Button", parent, "UIPanelButtonTemplate")
  b:SetSize(width, 22)
  if not templated then
    b:SetNormalTexture("Interface\\Buttons\\UI-Panel-Button-Up")
    b:SetPushedTexture("Interface\\Buttons\\UI-Panel-Button-Down")
    b:SetHighlightTexture("Interface\\Buttons\\UI-Panel-Button-Highlight", "ADD")
    for _, t in ipairs({ b:GetNormalTexture(), b:GetPushedTexture(), b:GetHighlightTexture() }) do
      t:SetTexCoord(0, 0.625, 0, 0.6875)
    end
    local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("CENTER")
    b:SetFontString(fs)
  end
  b:SetText(label)
  b:SetScript("OnClick", onClick)
  return b
end

local function makeCheck(parent, label, help, get, set)
  local cb = CreateFrame("CheckButton", nil, parent)
  cb:SetSize(26, 26)
  cb:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
  cb:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
  cb:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
  cb:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
  cb.text = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  cb.text:SetPoint("LEFT", cb, "RIGHT", 2, 1)
  cb.text:SetText(label)
  cb:SetHitRectInsets(0, -(cb.text:GetStringWidth() + 6), 0, 0)
  cb:SetScript("OnClick", function(self)
    if set(self:GetChecked() and true or false) == false then
      self:SetChecked(get() and true or false)
    end
  end)
  tip(cb, label, help)
  cb.refresh = function() cb:SetChecked(get() and true or false) end
  controls[#controls + 1] = cb
  return cb
end

local function makeSlider(parent, label, minV, maxV, step, show, get, set)
  local s = CreateFrame("Slider", nil, parent, BACKDROP_TEMPLATE)
  s:SetOrientation("HORIZONTAL")
  s:SetSize(220, 17)
  s:SetMinMaxValues(minV, maxV)
  s:SetValueStep(step)
  pcall(s.SetObeyStepOnDrag, s, true)
  s:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
  if s.SetBackdrop then
    s:SetBackdrop({ bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
      edgeFile = "Interface\\Buttons\\UI-SliderBar-Border", tile = true, tileSize = 8, edgeSize = 8,
      insets = { left = 3, right = 3, top = 6, bottom = 6 } })
  else
    local bg = s:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\Buttons\\UI-SliderBar-Background")
    bg:SetPoint("TOPLEFT", 3, -6)
    bg:SetPoint("BOTTOMRIGHT", -3, 6)
  end
  s.title = s:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  s.title:SetPoint("BOTTOMLEFT", s, "TOPLEFT", 0, 3)
  s.title:SetText(label)
  s.value = s:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  s.value:SetPoint("LEFT", s, "RIGHT", 8, 0)
  local lo = s:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  lo:SetPoint("TOPLEFT", s, "BOTTOMLEFT", 2, 0)
  lo:SetText(show(minV))
  local hi = s:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  hi:SetPoint("TOPRIGHT", s, "BOTTOMRIGHT", -2, 0)
  hi:SetText(show(maxV))
  s:EnableMouseWheel(true)
  s:SetScript("OnMouseWheel", function(self, delta) self:SetValue(self:GetValue() + delta * step) end)
  local busy = false
  s:SetScript("OnValueChanged", function(self, v)
    v = math.floor(v / step + 0.5) * step
    self.value:SetText(show(v))
    if not busy then set(v) end
  end)
  s.refresh = function()
    busy = true
    s:SetValue(get())
    s.value:SetText(show(get()))
    busy = false
  end
  controls[#controls + 1] = s
  return s
end

-- Ueberschrift mit duenner Goldlinie bis zum rechten Rand
local function makeSection(parent, label, y, x)
  local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x or 24, y)
  fs:SetText(label)
  local line = parent:CreateTexture(nil, "ARTWORK")
  line:SetColorTexture(1, 0.82, 0, 0.25)
  line:SetHeight(1)
  line:SetPoint("LEFT", fs, "RIGHT", 8, 0)
  line:SetPoint("RIGHT", parent, "RIGHT", -24, 0)
  return fs
end

local function makeNote(parent, text, x, y, width)
  local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  fs:SetPoint("TOPLEFT", x, y)
  fs:SetWidth(width or 420)
  fs:SetJustifyH("LEFT")
  fs:SetText(text)
  return fs
end

-- Farbwaehler des Spiels (alte und neue Schnittstelle)
local function pickColor(r, g, b, onChange)
  local cpf = ColorPickerFrame
  if not cpf then return end
  local function cur() return cpf:GetColorRGB() end
  if cpf.SetupColorPickerAndShow then
    cpf:SetupColorPickerAndShow({ r = r, g = g, b = b, hasOpacity = false,
      swatchFunc = function() onChange(cur()) end, cancelFunc = function() onChange(r, g, b) end })
  else
    cpf.hasOpacity = false
    cpf.previousValues = { r, g, b }
    cpf.func = function() onChange(cur()) end
    cpf.cancelFunc = function() onChange(r, g, b) end
    cpf:SetColorRGB(r, g, b)
    cpf:Hide()
    cpf:Show()
  end
  pcall(cpf.SetFrameStrata, cpf, "FULLSCREEN_DIALOG")
end

local function makeColorRow(parent, key, x, y)
  local btn = CreateFrame("Button", nil, parent)
  btn:SetSize(400, 20)
  btn:SetPoint("TOPLEFT", x, y)
  btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  btn:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

  btn.sw = btn:CreateTexture(nil, "ARTWORK")
  btn.sw:SetSize(14, 14)
  btn.sw:SetPoint("LEFT", 4, 0)
  btn.edge = btn:CreateTexture(nil, "BACKGROUND")
  btn.edge:SetColorTexture(0, 0, 0, 1)
  btn.edge:SetPoint("TOPLEFT", btn.sw, -1, 1)
  btn.edge:SetPoint("BOTTOMRIGHT", btn.sw, 1, -1)

  btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  btn.text:SetPoint("LEFT", btn.sw, "RIGHT", 8, 0)
  btn.text:SetText(ns.labels[key] or key)

  btn.sample = btn:CreateFontString(nil, "OVERLAY")
  btn.sample:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 15, "OUTLINE")
  btn.sample:SetPoint("RIGHT", -8, 0)
  btn.sample:SetText("1234")

  btn.refresh = function()
    local c = db().colors[key]
    btn.sw:SetColorTexture(c[1], c[2], c[3], 1)
    btn.sample:SetTextColor(c[1], c[2], c[3])
  end

  btn:SetScript("OnClick", function(self, button)
    if button == "RightButton" then
      local d = ns.defaults.colors[key]
      db().colors[key] = { d[1], d[2], d[3] }
      self.refresh()
    elseif IsShiftKeyDown() then
      ns.spawnSample(key)
    else
      local c = db().colors[key]
      pickColor(c[1], c[2], c[3], function(r, g, b)
        db().colors[key] = { r, g, b }
        self.refresh()
      end)
    end
  end)
  tip(btn, ns.labels[key] or key,
    "Linksklick: Farbe wählen\nShift-Klick: Beispielzahl anzeigen\nRechtsklick: Standardfarbe")
  controls[#controls + 1] = btn
  return btn
end

---------------------------------------------------------------------------
-- Seiten
---------------------------------------------------------------------------
local function buildGeneralPage(pg)
  local y = -54
  makeSection(pg, "Zahlen", y)
  y = y - 24
  local checks = {
    { "An der Nameplate anzeigen", "Zahlen erscheinen über dem getroffenen Gegner. Aus: alle Zahlen am festen Anker (Seite Position).", "plates" },
    { "Zauber-Icons", "Kleines Icon des Zaubers neben der Zahl.", "icons" },
    { "Physischen Schaden zeigen", "Zum Beispiel den Nahkampf deines Dämons.", "showPhysical" },
    { "Nur erkannte DoTs zeigen", "Alles ausblenden, was keinem DoT zugeordnet werden konnte.", "onlyDots" },
  }
  for _, c in ipairs(checks) do
    local key = c[3]
    makeCheck(pg, c[1], c[2], function() return db()[key] end, function(v) db()[key] = v end)
      :SetPoint("TOPLEFT", 26, y)
    y = y - 26
  end

  y = y - 12
  makeSection(pg, "Blizzard", y)
  y = y - 24
  makeCheck(pg, "Blizzard-Schadenszahlen ausblenden",
    "Schaltet die normalen Zahlen über Gegnern ab, damit nichts doppelt erscheint. Nur außerhalb des Kampfes änderbar.",
    function() return db().hideBlizzard end,
    function(v)
      if InCombatLockdown() then
        ns.msg("Bitte außerhalb des Kampfes ändern.")
        return false
      end
      db().hideBlizzard = v
      ns.applyBlizzard()
    end):SetPoint("TOPLEFT", 26, y)

  y = y - 38
  makeSection(pg, "Fehlersuche", y)
  y = y - 24
  makeCheck(pg, "Zuordnung im Chat mitschreiben", "Schreibt für jeden Treffer in den Chat, welchem DoT er zugeordnet wurde.",
    function() return db().debug end, function(v) db().debug = v end):SetPoint("TOPLEFT", 26, y)
end

local function buildLookPage(pg)
  local function int(v) return tostring(math.floor(v + 0.5)) end
  makeSection(pg, "Größe und Bewegung", -54)
  makeSlider(pg, "Schriftgröße", 8, 40, 1, int,
    function() return db().fontSize end, function(v) db().fontSize = v end):SetPoint("TOPLEFT", 30, -98)
  makeSlider(pg, "Anzeigedauer", 0.6, 4, 0.1, function(v) return string.format("%.1f s", v) end,
    function() return db().duration end, function(v) db().duration = v end):SetPoint("TOPLEFT", 30, -146)
  makeSlider(pg, "Steighöhe", 0, 200, 5, function(v) return int(v) .. " px" end,
    function() return db().rise end, function(v) db().rise = v end):SetPoint("TOPLEFT", 30, -194)
  makeNote(pg, "Krits werden automatisch größer dargestellt. Mit \"Vorschau\" unten siehst du die Wirkung sofort.", 30, -236)
end

local function buildColorPage(pg)
  makeSection(pg, "Farbe pro Zauber", -54)
  local y = -76
  for _, key in ipairs(ns.order) do
    makeColorRow(pg, key, 24, y)
    y = y - 22
  end
  makeNote(pg, "Linksklick: Farbe wählen   Shift-Klick: Beispielzahl   Rechtsklick: Standard", 28, y - 8)
end

local function buildPositionPage(pg)
  local function int(v) return tostring(math.floor(v + 0.5)) end
  makeSection(pg, "Fester Anker", -54)
  makeNote(pg, "Der Anker wird benutzt, wenn \"An der Nameplate anzeigen\" aus ist oder der Gegner keine sichtbare Nameplate hat.", 28, -76)
  makeSlider(pg, "Horizontal", -800, 800, 5, int,
    function() return db().x end, function(v) db().x = v; ns.placeAnchor() end):SetPoint("TOPLEFT", 30, -128)
  makeSlider(pg, "Vertikal", -500, 500, 5, int,
    function() return db().y end, function(v) db().y = v; ns.placeAnchor() end):SetPoint("TOPLEFT", 30, -176)

  local move = makeButton(pg, "Anker verschieben", 150, nil)
  move:SetPoint("TOPLEFT", 28, -214)
  move:SetScript("OnClick", function()
    ns.setMoving(not ns.isMoving())
    move.refresh()
  end)
  move.refresh = function() move:SetText(ns.isMoving() and "Anker sperren" or "Anker verschieben") end
  tip(move, "Anker verschieben", "Zeigt den Anker als lila Kasten an. Mit der Maus ziehen, danach sperren.")
  controls[#controls + 1] = move

  local center = makeButton(pg, "Zurück zur Mitte", 150, function()
    db().x, db().y = ns.defaults.x, ns.defaults.y
    ns.placeAnchor()
    refreshAll()
  end)
  center:SetPoint("LEFT", move, "RIGHT", 8, 0)
end

---------------------------------------------------------------------------
-- Fenster
---------------------------------------------------------------------------
local function build()
  local f = CreateFrame("Frame", "DotColorsOptions", UIParent, BACKDROP_TEMPLATE)
  f:SetSize(W, H)
  f:SetPoint("CENTER")
  f:SetFrameStrata("DIALOG")
  f:SetToplevel(true)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:SetClampedToScreen(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)

  -- fester Untergrund, darauf der dunkle Marmor, darum der goldene Rahmen
  local base = f:CreateTexture(nil, "BACKGROUND", nil, -8)
  base:SetColorTexture(0.04, 0.03, 0.02, 1)
  base:SetPoint("TOPLEFT", 11, -12)
  base:SetPoint("BOTTOMRIGHT", -12, 11)
  local marble = f:CreateTexture(nil, "BACKGROUND", nil, -7)
  marble:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Background-Dark", "REPEAT", "REPEAT")
  pcall(marble.SetHorizTile, marble, true)
  pcall(marble.SetVertTile, marble, true)
  marble:SetPoint("TOPLEFT", 11, -12)
  marble:SetPoint("BOTTOMRIGHT", -12, 11)
  if f.SetBackdrop then
    f:SetBackdrop({ edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", edgeSize = 32,
      insets = { left = 11, right = 12, top = 12, bottom = 11 } })
  end

  -- ESC schliesst das Fenster (ohne UISpecialFrames, das wuerde Taint verursachen)
  f:SetScript("OnKeyDown", function(self, key)
    if InCombatLockdown() then return end
    if key == "ESCAPE" then
      self:SetPropagateKeyboardInput(false)
      self:Hide()
    else
      self:SetPropagateKeyboardInput(true)
    end
  end)
  f:RegisterEvent("PLAYER_REGEN_DISABLED")
  f:RegisterEvent("PLAYER_REGEN_ENABLED")
  f:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_REGEN_DISABLED" then
      self:EnableKeyboard(false)
    elseif self:IsShown() then
      self:EnableKeyboard(true)
      self:SetPropagateKeyboardInput(true)
    end
  end)

  local header = f:CreateTexture(nil, "ARTWORK")
  header:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
  header:SetSize(300, 64)
  header:SetPoint("TOP", 0, 12)
  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetPoint("TOP", header, "TOP", 0, -14)
  title:SetText("DotColors")

  local close, templated = tryTemplate("Button", f, "UIPanelCloseButton")
  if not templated then
    close:SetSize(32, 32)
    close:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
    close:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
    close:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight", "ADD")
  end
  close:SetPoint("TOPRIGHT", -6, -6)
  close:SetScript("OnClick", function() f:Hide() end)

  local sub = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  sub:SetPoint("TOP", 0, -30)
  sub:SetText("Farbige Schadenszahlen pro DoT.  |cff888888v" .. VERSION .. "|r")

  -- Seiten rechts
  local pages = {}
  for i = 1, 4 do
    local pg = CreateFrame("Frame", nil, f)
    pg:SetPoint("TOPLEFT", NAV_W, 0)
    pg:SetPoint("BOTTOMRIGHT", 0, 50)
    pages[i] = pg
  end
  buildGeneralPage(pages[1])
  buildLookPage(pages[2])
  buildColorPage(pages[3])
  buildPositionPage(pages[4])

  -- Seitenliste links
  local navBg = CreateFrame("Frame", nil, f, BACKDROP_TEMPLATE)
  navBg:SetPoint("TOPLEFT", 16, -50)
  navBg:SetPoint("BOTTOMRIGHT", f, "BOTTOMLEFT", NAV_W - 6, 50)
  if navBg.SetBackdrop then
    navBg:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 16,
      insets = { left = 4, right = 4, top = 4, bottom = 4 } })
    navBg:SetBackdropColor(0.05, 0.04, 0.03, 0.85)
    navBg:SetBackdropBorderColor(0.6, 0.5, 0.3, 1)
  end

  local navItems = {}
  local function select(i)
    for k, pg in ipairs(pages) do pg:SetShown(k == i) end
    for k, it in ipairs(navItems) do
      it.sel:SetShown(k == i)
      it.mark:SetShown(k == i)
      if k == i then it.label:SetTextColor(1, 1, 1) else it.label:SetTextColor(1, 0.82, 0) end
    end
    f.page = i
  end
  local NAV = { "Allgemein", "Darstellung", "Farben", "Position" }
  for i, label in ipairs(NAV) do
    local it = CreateFrame("Button", nil, navBg)
    it:SetSize(NAV_W - 34, 24)
    it:SetPoint("TOPLEFT", 9, -10 - (i - 1) * 26)
    it.sel = it:CreateTexture(nil, "BACKGROUND")
    it.sel:SetAllPoints()
    it.sel:SetTexture("Interface\\QuestFrame\\UI-QuestLogTitleHighlight")
    it.sel:SetVertexColor(1, 0.82, 0, 0.45)
    it.sel:SetBlendMode("ADD")
    it.mark = it:CreateTexture(nil, "ARTWORK")
    it.mark:SetColorTexture(1, 0.82, 0, 1)
    it.mark:SetSize(2, 18)
    it.mark:SetPoint("LEFT", 0, 0)
    it:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    it.label = it:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    it.label:SetPoint("LEFT", 10, 0)
    it.label:SetText(label)
    it:SetScript("OnClick", function() select(i) end)
    navItems[i] = it
  end

  -- Knoepfe unten
  local bClose = makeButton(f, "Schließen", 100, function() f:Hide() end)
  bClose:SetPoint("BOTTOMRIGHT", -22, 18)
  local bReset = makeButton(f, "Standard", 100, function() StaticPopup_Show("DOTCOLORS_RESET") end)
  bReset:SetPoint("RIGHT", bClose, "LEFT", -6, 0)
  tip(bReset, "Standard", "Setzt alle Einstellungen von DotColors zurück.")
  local bTest = makeButton(f, "Vorschau", 100, function() ns.runTest() end)
  bTest:SetPoint("RIGHT", bReset, "LEFT", -6, 0)
  tip(bTest, "Vorschau", "Zeigt Beispielzahlen in allen Farben, über deinem Ziel oder am Anker.")

  f:SetScript("OnShow", function(self)
    if InCombatLockdown() then
      self:EnableKeyboard(false)
    else
      self:EnableKeyboard(true)
      self:SetPropagateKeyboardInput(true)
    end
    refreshAll()
    select(self.page or 1)
  end)
  f:SetScript("OnHide", function()
    if ns.isMoving() then ns.setMoving(false) end
  end)
  f:Hide()
  return f
end

StaticPopupDialogs["DOTCOLORS_RESET"] = {
  text = "Alle DotColors-Einstellungen auf Standard zurücksetzen?",
  button1 = YES,
  button2 = NO,
  OnAccept = function()
    ns.resetAll()
    if frame then refreshAll() end
  end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
}

local function openOptions()
  frame = frame or build()
  frame:Show()
  frame:Raise()
end

ns.toggleOptions = function()
  frame = frame or build()
  frame:SetShown(not frame:IsShown())
end
ns.refreshOptions = function() if frame then refreshAll() end end
ns.onAnchorMoved = ns.refreshOptions

---------------------------------------------------------------------------
-- Eintrag unter ESC > Optionen > AddOns
---------------------------------------------------------------------------
local function registerSettings()
  local p = CreateFrame("Frame", "DotColorsSettingsPanel")
  p.name = "DotColors"
  local title = p:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText("DotColors")
  local text = p:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  text:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)
  text:SetWidth(520)
  text:SetJustifyH("LEFT")
  text:SetText("Farbige Schadenszahlen pro DoT. Alle Einstellungen sind im eigenen Fenster (auch: /dc).")
  local open = makeButton(p, "DotColors-Optionen öffnen", 200, openOptions)
  open:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -16)
  if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
    pcall(function()
      local cat = Settings.RegisterCanvasLayoutCategory(p, "DotColors")
      Settings.RegisterAddOnCategory(cat)
    end)
  elseif InterfaceOptions_AddCategory then
    pcall(InterfaceOptions_AddCategory, p)
  end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function() pcall(registerSettings) end)
