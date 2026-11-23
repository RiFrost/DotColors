-- Commands.lua
-- The /dc chat commands.

local _, ns = ...
local L = ns.L

local MIN_FONT_SIZE, MAX_FONT_SIZE = 8, 48

local commands = {}

function commands.test()
  ns.showPreview()
end

function commands.blizz(argument)
  if InCombatLockdown() then
    ns.print(L["Please change this outside of combat."])
    return
  end
  if argument ~= "status" then
    ns.db.hideBlizzardNumbers = not ns.db.hideBlizzardNumbers
  end
  ns.print(string.format(L["Blizzard damage numbers hidden: %s"], ns.onOff(ns.db.hideBlizzardNumbers)))
  ns.applyBlizzardNumbers(true)
end

function commands.plates()
  ns.db.showOnNameplates = not ns.db.showOnNameplates
  ns.print(string.format(L["Numbers above nameplates: %s"], ns.onOff(ns.db.showOnNameplates)))
end

function commands.move()
  local unlock = not ns.isAnchorUnlocked()
  ns.setAnchorUnlocked(unlock)
  ns.print(unlock and L["Drag the anchor, then type /dc move again."] or L["Anchor locked."])
end

function commands.icons()
  ns.db.showIcons = not ns.db.showIcons
  ns.print(string.format(L["Spell icons: %s"], ns.onOff(ns.db.showIcons)))
end

function commands.physical()
  ns.db.showPhysical = not ns.db.showPhysical
  ns.print(string.format(L["Show physical damage: %s"], ns.onOff(ns.db.showPhysical)))
end

function commands.only()
  ns.db.onlyDots = not ns.db.onlyDots
  ns.print(string.format(L["Only recognized DoTs: %s"], ns.onOff(ns.db.onlyDots)))
end

function commands.size(argument)
  local size = tonumber(argument)
  if size and size >= MIN_FONT_SIZE and size <= MAX_FONT_SIZE then
    ns.db.fontSize = size
    ns.print(string.format(L["Font size: %d"], size))
  else
    ns.print(L["Example: /dc size 20 (8-48)"])
  end
end

function commands.color(argument, hex)
  local key = argument and argument:lower()
  local r, g, b = ns.fromHex(hex)
  if key and ns.db.colors[key] and r then
    ns.db.colors[key] = { r, g, b }
    ns.print(string.format("%s -> |cff%s%s|r", ns.KIND_BY_KEY[key].label, ns.toHex(ns.db.colors[key]), ns.toHex(ns.db.colors[key])))
    return
  end
  ns.print(L["Example: /dc color agony 00ff66"])
  for _, kind in ipairs(ns.KINDS) do
    print(string.format("  |cff%s%s|r = %s", ns.toHex(ns.db.colors[kind.key]), kind.key, kind.label))
  end
end

function commands.debug()
  ns.db.debug = not ns.db.debug
  ns.print(string.format(L["Debug output in chat: %s"], ns.onOff(ns.db.debug)))
end

function commands.reset()
  ns.resetSettings()
  ns.placeAnchor()
  if ns.refreshOptions then ns.refreshOptions() end
  ns.print(L["Settings reset."])
end

function commands.help()
  ns.print(L["Commands:"])
  for _, line in ipairs({
    L["/dc - open the options window"],
    L["/dc test - preview every color"],
    L["/dc color [name] [hex] - change a color (no arguments: list)"],
    L["/dc size [n] - font size"],
    L["/dc plates - numbers above nameplates"],
    L["/dc move - unlock the fixed anchor"],
    L["/dc icons - spell icons"],
    L["/dc physical - show physical damage"],
    L["/dc only - only recognized DoTs"],
    L["/dc blizz - hide Blizzard numbers (/dc blizz status: details)"],
    L["/dc debug - write each hit to chat"],
    L["/dc reset - reset all settings"],
  }) do
    print("  " .. line)
  end
end

SLASH_DOTCOLORS1 = "/dc"
SLASH_DOTCOLORS2 = "/dotcolors"
SlashCmdList.DOTCOLORS = function(input)
  local name, first, second = (input or ""):match("^(%S*)%s*(%S*)%s*(%S*)")
  name = name:lower()
  if name == "" then
    ns.toggleOptions()
  elseif commands[name] then
    commands[name](first, second)
  else
    commands.help()
  end
end
