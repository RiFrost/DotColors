# Changelog

All notable changes to DotColors are listed here. Versions follow [Semantic Versioning](https://semver.org/).

## 1.1.0 (2026-11-28)

### Added

- Wrack (Affliction talent) gets its own color
- Corruption, Bane of Agony and Siphon Life are still matched while Wrack makes them tick twice as fast
- "Gap between stacked numbers" slider on the Display page

### Fixed

- Numbers in the same column no longer appear on top of each other: a new number starts below the previous one if that hasn't risen far enough yet

## 1.0.0 (2026-11-24)

First public release.

### Added

- Own floating damage numbers with a separate color for each Warlock DoT: Corruption, Bane of Agony, Immolate, Siphon Life, Lash of Pain and Drain Life / Drain Soul
- Ticks matched by their rhythm after each cast, since WoW: Forever gives addons no combat log
- Spells recognized by their spell ID, so every client language and every spell rank works
- Numbers above enemy nameplates, with a movable fixed anchor as fallback
- Larger numbers for critical hits and an optional spell icon
- Option to hide Blizzard's own damage numbers
- Options window with the pages General, Display, Colors and Position, also listed under the game's AddOn options
- Adjustable spacing between the numbers of different spells
- Minimap button and AddOn menu entry
- `/dc` commands
- English and German texts

### Changed since 0.5.0-beta1

- Spells are recognized by spell ID instead of their English or German name
- New "Spacing between spells" slider on the Display page, for when numbers overlap
- Logo and in-game icon use the Cinzel typeface of the original design
