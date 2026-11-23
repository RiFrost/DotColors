# DotColors

**Colored damage numbers per damage-over-time spell for WoW: Forever.**

As a Warlock you have several DoTs ticking on the same target, and the default damage numbers all look alike. DotColors replaces them with its own floating numbers and gives every DoT its own color, so you can see at a glance which tick came from which spell.

| Spell | Default color |
|-------|---------------|
| Corruption | purple |
| Bane of Agony | poison green |
| Immolate | orange |
| Siphon Life | teal |
| Lash of Pain (Succubus) | pink |
| Drain Life / Drain Soul | blue |

> **Status:** early development. Built and tested for Warlocks on WoW: Forever (interface 16001).

## Features

- Own floating damage numbers, one color per DoT
- Numbers appear above the enemy's nameplate, or at a fixed anchor you can move
- Critical hits are shown larger
- Optional spell icon next to each number
- Hides Blizzard's own damage numbers so nothing shows twice
- Options window to change colors, font size, display time, rise height and position

## Installation

1. Download the latest release.
2. Extract the `DotColors` folder into
   `World of Warcraft\_forever_\Interface\AddOns\`
3. Check the folder structure: the file must be at
   `AddOns\DotColors\DotColors.toc`, not one folder deeper.
4. **Restart the game completely.** `/reload` does not pick up newly installed addons.

## Usage

Type `/dc` to open the options window. It has four pages:

- **General:** where numbers appear, icons, physical damage, hiding Blizzard's numbers
- **Display:** font size, display time, rise height
- **Colors:** click a color to change it, Shift-click for a sample number, right-click to reset it
- **Position:** move the fixed anchor used when no nameplate is visible

### Commands

| Command | What it does |
|---------|--------------|
| `/dc` | Open or close the options window |
| `/dc test` | Show sample numbers in every color |
| `/dc color <name> <hex>` | Change a color, e.g. `/dc color agony 00ff66` (no arguments: list all) |
| `/dc size <8-48>` | Set the font size |
| `/dc move` | Unlock the fixed anchor to drag it |
| `/dc plates` | Toggle numbers above nameplates |
| `/dc blizz` | Toggle hiding Blizzard's damage numbers (`/dc blizz status` shows details) |
| `/dc debug` | Write each hit and its detected spell to chat |
| `/dc reset` | Reset all settings |
| `/dc help` | List all commands |

## How it works

WoW: Forever runs on the modern game client and its addon restrictions. Addons get **no combat log**, and damage amounts are **"secret values"**: an addon may display them, but not read them. So there is no direct way to ask the game which spell caused a damage number.

What addons can still see:

- each damage event on a unit, with its **damage school** (Shadow, Fire, …) and whether it was a crit
- your own **spell casts**

DotColors combines the two. Every DoT ticks at a fixed rhythm after it is cast: Bane of Agony every 2 seconds, Corruption and Immolate every 3 seconds. When a Shadow or Fire hit arrives exactly when a DoT is due to tick, DotColors gives it that DoT's color. Immolate is easy anyway, because it's the only Fire DoT. Your pet's attacks are matched to its casts the same way.

## Known limitations

- **Simultaneous ticks:** when two Shadow DoTs tick at exactly the same moment, both numbers appear, but their colors can be swapped.
- **Another Warlock on the same target:** the game doesn't say who dealt the damage, so their ticks can be colored as yours.
- **Dungeons:** the game restricts more data inside instances. Detection may be less reliable there.
- **Damage amounts can't be summed or compared**, because they are secret values. Only how they are shown can change.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for the code guidelines and commit conventions.
