-- Widgets.lua
-- Small building blocks for the options window in the classic look:
-- gold-bordered dialog, checkboxes, sliders, buttons and color rows.
--
-- Every control that shows a setting is created through a "form". The form
-- remembers its controls so it can refresh them all when the window opens
-- or the settings are reset.

local _, ns = ...

local Widgets = {}
ns.Widgets = Widgets

local BACKDROP = BackdropTemplateMixin and "BackdropTemplate" or nil
local GOLD = { 1, 0.82, 0 }

---------------------------------------------------------------------------
-- Forms
---------------------------------------------------------------------------
local Form = {}
Form.__index = Form

--- A new, empty form.
function Widgets.newForm()
  return setmetatable({ controls = {} }, Form)
end

--- Adds a control. Its refresh function is called by Form:refresh().
function Form:add(control, refresh)
  control.refresh = refresh
  self.controls[#self.controls + 1] = control
  return control
end

--- Updates every control to show the current settings.
function Form:refresh()
  for _, control in ipairs(self.controls) do control.refresh() end
end

---------------------------------------------------------------------------
-- Simple pieces
---------------------------------------------------------------------------

--- Shows a tooltip with a gold title and white text while the mouse is over the widget.
function Widgets.setTooltip(widget, title, text)
  widget:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(title, GOLD[1], GOLD[2], GOLD[3])
    if text then GameTooltip:AddLine(text, 1, 1, 1, true) end
    GameTooltip:Show()
  end)
  widget:SetScript("OnLeave", GameTooltip_Hide)
end

--- A heading with a thin gold rule that runs to the right edge of the parent.
function Widgets.heading(parent, text, x, y)
  local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  label:SetPoint("TOPLEFT", x, y)
  label:SetText(text)
  local rule = parent:CreateTexture(nil, "ARTWORK")
  rule:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.25)
  rule:SetHeight(1)
  rule:SetPoint("LEFT", label, "RIGHT", 8, 0)
  rule:SetPoint("RIGHT", parent, "RIGHT", -24, 0)
  return label
end

--- A grey explanatory text that wraps at the given width.
function Widgets.note(parent, text, x, y, width)
  local label = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  label:SetPoint("TOPLEFT", x, y)
  label:SetWidth(width or 420)
  label:SetJustifyH("LEFT")
  label:SetText(text)
  return label
end

--- A red classic panel button.
function Widgets.button(parent, text, width, onClick)
  local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  button:SetSize(width, 22)
  button:SetText(text)
  button:SetScript("OnClick", onClick)
  return button
end

---------------------------------------------------------------------------
-- Setting controls
---------------------------------------------------------------------------

--- A checkbox bound to a setting.
--- options: label, tooltip, get(), set(value). set may return false to refuse the change.
function Form:checkbox(parent, options)
  local box = CreateFrame("CheckButton", nil, parent)
  box:SetSize(26, 26)
  box:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
  box:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
  box:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
  box:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")

  local label = box:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  label:SetPoint("LEFT", box, "RIGHT", 2, 1)
  label:SetText(options.label)
  -- make the label clickable too
  box:SetHitRectInsets(0, -(label:GetStringWidth() + 8), 0, 0)

  box:SetScript("OnClick", function()
    local accepted = options.set(box:GetChecked() and true or false)
    if accepted == false then box:SetChecked(options.get() and true or false) end
  end)
  Widgets.setTooltip(box, options.label, options.tooltip)

  return self:add(box, function() box:SetChecked(options.get() and true or false) end)
end

--- A horizontal slider bound to a number setting.
--- options: label, min, max, step, format(value) -> text, get(), set(value).
function Form:slider(parent, options)
  local slider = CreateFrame("Slider", nil, parent, BACKDROP)
  slider:SetOrientation("HORIZONTAL")
  slider:SetSize(220, 17)
  slider:SetMinMaxValues(options.min, options.max)
  slider:SetValueStep(options.step)
  if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end
  slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
  if slider.SetBackdrop then
    slider:SetBackdrop({
      bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
      edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
      tile = true, tileSize = 8, edgeSize = 8,
      insets = { left = 3, right = 3, top = 6, bottom = 6 },
    })
  end

  local title = slider:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  title:SetPoint("BOTTOMLEFT", slider, "TOPLEFT", 0, 3)
  title:SetText(options.label)
  local valueText = slider:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  valueText:SetPoint("LEFT", slider, "RIGHT", 8, 0)
  local minText = slider:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  minText:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 2, 0)
  minText:SetText(options.format(options.min))
  local maxText = slider:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  maxText:SetPoint("TOPRIGHT", slider, "BOTTOMRIGHT", -2, 0)
  maxText:SetText(options.format(options.max))

  local function snap(value)
    return math.floor(value / options.step + 0.5) * options.step
  end

  local refreshing = false
  slider:SetScript("OnValueChanged", function(_, value)
    value = snap(value)
    valueText:SetText(options.format(value))
    if not refreshing then options.set(value) end
  end)
  slider:EnableMouseWheel(true)
  slider:SetScript("OnMouseWheel", function(_, delta)
    slider:SetValue(slider:GetValue() + delta * options.step)
  end)

  return self:add(slider, function()
    refreshing = true
    slider:SetValue(options.get())
    valueText:SetText(options.format(snap(options.get())))
    refreshing = false
  end)
end

--- Opens the game's color picker. onChange(r, g, b) is called while the
--- player picks, and with the old color if they cancel.
function Widgets.pickColor(color, onChange)
  local picker = ColorPickerFrame
  if not picker then return end
  local r, g, b = color[1], color[2], color[3]
  local function current() onChange(picker:GetColorRGB()) end
  local function cancel() onChange(r, g, b) end

  if picker.SetupColorPickerAndShow then
    picker:SetupColorPickerAndShow({ r = r, g = g, b = b, hasOpacity = false, swatchFunc = current, cancelFunc = cancel })
  else
    picker.hasOpacity = false
    picker.previousValues = { r, g, b }
    picker.func, picker.cancelFunc = current, cancel
    picker:SetColorRGB(r, g, b)
    ShowUIPanel(picker)
  end
  pcall(picker.SetFrameStrata, picker, "FULLSCREEN_DIALOG")
end

--- A row with a color swatch, a label and a sample number in that color.
--- options: label, get() -> {r,g,b}, set({r,g,b}), default {r,g,b}, preview().
function Form:colorRow(parent, options)
  local row = CreateFrame("Button", nil, parent)
  row:SetSize(400, 20)
  row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

  local border = row:CreateTexture(nil, "BACKGROUND")
  border:SetColorTexture(0, 0, 0, 1)
  border:SetSize(16, 16)
  border:SetPoint("LEFT", 3, 0)
  local swatch = row:CreateTexture(nil, "ARTWORK")
  swatch:SetSize(14, 14)
  swatch:SetPoint("CENTER", border)

  local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  label:SetPoint("LEFT", border, "RIGHT", 8, 0)
  label:SetText(options.label)

  local sample = row:CreateFontString(nil, "OVERLAY")
  sample:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 15, "OUTLINE")
  sample:SetPoint("RIGHT", -8, 0)
  sample:SetText("1234")

  local function show(color)
    swatch:SetColorTexture(color[1], color[2], color[3], 1)
    sample:SetTextColor(color[1], color[2], color[3])
  end

  local function setColor(r, g, b)
    options.set({ r, g, b })
    show(options.get())
  end

  row:SetScript("OnClick", function(_, mouseButton)
    if mouseButton == "RightButton" then
      setColor(options.default[1], options.default[2], options.default[3])
    elseif IsShiftKeyDown() then
      options.preview()
    else
      Widgets.pickColor(options.get(), setColor)
    end
  end)
  Widgets.setTooltip(row, options.label, options.tooltip)

  return self:add(row, function() show(options.get()) end)
end

---------------------------------------------------------------------------
-- Dialog window
---------------------------------------------------------------------------

--- Lets Escape close the window without touching Blizzard's own tables
--- (adding to UISpecialFrames would taint them). Keyboard capture is not
--- allowed in combat, so the window lets every key through while fighting.
local function closeOnEscape(window)
  local function updateKeyboard()
    local inCombat = InCombatLockdown()
    window:EnableKeyboard(not inCombat)
    if not inCombat then window:SetPropagateKeyboardInput(true) end
  end

  window:SetScript("OnKeyDown", function(self, key)
    if InCombatLockdown() then return end
    local isEscape = key == "ESCAPE"
    self:SetPropagateKeyboardInput(not isEscape)
    if isEscape then self:Hide() end
  end)
  window:RegisterEvent("PLAYER_REGEN_DISABLED")
  window:RegisterEvent("PLAYER_REGEN_ENABLED")
  window:SetScript("OnEvent", function(self)
    if self:IsShown() then updateKeyboard() end
  end)
  window:HookScript("OnShow", updateKeyboard)
end

--- A movable dialog: dark marble inside a gold border, a title plate on
--- top and a close button. Escape closes it.
function Widgets.dialog(name, title, width, height)
  local window = CreateFrame("Frame", name, UIParent, BACKDROP)
  window:SetSize(width, height)
  window:SetPoint("CENTER")
  window:SetFrameStrata("DIALOG")
  window:SetToplevel(true)
  window:SetClampedToScreen(true)
  window:EnableMouse(true)
  window:SetMovable(true)
  window:RegisterForDrag("LeftButton")
  window:SetScript("OnDragStart", window.StartMoving)
  window:SetScript("OnDragStop", window.StopMovingOrSizing)

  -- The marble texture is partly see-through, so a solid layer goes under it.
  local solid = window:CreateTexture(nil, "BACKGROUND", nil, -8)
  solid:SetColorTexture(0.04, 0.03, 0.02, 1)
  solid:SetPoint("TOPLEFT", 11, -12)
  solid:SetPoint("BOTTOMRIGHT", -12, 11)
  local marble = window:CreateTexture(nil, "BACKGROUND", nil, -7)
  marble:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Background-Dark", "REPEAT", "REPEAT")
  marble:SetHorizTile(true)
  marble:SetVertTile(true)
  marble:SetAllPoints(solid)
  if window.SetBackdrop then
    window:SetBackdrop({
      edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", edgeSize = 32,
      insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
  end

  local plate = window:CreateTexture(nil, "ARTWORK")
  plate:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
  plate:SetSize(300, 64)
  plate:SetPoint("TOP", 0, 12)
  local titleText = window:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  titleText:SetPoint("TOP", plate, "TOP", 0, -14)
  titleText:SetText(title)

  local close = CreateFrame("Button", nil, window, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -6, -6)

  closeOnEscape(window)
  window:Hide()
  return window
end

--- A list of page names on the left of a window. Clicking one shows its page.
--- pages: { { title = text, frame = frame }, ... }. Returns a function select(index).
function Widgets.pageList(window, pages, width)
  local list = CreateFrame("Frame", nil, window, BACKDROP)
  list:SetPoint("TOPLEFT", 16, -50)
  list:SetPoint("BOTTOMRIGHT", window, "BOTTOMLEFT", width - 6, 50)
  if list.SetBackdrop then
    list:SetBackdrop({
      bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true, tileSize = 16, edgeSize = 16,
      insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    list:SetBackdropColor(0.05, 0.04, 0.03, 0.85)
    list:SetBackdropBorderColor(0.6, 0.5, 0.3, 1)
  end

  local entries = {}

  local function select(index)
    for i, page in ipairs(pages) do
      local active = i == index
      page.frame:SetShown(active)
      entries[i].marker:SetShown(active)
      entries[i].glow:SetShown(active)
      entries[i].label:SetTextColor(active and 1 or GOLD[1], active and 1 or GOLD[2], active and 1 or GOLD[3])
    end
  end

  for i, page in ipairs(pages) do
    local entry = CreateFrame("Button", nil, list)
    entry:SetSize(width - 34, 24)
    entry:SetPoint("TOPLEFT", 9, -10 - (i - 1) * 26)
    entry:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

    entry.glow = entry:CreateTexture(nil, "BACKGROUND")
    entry.glow:SetAllPoints()
    entry.glow:SetTexture("Interface\\QuestFrame\\UI-QuestLogTitleHighlight")
    entry.glow:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 0.45)
    entry.glow:SetBlendMode("ADD")

    entry.marker = entry:CreateTexture(nil, "ARTWORK")
    entry.marker:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
    entry.marker:SetSize(2, 18)
    entry.marker:SetPoint("LEFT")

    entry.label = entry:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    entry.label:SetPoint("LEFT", 10, 0)
    entry.label:SetText(page.title)

    entry:SetScript("OnClick", function() select(i) end)
    entries[i] = entry
  end

  return select
end
