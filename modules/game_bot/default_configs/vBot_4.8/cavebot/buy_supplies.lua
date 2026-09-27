CaveBot.Extensions.BuySupplies = {}

if CaveBot and CaveBot.Actions then
  CaveBot.Actions["buysupplies"] = nil
  CaveBot.Actions["BuySupplies"] = nil
end

-- Helper to find the NPC trade window anywhere in OTClient
local function getNpcTradeWindow()
  if modules.game_npctrade and modules.game_npctrade.npcWindow and modules.game_npctrade.npcWindow:isVisible() then
    return modules.game_npctrade.npcWindow
  end
  if modules.game_npctrader then
    for _, var in ipairs({"npcWindow", "tradeWindow", "window", "traderWindow", "ui"}) do
      if modules.game_npctrader[var] and modules.game_npctrader[var].isVisible and modules.game_npctrader[var]:isVisible() then
        return modules.game_npctrader[var]
      end
    end
  end
  local root = g_ui.getRootWidget()
  if root then
    for _, w in ipairs(root:getChildren() or {}) do
      if w:isVisible() then
        local t = w.getText and tostring(w:getText()):lower() or ""
        local id = tostring(w:getId()):lower()
        if t:find("intercambio con npc") or t:find("npc trade") or id:find("npctrade") or id:find("npcwindow") then
          return w
        end
        local title = w:getChildById("title") or w:getChildById("windowText")
        if title and title.getText and tostring(title:getText()):lower():find("intercambio con npc") then
          return w
        end
      end
    end
  end
  return nil
end

-- Hook NPC.isTrading so engine functions know trade is open
local oldIsTrading = NPC and NPC.isTrading
if NPC then
  NPC.isTrading = function()
    local win = getNpcTradeWindow()
    if win and win:isVisible() then return true end
    if oldIsTrading then return oldIsTrading() end
    return false
  end
end

local function isTradeWindowOpen()
  return (getNpcTradeWindow() ~= nil)
end

local function findChildByText(parent, target)
  if not parent then return nil end
  if parent.getText then
    local t = tostring(parent:getText()):lower():trim()
    if t == target:lower():trim() then
      return parent
    end
  end
  for _, child in ipairs(parent:getChildren() or {}) do
    local f = findChildByText(child, target)
    if f then return f end
  end
  return nil
end

-- Safely close the trade window through every known method
local function safeCloseTrade()
  local win = getNpcTradeWindow()
  if win then
    local closeBtn = findChildByText(win, "Cerrar") or findChildByText(win, "Close") or win:getChildById("closeButton") or win:getChildById("buttonClose")
    if closeBtn then
      local pos = closeBtn:getPosition()
      local center = {x = pos.x + math.floor(closeBtn:getWidth()/2), y = pos.y + math.floor(closeBtn:getHeight()/2)}
      pcall(function() if closeBtn.onClick then closeBtn:onClick(center) end end)
      pcall(function() if closeBtn.onMousePress then closeBtn:onMousePress(center, 1) end end)
      pcall(function() if closeBtn.onMouseRelease then closeBtn:onMouseRelease(center, 1) end end)
    end
    pcall(function() win:hide() end)
  end

  pcall(function()
    if NPC and NPC.closeTrade then
      NPC.closeTrade()
    end
  end)
  pcall(function()
    if modules.game_npctrade and modules.game_npctrade.closeNpcTrade then
      modules.game_npctrade.closeNpcTrade()
    end
    if modules.game_npctrader and modules.game_npctrader.closeNpcTrade then
      modules.game_npctrader.closeNpcTrade()
    end
  end)
  pcall(function()
    if NPC and NPC.say then NPC.say("bye") end
    say("bye")
  end)
end

-- Switch to the "Comprar" tab
local function switchToBuyTab()
  local win = getNpcTradeWindow()
  if not win then return end

  if modules.game_npctrade then modules.game_npctrade.npcWindow = win end
  if modules.game_npctrader then modules.game_npctrader.npcWindow = win end

  -- 1. Try TabBar
  local function findTabBar(widget)
    if not widget then return nil end
    if widget.selectTab and widget.getTabs then
      local tabs = widget:getTabs()
      if tabs and #tabs >= 2 then return widget end
    end
    for _, child in ipairs(widget:getChildren() or {}) do
      local f = findTabBar(child)
      if f then return f end
    end
    return nil
  end
  local tb = findTabBar(win)
  if tb then
    pcall(function()
      local tabs = tb:getTabs()
      tb:selectTab(tabs[1]) -- First tab is usually "Comprar" / Buy
    end)
  end

  -- 2. Find any button/tab widget with text "Comprar" or "Buy"
  local buyBtn = findChildByText(win, "Comprar") or findChildByText(win, "Buy")
  if buyBtn then
    local p = buyBtn:getParent()
    while p do
      if p.selectTab then
        pcall(function() p:selectTab(buyBtn) end)
        break
      end
      p = p:getParent()
    end
    local pos = buyBtn:getPosition()
    local center = {x = pos.x + math.floor(buyBtn:getWidth()/2), y = pos.y + math.floor(buyBtn:getHeight()/2)}
    pcall(function() buyBtn:focus() end)
    pcall(function() if buyBtn.setOn then buyBtn:setOn(true) end end)
    pcall(function() if buyBtn.setChecked then buyBtn:setChecked(true) end end)
    pcall(function() if buyBtn.onMousePress then buyBtn:onMousePress(center, 1) end end)
    pcall(function() if buyBtn.onMouseRelease then buyBtn:onMouseRelease(center, 1) end end)
    pcall(function() if buyBtn.onClick then buyBtn:onClick(center) end end)
  end

  -- 3. Also try module functions
  pcall(function()
    if modules.game_npctrade and modules.game_npctrade.setTradeType then
      modules.game_npctrade.setTradeType(modules.game_npctrade.BUY or 1)
    end
    if modules.game_npctrader and modules.game_npctrader.setTradeType then
      modules.game_npctrader.setTradeType(modules.game_npctrader.BUY or 1)
    end
  end)
end

-- Safely execute item purchase without crashing
local function safeBuy(id, count)
  id = tonumber(id)
  if not id or id <= 0 then return end
  count = tonumber(count) or 1
  if count <= 0 then return end

  local itemObj = nil
  pcall(function()
    itemObj = Item.create(id)
  end)

  pcall(function()
    if modules.game_npctrader and modules.game_npctrader.buyItem then
      modules.game_npctrader.buyItem(itemObj or id, count)
    end
  end)

  pcall(function()
    if modules.game_npctrade and modules.game_npctrade.buyItem then
      modules.game_npctrade.buyItem(itemObj or id, count)
    end
  end)

  pcall(function()
    if itemObj and g_game and g_game.buyItem then
      g_game.buyItem(itemObj, count, false, false)
    end
  end)

  pcall(function()
    if NPC and NPC.buy then
      NPC.buy(itemObj or id, count, false, false)
    end
  end)
end

-- Get list of configured supplies from bot config
local function getConfiguredSupplies()
  local items = {}

  -- 1. Try Supplies.getItemsData()
  pcall(function()
    if Supplies and Supplies.getItemsData then
      local data = Supplies.getItemsData()
      if data and type(data) == "table" then
        for id, vals in pairs(data) do
          local numId = tonumber(id)
          if numId and vals and vals.max and tonumber(vals.max) > 0 then
            items[numId] = {
              min = tonumber(vals.min) or 0,
              max = tonumber(vals.max) or 0
            }
          end
        end
      end
    end
  end)

  -- 2. Fallback to SuppliesConfig
  local count = 0
  for _ in pairs(items) do count = count + 1 end
  if count == 0 then
    pcall(function()
      if SuppliesConfig and SuppliesConfig.supplies then
        local prof = SuppliesConfig.supplies.currentProfile or "Default"
        local pData = SuppliesConfig.supplies[prof] or SuppliesConfig.supplies["Default"]
        if pData and pData.items then
          for id, vals in pairs(pData.items) do
            local numId = tonumber(id)
            if numId and vals and vals.max and tonumber(vals.max) > 0 then
              items[numId] = {
                min = tonumber(vals.min) or 0,
                max = tonumber(vals.max) or 0
              }
            end
          end
        end
      end
    end)
  end

  return items
end

-- Get item IDs that the NPC sells (if detectable)
local function getPossibleBuyItemIds()
  local ids = {}

  pcall(function()
    if NPC and NPC.getBuyItems then
      for _, it in ipairs(NPC.getBuyItems() or {}) do
        if it.id then ids[tonumber(it.id)] = true end
      end
    end
  end)

  pcall(function()
    local t = modules.game_npctrade and modules.game_npctrade.tradeItems
    local buyType = (modules.game_npctrade and modules.game_npctrade.BUY) or 1
    if t and t[buyType] then
      for _, item in ipairs(t[buyType]) do
        local id = (item.ptr and item.ptr:getId()) or (item.getId and item:getId()) or item.id
        if id then ids[tonumber(id)] = true end
      end
    end
  end)

  pcall(function()
    local t = modules.game_npctrader and (modules.game_npctrader.tradeItems or modules.game_npctrader.items)
    local buyType = (modules.game_npctrader and modules.game_npctrader.BUY) or 1
    if t and t[buyType] then
      for _, item in ipairs(t[buyType]) do
        local id = (item.ptr and item.ptr:getId()) or (item.getId and item:getId()) or item.id
        if id then ids[tonumber(id)] = true end
      end
    end
  end)

  pcall(function()
    local win = getNpcTradeWindow()
    if win then
      for _, child in ipairs(win:getChildren() or {}) do
        if child.getItemId and child:getItemId() > 100 then
          ids[child:getItemId()] = true
        end
      end
    end
  end)

  return ids
end

-- State variables for attempt tracking
local failedAttempts = {}
local lastCounts = {}
local lastAttemptId = nil

CaveBot.Extensions.BuySupplies.setup = function()
  local callback = function(value, retries)
    local val = string.split(value, ",")
    local npcName = val[1] and val[1]:trim() or "Frederik"
    local customDelay = val[2] and tonumber(val[2]:trim())

    if retries <= 1 then
      failedAttempts = {}
      lastCounts = {}
      lastAttemptId = nil
    end

    -- Timeout protection: after 35 retries, safely close and proceed
    if retries >= 35 then
      warn("CaveBot[BuySupplies]: Reached max retries (35), closing trade window and proceeding.")
      safeCloseTrade()
      delay(800)
      CaveBot.delay(800)
      return true
    end

    -- Locate NPC
    local npc = getCreatureByName(npcName)
    if not npc and not isTradeWindowOpen() then
      local pos = player:getPosition()
      for _, c in ipairs(getCreatures()) do
        if c:isNpc() and getDistanceBetween(pos, c:getPosition()) <= 4 then
          npc = c
          npcName = c:getName()
          break
        end
      end
    end

    delay(200)
    CaveBot.delay(200)
    if npc and not CaveBot.ReachNPC(npcName) then
      return "retry"
    end

    -- If trade is not open yet: say hi/trade and wait 7 seconds
    if not isTradeWindowOpen() then
      warn("CaveBot[BuySupplies]: Saying hi/trade to " .. tostring(npcName) .. ", waiting 7s for trade window...")
      CaveBot.OpenNpcTrade()
      local waitTrade = 7000
      delay(waitTrade)
      CaveBot.delay(waitTrade)
      return "retry"
    end

    -- Trade window is open!
    local win = getNpcTradeWindow()
    if modules.game_npctrade then modules.game_npctrade.npcWindow = win end
    if modules.game_npctrader then modules.game_npctrader.npcWindow = win end

    -- Make sure we are on the "Comprar" tab
    switchToBuyTab()

    -- Check if last buy attempt actually increased item count
    if lastAttemptId then
      local prev = lastCounts[lastAttemptId] or 0
      local current = player:getItemsCount(lastAttemptId) or 0
      if current <= prev then
        failedAttempts[lastAttemptId] = (failedAttempts[lastAttemptId] or 0) + 1
      else
        failedAttempts[lastAttemptId] = 0
      end
      lastAttemptId = nil
    end

    local supplies = getConfiguredSupplies()
    local npcItems = getPossibleBuyItemIds()
    local hasNpcItemsList = false
    for _ in pairs(npcItems) do hasNpcItemsList = true; break end

    local boughtAny = false

    -- Iterate configured supplies
    for id, vals in pairs(supplies) do
      local npcHasIt = true
      if hasNpcItemsList and not npcItems[id] then
        npcHasIt = false
      end

      local fails = failedAttempts[id] or 0
      if npcHasIt and fails < 3 then
        local current = player:getItemsCount(id) or 0
        local needed = vals.max - current

        if needed > 0 then
          local buyBatch = math.min(100, needed)
          warn("CaveBot[BuySupplies]: Buying " .. buyBatch .. "x item " .. id .. " (current: " .. current .. ", target: " .. vals.max .. ")...")
          lastAttemptId = id
          lastCounts[id] = current
          safeBuy(id, buyBatch)
          boughtAny = true
          break -- Buy 1 batch per round, then wait for server ACK
        end
      elseif fails >= 3 then
        -- Skipped item that could not be bought from this NPC
      end
    end

    -- If all needed supplies have been bought (or are skipped)
    if not boughtAny then
      warn("CaveBot[BuySupplies]: All supplies purchased! Closing trade window and continuing.")
      safeCloseTrade()
      delay(800)
      CaveBot.delay(800)
      return true
    end

    -- Delay between rounds so the server processes the buy packet
    local passDelay = customDelay or 400
    delay(passDelay)
    CaveBot.delay(passDelay)
    return "retry"
  end

  CaveBot.Actions["buysupplies"] = nil
  CaveBot.Actions["BuySupplies"] = nil
  CaveBot.registerAction("BuySupplies", "#C300FF", callback)

  if CaveBot.Actions then
    CaveBot.Actions["buysupplies"] = {
      color = "#C300FF",
      callback = callback
    }
    CaveBot.Actions["BuySupplies"] = {
      color = "#C300FF",
      callback = callback
    }
  end

  CaveBot.Editor.registerAction("buysupplies", "buy supplies", {
    value="NPC name",
    title="Buy Supplies",
    description="NPC Name, delay(in ms, optional)",
  })
end

CaveBot.Extensions.BuySupplies.setup()