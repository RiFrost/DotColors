-- Options.lua
-- The options window (/dc) and its entry under Escape > Options > AddOns.

local _, ns = ...
local L = ns.L
local Widgets = ns.Widgets

local WINDOW_WIDTH, WINDOW_HEIGHT = 640, 490
local PAGE_LIST_WIDTH = 160
local LEFT = 26  -- left edge of a page's content

local form = Widgets.newForm()
local window
local currentPage = 1

local function integer(value) return tostring(math.floor(value + 0.5)) end
local function seconds(value) return string.format("%.1f s", value) end
local function pixels(value) return integer(value) .. " px" end
local function percent(value) return integer(value) .. " %" end

--- A checkbox for a simple on/off setting.
local function settingCheckbox(page, key, label, tooltip, y)
  form:checkbox(page, {
    label = label,
    tooltip = tooltip,
    get = function() return ns.db[key] end,
    set = function(value) ns.db[key] = value end,
  }):SetPoint("TOPLEFT", LEFT, y)
end

local function buildGeneralPage(page)
  Widgets.heading(page, L["Numbers"], 24, -54)
  settingCheckbox(page, "showOnNameplates", L["Show above nameplates"],
    L["Numbers appear above the enemy that was hit. Off: every number appears at the fixed anchor (Position page)."], -78)
  settingCheckbox(page, "showIcons", L["Spell icons"], L["A small spell icon next to each number."], -104)
  settingCheckbox(page, "showPhysical", L["Show physical damage"], L["For example your demon's melee attacks."], -130)
  settingCheckbox(page, "onlyDots", L["Only recognized DoTs"], L["Hide everything that could not be matched to a DoT."], -156)

  Widgets.heading(page, L["Blizzard"], 24, -194)
  form:checkbox(page, {
    label = L["Hide Blizzard damage numbers"],
    tooltip = L["Turns off the game's own numbers above enemies so nothing shows twice. Can only be changed out of combat."],
    get = function() return ns.db.hideBlizzardNumbers end,
    set = function(value)
      if InCombatLockdown() then
        ns.print(L["Please change this outside of combat."])
        return false
      end
      ns.db.hideBlizzardNumbers = value
      ns.applyBlizzardNumbers()
    end,
  }):SetPoint("TOPLEFT", LEFT, -218)

  Widgets.heading(page, L["Minimap"], 24, -256)
  form:checkbox(page, {
    label = L["Show minimap button"],
    tooltip = L["The round button at the edge of the minimap. Drag it to move it along the edge."],
    get = function() return ns.db.minimap.show end,
    set = function(value)
      ns.db.minimap.show = value
      ns.updateMinimapButton()
    end,
  }):SetPoint("TOPLEFT", LEFT, -280)

  Widgets.heading(page, L["Troubleshooting"], 24, -318)
  settingCheckbox(page, "debug", L["Write matches to chat"], L["Writes every hit and the DoT it was matched to into chat."], -342)
end

local function buildDisplayPage(page)
  Widgets.heading(page, L["Size and movement"], 24, -54)
  local sliders = {
    { key = "fontSize",   label = L["Font size"],    min = 8,   max = 40,  step = 1,   format = integer },
    { key = "duration",   label = L["Display time"], min = 0.6, max = 4,   step = 0.1, format = seconds },
    { key = "riseHeight", label = L["Rise height"],  min = 0,   max = 200, step = 5,   format = pixels },
    { key = "laneSpacing", label = L["Spacing between spells"], min = 50, max = 250, step = 10, format = percent },
    { key = "numberGap",  label = L["Gap between stacked numbers"], min = 0, max = 40, step = 1, format = pixels },
  }
  for i, s in ipairs(sliders) do
    form:slider(page, {
      label = s.label, min = s.min, max = s.max, step = s.step, format = s.format,
      get = function() return ns.db[s.key] end,
      set = function(value) ns.db[s.key] = value end,
    }):SetPoint("TOPLEFT", LEFT + 4, -98 - (i - 1) * 48)
  end
  local spacingNote = Widgets.note(page, L["Each spell has its own column. Numbers overlapping side by side: raise the spacing between spells. On top of each other: raise the gap."], LEFT + 4, -336)
  local critNote = Widgets.note(page, L["Critical hits are shown larger automatically. Use \"Preview\" below to see the effect."], LEFT + 4, 0)
  critNote:ClearAllPoints()
  critNote:SetPoint("TOPLEFT", spacingNote, "BOTTOMLEFT", 0, -6)  -- follows the first note, however many lines it wraps to
end

local function buildColorsPage(page)
  Widgets.heading(page, L["Color per spell"], 24, -54)
  local tooltip = L["Left-click: pick a color"] .. "\n" .. L["Shift-click: show a sample number"] .. "\n" .. L["Right-click: default color"]
  local y = -76
  for _, kind in ipairs(ns.KINDS) do
    form:colorRow(page, {
      label = kind.label,
      tooltip = tooltip,
      default = ns.DEFAULTS.colors[kind.key],
      get = function() return ns.db.colors[kind.key] end,
      set = function(color) ns.db.colors[kind.key] = color end,
      preview = function() ns.showSample(kind.key) end,
    }):SetPoint("TOPLEFT", 24, y)
    y = y - 22
  end
  Widgets.note(page, L["Left-click: pick a color   Shift-click: sample   Right-click: default"], 28, y - 8)
end

local function buildPositionPage(page)
  Widgets.heading(page, L["Fixed anchor"], 24, -54)
  Widgets.note(page, L["The anchor is used when \"Show above nameplates\" is off or the enemy has no visible nameplate."], 28, -76)

  local axes = {
    { key = "anchorX", label = L["Horizontal"], limit = 800 },
    { key = "anchorY", label = L["Vertical"],   limit = 500 },
  }
  for i, axis in ipairs(axes) do
    form:slider(page, {
      label = axis.label, min = -axis.limit, max = axis.limit, step = 5, format = integer,
      get = function() return ns.db[axis.key] end,
      set = function(value) ns.db[axis.key] = value; ns.placeAnchor() end,
    }):SetPoint("TOPLEFT", LEFT + 4, -128 - (i - 1) * 48)
  end

  local move = Widgets.button(page, L["Move anchor"], 150, function()
    ns.setAnchorUnlocked(not ns.isAnchorUnlocked())
    form:refresh()
  end)
  move:SetPoint("TOPLEFT", LEFT + 2, -214)
  Widgets.setTooltip(move, L["Move anchor"], L["Shows the anchor as a purple box. Drag it with the mouse, then lock it."])
  form:add(move, function() move:SetText(ns.isAnchorUnlocked() and L["Lock anchor"] or L["Move anchor"]) end)

  local center = Widgets.button(page, L["Back to center"], 150, function()
    ns.db.anchorX, ns.db.anchorY = ns.DEFAULTS.anchorX, ns.DEFAULTS.anchorY
    ns.placeAnchor()
    form:refresh()
  end)
  center:SetPoint("LEFT", move, "RIGHT", 8, 0)
end

--- Builds the window the first time it is needed.
local function buildWindow()
  window = Widgets.dialog("DotColorsOptions", "DotColors", WINDOW_WIDTH, WINDOW_HEIGHT)

  local subtitle = window:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  subtitle:SetPoint("TOP", 0, -30)
  subtitle:SetText(L["Colored damage numbers per DoT."] .. "  |cff888888v" .. ns.VERSION .. "|r")

  local pages = {
    { title = L["General"],  build = buildGeneralPage },
    { title = L["Display"],  build = buildDisplayPage },
    { title = L["Colors"],   build = buildColorsPage },
    { title = L["Position"], build = buildPositionPage },
  }
  for _, page in ipairs(pages) do
    page.frame = CreateFrame("Frame", nil, window)
    page.frame:SetPoint("TOPLEFT", PAGE_LIST_WIDTH, 0)
    page.frame:SetPoint("BOTTOMRIGHT", 0, 50)
    page.build(page.frame)
  end

  local selectPage = Widgets.pageList(window, pages, PAGE_LIST_WIDTH)
  for i, page in ipairs(pages) do
    page.frame:HookScript("OnShow", function() currentPage = i end)
  end

  local close = Widgets.button(window, L["Close"], 100, function() window:Hide() end)
  close:SetPoint("BOTTOMRIGHT", -22, 18)
  local defaults = Widgets.button(window, L["Defaults"], 100, function() StaticPopup_Show("DOTCOLORS_RESET") end)
  defaults:SetPoint("RIGHT", close, "LEFT", -6, 0)
  Widgets.setTooltip(defaults, L["Defaults"], L["Resets every DotColors setting."])
  local preview = Widgets.button(window, L["Preview"], 100, ns.showPreview)
  preview:SetPoint("RIGHT", defaults, "LEFT", -6, 0)
  Widgets.setTooltip(preview, L["Preview"], L["Shows sample numbers in every color, above your target or at the anchor."])

  window:HookScript("OnShow", function()
    form:refresh()
    selectPage(currentPage)
  end)
  window:HookScript("OnHide", function()
    ns.setAnchorUnlocked(false)
  end)
end

StaticPopupDialogs["DOTCOLORS_RESET"] = {
  text = L["Reset every DotColors setting to its default?"],
  button1 = YES,
  button2 = NO,
  OnAccept = function()
    ns.resetSettings()
    ns.placeAnchor()
    ns.updateMinimapButton()
    ns.refreshOptions()
  end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
}

--- Shows the window, building it first if needed.
local function openOptions()
  if not window then buildWindow() end
  window:Show()
  window:Raise()
end

--- Opens the window, or closes it if it is open.
function ns.toggleOptions()
  if window and window:IsShown() then
    window:Hide()
  else
    openOptions()
  end
end

--- Updates the window's controls after settings changed elsewhere.
function ns.refreshOptions()
  if window then form:refresh() end
end

--- Adds a DotColors entry under Escape > Options > AddOns with a button
--- that opens the real window. Uses only the official registration calls.
function ns.registerSettingsPanel()
  local panel = CreateFrame("Frame")
  panel.name = "DotColors"

  local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText("DotColors")
  local text = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  text:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)
  text:SetWidth(520)
  text:SetJustifyH("LEFT")
  text:SetText(L["All settings are in DotColors' own window (also: /dc)."])
  Widgets.button(panel, L["Open DotColors options"], 200, openOptions)
    :SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -16)

  if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
    Settings.RegisterAddOnCategory(Settings.RegisterCanvasLayoutCategory(panel, "DotColors"))
  elseif InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(panel)
  end
end
