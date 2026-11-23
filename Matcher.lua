-- Matcher.lua
-- Decides which spell a hit came from.
--
-- The game tells an addon only that a unit took damage, the damage school
-- and whether it was a crit. It does not say which spell or which player.
-- But each DoT ticks at a fixed rhythm counted from its last cast, so a
-- Shadow hit 2.0 s after Bane of Agony was cast is almost certainly Agony.
-- For every enemy we remember when each of our DoTs was cast and when it
-- last ticked, and pick the DoT whose next tick is closest to the hit.

local _, ns = ...

local TICK_TOLERANCE = 0.35     -- a hit may be this many seconds off the expected tick
local DIRECT_HIT_WINDOW = 0.25  -- a hit this soon after the cast is the spell's direct damage
local PET_HIT_WINDOW = 0.3      -- a pet spell hits within this time of the pet's cast
local DIRECT_ICON_WINDOW = 3    -- unmatched hits borrow the icon of a cast this recent
local DURATION_GRACE = 3        -- keep a DoT a little past its duration for late ticks
local FORGET_AFTER = 60         -- forget enemies not seen for this many seconds

local enemies = {}  -- enemy key -> { dots = {}, petCast = ?, directCast = ?, lastSeen = time }
local channel       -- { enemy = key, icon = texture } while Drain Life / Drain Soul is channeled

--- A stable key for a unit: its GUID, or a fallback when the GUID is hidden.
function ns.enemyKey(unit)
  if not ns.safeCall(UnitExists, unit) then return nil end
  local guid = ns.safeCall(UnitGUID, unit)
  if guid then return guid end
  if unit == "target" or ns.safeCall(UnitIsUnit, unit, "target") then return "unit:target" end
  return "unit:" .. unit
end

--- The spell's name in the client's language, if the game shares it.
local function spellName(spellID)
  if C_Spell and C_Spell.GetSpellName then
    return ns.safeCall(C_Spell.GetSpellName, spellID)
  end
  if GetSpellInfo then return ns.safeCall(GetSpellInfo, spellID) end
end

--- The spell's icon texture, if the game shares it.
local function spellIcon(spellID)
  if C_Spell and C_Spell.GetSpellTexture then
    return ns.safeCall(C_Spell.GetSpellTexture, spellID)
  end
  if GetSpellTexture then return ns.safeCall(GetSpellTexture, spellID) end
end

--- The remembered state of one enemy, created on first use.
local function enemyState(key)
  local state = enemies[key]
  if not state then
    state = { dots = {} }
    enemies[key] = state
  end
  state.lastSeen = GetTime()
  return state
end

--- Remembers a cast by the player on the current target.
--- A DoT cast restarts that DoT's tick rhythm (confirmed in game logs).
function ns.onPlayerCast(spellID)
  local name = spellName(spellID)
  local key = name and ns.enemyKey("target")
  if not key then return end

  local now = GetTime()
  local state = enemyState(key)
  local dotKind = ns.DOT_BY_SPELL_NAME[name]
  if dotKind then
    state.dots[dotKind] = {
      lastTick = now,
      awaitingDirectHit = true,
      expires = now + ns.DOTS[dotKind].duration + DURATION_GRACE,
      icon = spellIcon(spellID),
    }
  else
    state.directCast = { time = now, icon = spellIcon(spellID) }
  end
end

--- Remembers a cast by the player's pet, so its hit can be matched.
function ns.onPetCast(spellID)
  local name = spellName(spellID)
  local kind = name and ns.PET_HIT_BY_SPELL_NAME[name]
  if not kind then return end
  local key = ns.enemyKey("pettarget") or ns.enemyKey("target")
  if not key then return end
  enemyState(key).petCast = { time = GetTime(), kind = kind, icon = spellIcon(spellID) }
end

--- Starts or stops treating Shadow hits as Drain Life / Drain Soul.
function ns.onChannelStart(spellID)
  local name = spellName(spellID)
  if name and ns.CHANNELED_SPELL_NAMES[name] then
    channel = { enemy = ns.enemyKey("target"), icon = spellIcon(spellID) }
  end
end

function ns.onChannelStop()
  channel = nil
end

--- How far (in seconds) a hit is from one of the DoT's expected ticks,
--- or nil if it doesn't fit at all.
local function tickError(dot, interval, now)
  local sinceTick = now - dot.lastTick
  if dot.awaitingDirectHit and sinceTick < DIRECT_HIT_WINDOW then
    return sinceTick
  end
  if sinceTick < 0.5 then return nil end
  local ticks = math.floor(sinceTick / interval + 0.5)
  if ticks < 1 then return nil end
  return math.abs(sinceTick - ticks * interval)
end

--- Matches a pet spell hit to the pet's cast, if both happened together.
local function matchPetHit(state, school, now)
  local cast = state.petCast
  if not cast or cast.used or now - cast.time >= PET_HIT_WINDOW then return nil end
  local fits = (cast.kind == "lash" and school == ns.SCHOOL.SHADOW)
    or (cast.kind == "petfire" and school == ns.SCHOOL.FIRE)
  if not fits then return nil end
  cast.used = true
  return cast.kind, cast.icon, now - cast.time
end

--- Matches a hit to the DoT whose expected tick is closest.
local function matchDotTick(state, school, now)
  local bestKind, bestError
  for kind, dot in pairs(state.dots) do
    local info = ns.DOTS[kind]
    if now > dot.expires then
      state.dots[kind] = nil
    elseif info.school == school then
      local err = tickError(dot, info.interval, now)
      if err and err < TICK_TOLERANCE and (not bestError or err < bestError) then
        bestKind, bestError = kind, err
      end
    end
  end
  if not bestKind then return nil end

  local dot = state.dots[bestKind]
  local isDirectHit = dot.awaitingDirectHit and now - dot.lastTick < DIRECT_HIT_WINDOW
  if not isDirectHit then
    dot.lastTick = now  -- re-align to the real tick so small delays don't add up
  end
  dot.awaitingDirectHit = false
  return bestKind, dot.icon, bestError
end

--- Classifies one hit on an enemy.
--- Returns the hit type (a key of ns.KIND_BY_KEY), an icon or nil,
--- and how far off the expected time it was (nil when unknown).
function ns.classifyHit(key, school, now)
  local state = enemies[key]
  if state then
    local kind, icon, err = matchPetHit(state, school, now)
    if kind then return kind, icon, err end
    kind, icon, err = matchDotTick(state, school, now)
    if kind then return kind, icon, err end
  end

  if channel and channel.enemy == key and school == ns.SCHOOL.SHADOW then
    return "drain", channel.icon
  end

  local recentCast = state and state.directCast
  local icon = recentCast and now - recentCast.time < DIRECT_ICON_WINDOW and recentCast.icon or nil
  if school == ns.SCHOOL.SHADOW then return "shadow", icon end
  if school == ns.SCHOOL.FIRE then return "fire", icon end
  if school == ns.SCHOOL.PHYSICAL then return "physical" end
  return "other", icon
end

--- Forgets enemies that haven't been seen for a while.
function ns.forgetOldEnemies()
  local cutoff = GetTime() - FORGET_AFTER
  for key, state in pairs(enemies) do
    if (state.lastSeen or 0) < cutoff then enemies[key] = nil end
  end
end
