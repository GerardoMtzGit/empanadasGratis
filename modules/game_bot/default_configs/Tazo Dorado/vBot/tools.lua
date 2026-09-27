-- tools tab
setDefaultTab("Tools")

if type(storage.moneyItems) ~= "table" then
  storage.moneyItems = {3031, 3035}
end
macro(1000, "Exchange money", function()
  if not storage.moneyItems[1] then return end
  local containers = g_game.getContainers()
  for index, container in pairs(containers) do
    if not container.lootContainer then -- ignore monster containers
      for i, item in ipairs(container:getItems()) do
        if item:getCount() == 100 then
          for m, moneyId in ipairs(storage.moneyItems) do
            if item:getId() == moneyId.id then
              return g_game.use(item)            
            end
          end
        end
      end
    end
  end
end)

local moneyContainer = UI.Container(function(widget, items)
  storage.moneyItems = items
end, true)
moneyContainer:setHeight(35)
moneyContainer:setItems(storage.moneyItems)

UI.Separator()

macro(60000, "Send message on trade", function()
  local trade = getChannelId("advertising")
  if not trade then
    trade = getChannelId("trade")
  end
  if trade and storage.autoTradeMessage:len() > 0 then    
    sayChannel(trade, storage.autoTradeMessage)
  end
end)
UI.TextEdit(storage.autoTradeMessage or "I'm using OTClientV8!", function(widget, text)    
  storage.autoTradeMessage = text
end)

UI.Separator()

-- Wild Growth Auto-Recast
UI.Label("Wild Growth Auto-Recast")

if not storage.wildGrowth then
  storage.wildGrowth = {
    runeId   = 2132,
    treeId   = 2130,
    lastPos  = nil,
    castTime = 0
  }
end

local wg = storage.wildGrowth
if not wg.runeId  then wg.runeId   = 2132 end
if not wg.treeId or wg.treeId == 2982 then wg.treeId = 2130 end
if not wg.castTime then wg.castTime = 0   end

UI.Label("Rune ID (default 2132):")
UI.TextEdit(tostring(wg.runeId), function(w, v)
  local n = tonumber(v)
  if n then wg.runeId = n end
end)

UI.Label("Tree ID (2130/2982 | 0=auto):")
UI.TextEdit(tostring(wg.treeId), function(w, v)
  local n = tonumber(v)
  if n then wg.treeId = n end
end)

local function isTreeOnTile(tile)
  if not tile then return false end
  if wg.treeId and wg.treeId > 0 then
    for _, thing in ipairs(tile:getThings()) do
      if thing:isItem() then
        local tid = thing:getId()
        if tid == wg.treeId or tid == 2130 or tid == 2982 or (wg.detectedTreeId and tid == wg.detectedTreeId) then
          return true
        end
      end
    end
    return false
  else
    return not tile:isWalkable(false)
  end
end

local function recastWildGrowth()
  if not wg.lastPos then return end
  if now - wg.castTime < 600 then return end

  local ppos = player:getPosition()
  if not ppos or ppos.z ~= wg.lastPos.z then return end
  if math.abs(ppos.x - wg.lastPos.x) > 7 or math.abs(ppos.y - wg.lastPos.y) > 5 then return end

  local tile = g_map.getTile(wg.lastPos)
  if not tile then return end

  local rune = findItem(wg.runeId)
  if not rune then return end

  local targetThing = tile:getTopUseThing() or tile:getGround() or tile:getTopThing()
  if not targetThing then return end

  useWith(rune, targetThing)
  wg.castTime = now
end

local wgMacro = macro(100, "Wild Growth Auto-Recast", function()
  if not wg.lastPos then return end
  if now - wg.castTime < 600 then return end

  local tile = g_map.getTile(wg.lastPos)
  if not tile then return end

  if isTreeOnTile(tile) then
    return
  end

  recastWildGrowth()
end)

onUseWith(function(pos, itemId, target, subType)
  if itemId == wg.runeId then
    local tpos = nil
    if type(target) == "table" and target.x and target.y and target.z then
      tpos = target
    elseif target and type(target.getPosition) == "function" then
      tpos = target:getPosition()
    elseif type(pos) == "table" and pos.x and pos.y and pos.z then
      tpos = pos
    end
    if tpos then
      wg.lastPos  = {x = tpos.x, y = tpos.y, z = tpos.z}
      wg.castTime = now
    end
  end
end)

onAddThing(function(tile, thing)
  if not thing:isItem() then return end
  local tpos = tile:getPosition()
  if not tpos or not wg.lastPos then return end
  local itemId = thing:getId()

  if tpos.x == wg.lastPos.x and tpos.y == wg.lastPos.y and tpos.z == wg.lastPos.z then
    if itemId == 2130 or itemId == 2982 or itemId == wg.treeId or (now - wg.castTime < 1000) then
      wg.detectedTreeId = itemId
      tile:setTimer(40000)
    end
  end
end)

onRemoveThing(function(tile, thing)
  if not wgMacro or wgMacro.isOff() then return end
  if not thing:isItem() then return end
  local tpos = tile:getPosition()
  if not tpos or not wg.lastPos then return end

  if tpos.x == wg.lastPos.x and tpos.y == wg.lastPos.y and tpos.z == wg.lastPos.z then
    local tid = thing:getId()
    if tid == wg.treeId or tid == 2130 or tid == 2982 or tid == wg.detectedTreeId then
      tile:setTimer(0)
      schedule(20, function()
        recastWildGrowth()
      end)
    end
  end
end)

UI.Separator()
