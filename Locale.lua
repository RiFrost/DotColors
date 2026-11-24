-- Locale.lua
-- User-facing text. English strings are the keys; a missing translation
-- falls back to the English key, so nothing ever shows up empty.

local _, ns = ...

local L = setmetatable({}, {
  __index = function(_, key) return key end,
})
ns.L = L

if GetLocale() ~= "deDE" then return end

-- Labels for each hit type
L["Corruption"] = "Verderbnis"
L["Bane of Agony"] = "Bann der Pein"
L["Immolate"] = "Feuerbrand"
L["Siphon Life"] = "Lebensentzug"
L["Lash of Pain (pet)"] = "Schmerzenspeitsche (Begleiter)"
L["Firebolt (pet)"] = "Feuerblitz (Begleiter)"
L["Drain Life / Drain Soul"] = "Blutsauger / Seelendieb"
L["Other Shadow"] = "Sonstiger Schatten"
L["Other Fire"] = "Sonstiges Feuer"
L["Physical"] = "Physisch"
L["Other"] = "Sonstiges"

-- Chat messages
L["Loaded. Type /dc for options."] = "Geladen. /dc öffnet die Optionen."
L["Please change this outside of combat."] = "Bitte außerhalb des Kampfes ändern."
L["on"] = "an"
L["off"] = "aus"
L["Blizzard damage numbers hidden: %s"] = "Blizzard-Schadenszahlen ausgeblendet: %s"
L["%s: was %s, now %s"] = "%s: vorher %s, jetzt %s"
L["None of the known settings found. Turn the numbers off in the game options."] =
  "Keine der bekannten Einstellungen gefunden. Bitte im Spielmenü abschalten."
L["Numbers above nameplates: %s"] = "Zahlen über der Nameplate: %s"
L["Drag the anchor, then type /dc move again."] = "Anker mit der Maus verschieben, danach erneut /dc move."
L["Anchor locked."] = "Anker gesperrt."
L["Spell icons: %s"] = "Zauber-Icons: %s"
L["Show physical damage: %s"] = "Physischen Schaden zeigen: %s"
L["Only recognized DoTs: %s"] = "Nur erkannte DoTs: %s"
L["Font size: %d"] = "Schriftgröße: %d"
L["Example: /dc size 20 (8-48)"] = "Beispiel: /dc size 20 (8-48)"
L["Example: /dc color agony 00ff66"] = "Beispiel: /dc color agony 00ff66"
L["Debug output in chat: %s"] = "Debug-Ausgabe im Chat: %s"
L["Settings reset."] = "Einstellungen zurückgesetzt."
L["%s | school %s | %s"] = "%s | Schule %s | %s"
L[" (off by %.2fs)"] = " (Abw. %.2fs)"
L["Error in %s: %s"] = "Fehler in %s: %s"
L["Unknown spell ID %d"] = "Unbekannte Zauber-ID %d"

-- Command help
L["Commands:"] = "Befehle:"
L["/dc - open the options window"] = "/dc - Optionsfenster öffnen"
L["/dc test - preview every color"] = "/dc test - Vorschau aller Farben"
L["/dc color [name] [hex] - change a color (no arguments: list)"] =
  "/dc color [name] [hex] - Farbe ändern (ohne Angaben: Liste)"
L["/dc size [n] - font size"] = "/dc size [n] - Schriftgröße"
L["/dc plates - numbers above nameplates"] = "/dc plates - Zahlen über der Nameplate"
L["/dc move - unlock the fixed anchor"] = "/dc move - festen Anker verschieben"
L["/dc icons - spell icons"] = "/dc icons - Zauber-Icons"
L["/dc physical - show physical damage"] = "/dc physical - physischen Schaden zeigen"
L["/dc only - only recognized DoTs"] = "/dc only - nur erkannte DoTs"
L["/dc blizz - hide Blizzard numbers (/dc blizz status: details)"] =
  "/dc blizz - Blizzard-Zahlen ausblenden (/dc blizz status: Details)"
L["/dc debug - write each hit to chat"] = "/dc debug - jeden Treffer im Chat mitschreiben"
L["/dc reset - reset all settings"] = "/dc reset - alles zurücksetzen"

-- Options window
L["Colored damage numbers per DoT."] = "Farbige Schadenszahlen pro DoT."
L["General"] = "Allgemein"
L["Display"] = "Darstellung"
L["Colors"] = "Farben"
L["Position"] = "Position"
L["Preview"] = "Vorschau"
L["Defaults"] = "Standard"
L["Close"] = "Schließen"
L["Shows sample numbers in every color, above your target or at the anchor."] =
  "Zeigt Beispielzahlen in allen Farben, über deinem Ziel oder am Anker."
L["Resets every DotColors setting."] = "Setzt alle Einstellungen von DotColors zurück."
L["Reset every DotColors setting to its default?"] = "Alle DotColors-Einstellungen auf Standard zurücksetzen?"

L["Numbers"] = "Zahlen"
L["Show above nameplates"] = "An der Nameplate anzeigen"
L["Numbers appear above the enemy that was hit. Off: every number appears at the fixed anchor (Position page)."] =
  "Zahlen erscheinen über dem getroffenen Gegner. Aus: alle Zahlen am festen Anker (Seite Position)."
L["Spell icons"] = "Zauber-Icons"
L["A small spell icon next to each number."] = "Kleines Icon des Zaubers neben der Zahl."
L["Show physical damage"] = "Physischen Schaden zeigen"
L["For example your demon's melee attacks."] = "Zum Beispiel den Nahkampf deines Dämons."
L["Only recognized DoTs"] = "Nur erkannte DoTs zeigen"
L["Hide everything that could not be matched to a DoT."] = "Alles ausblenden, was keinem DoT zugeordnet werden konnte."
L["Blizzard"] = "Blizzard"
L["Hide Blizzard damage numbers"] = "Blizzard-Schadenszahlen ausblenden"
L["Turns off the game's own numbers above enemies so nothing shows twice. Can only be changed out of combat."] =
  "Schaltet die normalen Zahlen über Gegnern ab, damit nichts doppelt erscheint. Nur außerhalb des Kampfes änderbar."
L["Troubleshooting"] = "Fehlersuche"
L["Write matches to chat"] = "Zuordnung im Chat mitschreiben"
L["Writes every hit and the DoT it was matched to into chat."] =
  "Schreibt für jeden Treffer in den Chat, welchem DoT er zugeordnet wurde."

L["Size and movement"] = "Größe und Bewegung"
L["Font size"] = "Schriftgröße"
L["Display time"] = "Anzeigedauer"
L["Rise height"] = "Steighöhe"
L["Spacing between spells"] = "Abstand zwischen Zaubern"
L["Each spell has its own column. Raise the spacing if numbers overlap."] =
  "Jeder Zauber hat eine eigene Spalte. Überlappen sich Zahlen, den Abstand erhöhen."
L["Critical hits are shown larger automatically. Use \"Preview\" below to see the effect."] =
  "Krits werden automatisch größer dargestellt. Mit \"Vorschau\" unten siehst du die Wirkung sofort."

L["Color per spell"] = "Farbe pro Zauber"
L["Left-click: pick a color   Shift-click: sample   Right-click: default"] =
  "Linksklick: Farbe wählen   Shift-Klick: Beispielzahl   Rechtsklick: Standard"
L["Left-click: pick a color"] = "Linksklick: Farbe wählen"
L["Shift-click: show a sample number"] = "Shift-Klick: Beispielzahl anzeigen"
L["Right-click: default color"] = "Rechtsklick: Standardfarbe"

L["Fixed anchor"] = "Fester Anker"
L["The anchor is used when \"Show above nameplates\" is off or the enemy has no visible nameplate."] =
  "Der Anker wird benutzt, wenn \"An der Nameplate anzeigen\" aus ist oder der Gegner keine sichtbare Nameplate hat."
L["Horizontal"] = "Horizontal"
L["Vertical"] = "Vertikal"
L["Move anchor"] = "Anker verschieben"
L["Lock anchor"] = "Anker sperren"
L["Shows the anchor as a purple box. Drag it with the mouse, then lock it."] =
  "Zeigt den Anker als lila Kasten an. Mit der Maus ziehen, danach sperren."
L["Back to center"] = "Zurück zur Mitte"

L["Minimap"] = "Minikarte"
L["Show minimap button"] = "Button an der Minikarte zeigen"
L["The round button at the edge of the minimap. Drag it to move it along the edge."] =
  "Der runde Button am Rand der Minikarte. Ziehen, um ihn am Rand zu verschieben."
L["Left-click: open options"] = "Linksklick: Optionen öffnen"
L["Right-click: preview"] = "Rechtsklick: Vorschau"
L["Drag: move the button"] = "Ziehen: Button verschieben"
L["Minimap button: %s"] = "Button an der Minikarte: %s"
L["/dc minimap - minimap button"] = "/dc minimap - Button an der Minikarte"

L["All settings are in DotColors' own window (also: /dc)."] =
  "Alle Einstellungen sind im eigenen Fenster von DotColors (auch: /dc)."
L["Open DotColors options"] = "DotColors-Optionen öffnen"
