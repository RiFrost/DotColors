-- Minimap.lua
-- A round button on the edge of the minimap that opens the options,
-- and the entry in the AddOn compartment (the puzzle menu at the minimap).

local _, ns = ...
local L = ns.L

-- Corruption's icon, until DotColors has its own.
local ICON = "Interface\\Icons\\Spell_Shadow_AbominationExplosion"
local EDGE_OFFSET = 10  -- pixels outside the minimap's edge

local button

--- Puts the button on the minimap's edge at the saved angle.
local function placeButton()
  local angle = math.rad(ns.db.minimap.angle)
  local radius = Minimap:GetWidth() / 2 + EDGE_OFFSET
  button:ClearAllPoints()
  button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

--- While dragging: moves the button along the edge toward the cursor.
local function followCursor()
  local centerX, centerY = Minimap:GetCenter()
  local scale = Minimap:GetEffectiveScale()
  local cursorX, cursorY = GetCursorPosition()
  local atan2 = math.atan2 or math.atan
  ns.db.minimap.angle = math.deg(atan2(cursorY / scale - centerY, cursorX / scale - centerX)) % 360
  placeButton()
end

--- Left-click opens the options, right-click shows the preview.
local function onClick(mouseButton)
  if mouseButton == "RightButton" then
    ns.showPreview()
  else
    ns.toggleOptions()
  end
end

local function showTooltip(owner)
  GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
  GameTooltip:SetText("DotColors", 1, 0.82, 0)
  GameTooltip:AddLine(L["Left-click: open options"], 1, 1, 1)
  GameTooltip:AddLine(L["Right-click: preview"], 1, 1, 1)
  GameTooltip:AddLine(L["Drag: move the button"], 0.7, 0.7, 0.7)
  GameTooltip:Show()
end

--- Creates the button in the classic round minimap style.
function ns.createMinimapButton()
  if button or not Minimap then return end

  button = CreateFrame("Button", "DotColorsMinimapButton", Minimap)
  button:SetSize(31, 31)
  button:SetFrameStrata("MEDIUM")
  button:SetFrameLevel(8)
  button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  button:RegisterForDrag("LeftButton")
  button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

  local background = button:CreateTexture(nil, "BACKGROUND")
  background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
  background:SetSize(20, 20)
  background:SetPoint("TOPLEFT", 7, -5)

  local icon = button:CreateTexture(nil, "ARTWORK")
  icon:SetTexture(ICON)
  icon:SetSize(17, 17)
  icon:SetPoint("TOPLEFT", 7, -6)
  icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)

  local border = button:CreateTexture(nil, "OVERLAY")
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  border:SetSize(53, 53)
  border:SetPoint("TOPLEFT")

  button:SetScript("OnClick", function(_, mouseButton) onClick(mouseButton) end)
  button:SetScript("OnDragStart", function(self) self:SetScript("OnUpdate", followCursor) end)
  button:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
  button:SetScript("OnEnter", showTooltip)
  button:SetScript("OnLeave", GameTooltip_Hide)

  ns.updateMinimapButton()
end

--- Shows or hides the button following the setting.
function ns.updateMinimapButton()
  if not button then return end
  button:SetShown(ns.db.minimap.show)
  placeButton()
end

-- Called by the AddOn compartment; the function name is set in the .toc,
-- which is why it has to be global.
function DotColors_OnAddonCompartmentClick(_, mouseButton)
  onClick(mouseButton)
end
