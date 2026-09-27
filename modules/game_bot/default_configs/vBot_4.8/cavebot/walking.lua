-- walking
local expectedDirs = {}
local isWalking = false
local walkPath = {}
local walkPathIter = 0
local lureNextStepAt = 0 -- direct time gate for dynamic lure delay
local lastStepTime = 0

CaveBot.resetWalking = function()
  expectedDirs = {}
  walkPath = {}
  isWalking = false
  -- do NOT reset lureNextStepAt here so delay carries over
end

CaveBot.clearDelay = function()
  lureNextStepAt = 0
  if cavebotMacro then
    cavebotMacro.delay = nil
  end
end

local function getWalkDelay(dir)
  local duration = player:getStepDuration(false, dir)
  local ping = CaveBot.Config.get("ping") or 0
  local walkDelay = CaveBot.Config.get("walkDelay") or 0
  -- Subtract server ping to pipeline walk packets so character runs fluidly without pausing
  -- Minimum delay safety floor: at least 60ms and at least 40% of step duration
  local minDelay = math.max(60, math.floor(duration * 0.4))
  return math.max(minDelay, duration - ping + walkDelay)
end

-- Count living hostile monsters visible on player's screen/floor
local function getLivingMonstersOnScreen()
  local count = 0
  local myPos = player:getPosition()
  if not myPos then return 0 end
  local myZ = myPos.z
  
  local specs = getSpectators()
  if not specs then return 0 end
  
  for _, spec in ipairs(specs) do
    if spec and not spec:isLocalPlayer() and not spec:isPlayer() and not spec:isNpc() then
      local isMob = spec:isMonster() or (spec:getType() and spec:getType() < 3 and not spec:isPlayer())
      if isMob then
        local hp = spec:getHealthPercent()
        local pos = spec:getPosition()
        if hp and hp > 0 and pos and pos.z == myZ then
          local dx = math.abs(pos.x - myPos.x)
          local dy = math.abs(pos.y - myPos.y)
          -- Visible on player screen (standard screen is 15x11 tiles, with borders up to 10x8)
          if dx <= 10 and dy <= 8 then
            count = count + 1
          end
        end
      end
    end
  end
  return count
end
CaveBot.getLivingMonstersOnScreen = getLivingMonstersOnScreen

-- Retrieve monster threshold and delay from TargetBot creature configs or CaveBot config
local function getDynamicLureConfig()
  local threshold = nil
  local delay = nil
  
  -- 1. Check active creature in TargetBot if attacking
  if TargetBot and TargetBot.activeConfig then
    local cfg = TargetBot.activeConfig
    threshold = cfg.delayFrom or cfg.lureMin
    if cfg.lureDelay and cfg.lureDelay > 0 then
      delay = cfg.lureDelay
    end
  end
  
  -- 2. Inspect all target entries in TargetBot list
  if not threshold and TargetBot and TargetBot.targetList then
    for _, child in ipairs(TargetBot.targetList:getChildren()) do
      local cfg = child.value
      if cfg then
        if cfg.dynamicLure or cfg.dynamicLureDelay or cfg.lureCavebot then
          threshold = threshold or cfg.delayFrom or cfg.lureMin
          if cfg.lureDelay and cfg.lureDelay > 0 then
            delay = delay or cfg.lureDelay
          end
          if threshold and delay then break end
        end
      end
    end
  end
  
  -- 3. Check CaveBot Config mapClickDelay
  local mapClickDelay = (CaveBot and CaveBot.Config and CaveBot.Config.get and CaveBot.Config.get("mapClickDelay")) or 0
  if mapClickDelay > 0 then
    delay = math.max(delay or 0, mapClickDelay)
  end
  
  -- Default threshold is 2 (or dynamicLureMin)
  if not threshold then
    threshold = (TargetBot and TargetBot.dynamicLureMin) or 2
  end
  
  -- Default delay if dynamic lure is active but delay is 0
  if not delay or delay == 0 then
    delay = 1500
  end
  
  return threshold, delay
end

local function getEffectiveMapClickDelay()
  if CaveBot and CaveBot.isOff and CaveBot.isOff() then
    return 0
  end

  local threshold, delay = getDynamicLureConfig()
  local livingMobs = getLivingMonstersOnScreen()

  -- Keep TargetBot targetsCount updated
  if TargetBot then
    TargetBot.targetsCount = livingMobs
  end

  -- When monsters on screen >= specified threshold (and at least 1 alive):
  -- START MAP CLICK DELAY!
  if livingMobs >= threshold and livingMobs > 0 then
    if TargetBot then
      TargetBot.dynamicLureEngaged = true
      TargetBot.dynamicLureStepDelay = delay
    end
    return delay
  else
    -- When monsters are dead (< threshold or 0):
    -- DEACTIVATE THE DELAY IMMEDIATELY!
    if TargetBot then
      TargetBot.dynamicLureEngaged = false
    end
    return 0
  end
end
CaveBot.getEffectiveMapClickDelay = getEffectiveMapClickDelay

CaveBot.doWalking = function()
  if not isWalking or not walkPath or #walkPath == 0 then
    return false
  end

  local isMapClick = CaveBot.Config.get("mapClick")
  local effectiveDelay = getEffectiveMapClickDelay()

  -- If monsters died mid-step, instantly deactivate delay!
  if effectiveDelay == 0 and lureNextStepAt > 0 then
    lureNextStepAt = 0
    if cavebotMacro then
      cavebotMacro.delay = nil
    end
  end

  -- DIRECT TIME GATE: block next step until lureNextStepAt has passed
  if effectiveDelay > 0 and now < lureNextStepAt then
    return true -- still waiting for lure delay
  end

  local stepDuration = player:getStepDuration(false) or 200
  local stepTimeout = math.max(700, stepDuration * 2 + (CaveBot.Config.get("ping") or 50) + 200 + effectiveDelay)

  -- Stuck detection: if we have expected dirs and haven't moved within timeout, reset walking
  if #expectedDirs > 0 and (now - lastStepTime > stepTimeout) then
    CaveBot.resetWalking()
    return false
  end

  -- Too many unconfirmed steps: packets backlogged or desynced
  if #expectedDirs >= 3 then
    CaveBot.resetWalking()
    return false
  end

  local maxExpected = (effectiveDelay > 0) and 1 or 2
  if #expectedDirs >= maxExpected then
    return true
  end

  local dir = walkPath[walkPathIter]
  if dir then
    if isMapClick then
      autoWalk({ dir })
    else
      g_game.walk(dir)
    end
    table.insert(expectedDirs, dir)
    walkPathIter = walkPathIter + 1
    lastStepTime = now
    
    if effectiveDelay > 0 then
      local stepDelay = player:getStepDuration(false, dir) or 200
      local totalDelay = stepDelay + effectiveDelay
      CaveBot.delay(totalDelay)
      lureNextStepAt = now + totalDelay
    else
      local stepDelay = isMapClick and (player:getStepDuration(false, dir) or 200) or getWalkDelay(dir)
      CaveBot.delay(stepDelay)
      lureNextStepAt = 0
    end
    return true
  end

  if #expectedDirs > 0 then
    return true
  end

  CaveBot.resetWalking()
  return false  
end

-- called when player position has been changed (step has been confirmed by server)
onPlayerPositionChange(function(newPos, oldPos)
  if not oldPos or not newPos then return end
  
  local dirs = {{NorthWest, North, NorthEast}, {West, 8, East}, {SouthWest, South, SouthEast}}
  local dir = dirs[newPos.y - oldPos.y + 2]
  if dir then
    dir = dir[newPos.x - oldPos.x + 2]
  end
  if not dir then
    dir = 8 -- 8 is invalid dir, it's fine
  end

  if newPos.z ~= oldPos.z then
    -- Floor change (stairs/ladder/teleport), clear walking state
    walkPath = {}
    expectedDirs = {}
    isWalking = false
    lastStepTime = now
    CaveBot.delay(CaveBot.Config.get("ping") + 50)
    return
  end

  if not isWalking or #expectedDirs == 0 then
    return
  end
  
  local effectiveDelay = getEffectiveMapClickDelay()
  if expectedDirs[1] == dir then
    table.remove(expectedDirs, 1)  
    lastStepTime = now
    if effectiveDelay > 0 then
      -- Refresh the direct time gate from the moment the step is CONFIRMED
      lureNextStepAt = math.max(lureNextStepAt, now + effectiveDelay)
      CaveBot.delay(effectiveDelay)
    else
      -- Monsters dead or < threshold: delay is 0, clear lure gate!
      lureNextStepAt = 0
    end
  else
    CaveBot.resetWalking()
  end
end)

CaveBot.walkTo = function(dest, maxDist, params)
  local path = getPath(player:getPosition(), dest, maxDist, params)
  if not path or not path[1] then
    return false
  end
  local dir = path[1]
  local isMapClick = CaveBot.Config.get("mapClick")
  local effectiveDelay = getEffectiveMapClickDelay()
  
  if isMapClick then
    if effectiveDelay > 0 then
      -- Dynamic lure or map click delay active: walk step-by-step via autoWalk so delays can be applied
      if now < lureNextStepAt then
        return false -- wait for lure delay gate
      end
      local ret = autoWalk({ dir })
      if ret then
        isWalking = true
        walkPath = path
        walkPathIter = 2
        expectedDirs = { dir }
        lastStepTime = now
        local stepDelay = player:getStepDuration(false, dir) or 200
        local totalDelay = stepDelay + effectiveDelay
        CaveBot.delay(totalDelay)
        lureNextStepAt = now + totalDelay
      end
      return ret
    else
      -- Normal map click without delay: step-by-step so if monsters appear mid-path, delay kicks in immediately!
      local ret = autoWalk({ dir })
      if ret then
        isWalking = true
        walkPath = path
        walkPathIter = 2
        expectedDirs = { dir }
        lastStepTime = now
        local stepDelay = player:getStepDuration(false, dir) or 200
        CaveBot.delay(stepDelay)
        lureNextStepAt = 0
      end
      return ret
    end
  end
  
  local extraDelay = effectiveDelay
  if extraDelay > 0 and now < lureNextStepAt then
    return false
  end
  g_game.walk(dir)
  isWalking = true    
  walkPath = path
  walkPathIter = 2
  expectedDirs = { dir }
  lastStepTime = now
  local stepDelay = getWalkDelay(dir)
  CaveBot.delay(stepDelay + extraDelay)
  if extraDelay > 0 then
    lureNextStepAt = now + stepDelay + extraDelay
  else
    lureNextStepAt = 0
  end
  return true
end
