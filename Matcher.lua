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
local WRACK_SPEEDUP = 2         -- Wrack makes Corruption, Agony and Siphon Life tick this much faster

local enemies = {}  -- enemy key -> { dots = {}, petCast = ?, directCast = ?, lastSeen = time }
local channel       -- { enemy = key, kind = hit type, icon = texture } while Drain or Wrack is channeled

--- A stable key for a unit: its GUID, or a fallback when the GUID is hidden.
function ns.enemyKey(unit)
  if not ns.safeCall(UnitExists, unit) then return nil end
  local guid = ns.safeCall(UnitGUID, unit)
  if guid then return guid end
  if unit == "target" or ns.safeCall(UnitIsUnit, unit, "target") then return "unit:target" end
  return "unit:" .. unit
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
  local name = ns.spellName(spellID)
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
  local name = ns.spellName(spellID)
  local kind = name and ns.PET_HIT_BY_SPELL_NAME[name]
  if not kind then return end
  local key = ns.enemyKey("pettarget") or ns.enemyKey("target")
  if not key then return end
  enemyState(key).petCast = { time = GetTime(), kind = kind, icon = spellIcon(spellID) }
end

--- True while Wrack is channeled on this enemy.
local function isWracking(key)
  return channel and channel.kind == "wrack" and channel.enemy == key
end

--- Stretches or squeezes the time since each Wrack-affected DoT last ticked.
--- A DoT that was halfway to its next tick when its speed changes is still
--- halfway there afterwards, so its next tick is predicted correctly.
local function rescaleWrackedDots(key, factor)
  local state = key and enemies[key]
  if not state then return end
  local now = GetTime()
  for kind, dot in pairs(state.dots) do
    if ns.DOTS[kind].fasterDuringWrack then
      dot.lastTick = now - (now - dot.lastTick) * factor
    end
  end
end

--- Starts treating Shadow hits on the target as the channeled spell.
function ns.onChannelStart(spellID)
  local name = ns.spellName(spellID)
  local kind = name and ns.CHANNELED_SPELL_NAMES[name]
  if not kind then return end
  channel = { enemy = ns.enemyKey("target"), kind = kind, icon = spellIcon(spellID) }
  if kind == "wrack" then rescaleWrackedDots(channel.enemy, 1 / WRACK_SPEEDUP) end
end

--- Stops the channel; DoTs sped up by Wrack return to their normal rhythm.
function ns.onChannelStop()
  if channel and channel.kind == "wrack" then rescaleWrackedDots(channel.enemy, WRACK_SPEEDUP) end
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
local function matchDotTick(key, state, school, now)
  local wracking = isWracking(key)
  local bestKind, bestError
  for kind, dot in pairs(state.dots) do
    local info = ns.DOTS[kind]
    if now > dot.expires then
      state.dots[kind] = nil
    elseif info.school == school then
      local interval = (wracking and info.fasterDuringWrack) and info.interval / WRACK_SPEEDUP or info.interval
      local err = tickError(dot, interval, now)
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
    kind, icon, err = matchDotTick(key, state, school, now)
    if kind then return kind, icon, err end
  end

  if channel and channel.enemy == key and school == ns.SCHOOL.SHADOW then
    return channel.kind, channel.icon
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
