# Contributing to DotColors

These are the rules this repository follows. They apply to everyone, including AI assistants.

## Principles

### Clean code

- **Names say what things are.** `tickInterval`, not `ti`. Functions are verbs: `classifyHit`, `spawnNumber`.
- **Small functions, one job each.** If a function needs a comment to explain its sections, split it.
- **Comments explain why, not what.** The code shows what happens. A comment is for the reason behind it, especially for workarounds around WoW API restrictions.
- **No magic numbers.** Name constants at the top of the file (`local TICK_TOLERANCE = 0.35`).
- **No dead code.** Don't comment code out; delete it. Git remembers.
- **Fail quietly in game.** Wrap calls that can hit restricted or secret values in `pcall`. A broken frame must never spam the user with Lua errors.

### YAGNI – You Aren't Gonna Need It

- Build what is needed now, not what might be needed later.
- No options, settings or abstractions "just in case". A setting exists only if someone asked for it.
- No libraries (Ace3, LibStub, …) unless a concrete feature can't be done reasonably without them.
- Three similar lines are fine. Abstract on the third real repetition, not the first.

### KISS – Keep It Simple

- Prefer plain Lua tables and functions over class systems.
- Prefer one clear way to do something over configurable flexibility.

## Lua and WoW conventions

- **Everything is `local`.** The only globals are the ones WoW requires: `SavedVariables` and `SLASH_*` / `SlashCmdList` entries.
- **Share code between files through the addon namespace** (`local ADDON, ns = ...`), never through globals.
- **Indentation:** 2 spaces. No tabs.
- **Naming:** `camelCase` for locals and functions, `UPPER_SNAKE_CASE` for constants, `PascalCase` only for frames created with a global name.
- **Language:** code, comments and commit messages in English. User-facing text goes through the locale files.
- **Secret values:** WoW: Forever runs on the modern (Midnight) API. Combat values can be "secret": they may be shown (`FontString:SetText`) but never read, compared or used in arithmetic. Check with `issecretvalue` and wrap access in `pcall`.
- **No combat log.** `COMBAT_LOG_EVENT_UNFILTERED` does not reach addons in Forever. Don't build features on it.
- **No taint.** Don't write into Blizzard tables (for example `UISpecialFrames`). Use the official registration functions only.

## Commits – Conventional Commits

All commit messages follow [Conventional Commits 1.0](https://www.conventionalcommits.org/en/v1.0.0/):

```
<type>(<optional scope>): <short summary in imperative mood>

<optional body: what and why>

<optional footer: BREAKING CHANGE, refs>
```

**Types:**

| Type | Use for |
|------|---------|
| `feat` | A new feature for the user |
| `fix` | A bug fix |
| `docs` | Documentation only |
| `style` | Formatting, no code change |
| `refactor` | Code change that neither fixes a bug nor adds a feature |
| `perf` | Performance improvement |
| `test` | Adding or fixing tests |
| `build` | Packaging, `.pkgmeta`, `.toc` metadata |
| `ci` | GitHub Actions and release automation |
| `chore` | Anything else that doesn't touch the addon (tooling, housekeeping) |

**Scopes** (optional): `core`, `display`, `options`, `minimap`, `locale`.

**Rules:**

- Summary in imperative mood, lower case, no trailing period, max 72 characters: `feat(options): add font size slider`
- One logical change per commit.
- Breaking changes (for example renamed saved settings) get `!` after the type and a `BREAKING CHANGE:` footer.

**Examples:**

```
feat(core): detect Siphon Life ticks by their 3 second rhythm
fix(display): stop numbers stacking on top of each other
docs: describe known limitations in the README
build: bump interface version to 16002
```

## Versioning

DotColors uses [Semantic Versioning](https://semver.org/): `MAJOR.MINOR.PATCH`.

- `feat` → minor version
- `fix` → patch version
- breaking change → major version

Releases are tagged `vMAJOR.MINOR.PATCH`.

## Branches and pull requests

- `main` always holds a working addon.
- Work on a branch named after the change: `feat/minimap-button`, `fix/double-numbers`.
- A pull request describes what changed, why, and how it was tested in game.
