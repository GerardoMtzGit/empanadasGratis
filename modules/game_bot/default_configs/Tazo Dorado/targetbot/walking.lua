local dest
local maxDist
local params

TargetBot.walkTo = function(_dest, _maxDist, _params)
  dest = _dest
  maxDist = _maxDist
  params = _params
end

-- called every 100ms if targeting or looting is active
TargetBot.walk = function()
  -- When dynamic lure delay is engaged, CaveBot owns all movement.
  -- TargetBot must NOT send walk steps directly, or it bypasses CaveBot.delay.
  if TargetBot.dynamicLureEngaged then return end
  if not dest then return end
  if player:isWalking() then return end
  local pos = player:getPosition()
  if pos.z ~= dest.z then return end
  local dist = math.max(math.abs(pos.x-dest.x), math.abs(pos.y-dest.y))
  if params.precision and params.precision >= dist then return end
  if params.marginMin and params.marginMax then
    if dist >= params.marginMin and dist <= params.marginMax then 
      return
    end
  end
  local path = getPath(pos, dest, maxDist, params)
  if not path or #path == 0 then return end
  if g_game and g_game.walk then
    g_game.walk(path[1])
  elseif walk then
    pcall(walk, path[1])
  end
end
