CaveBot.Extensions.SellAll = {}

if CaveBot and CaveBot.Actions then
  CaveBot.Actions["sellall"] = nil
  CaveBot.Actions["SellAll"] = nil
end

-- State tracking for consecutive identical sellall waypoints
local lastSoldSuccessNpc = nil
local lastSoldSuccessTime = 0

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

-- Switch to the "Vender" tab
local function switchToSellTab()
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
      tb:selectTab(tabs[2])
    end)
  end

  -- 2. Find any button/tab widget with text "Vender" or "Sell"
  local sellBtn = findChildByText(win, "Vender") or findChildByText(win, "Sell")
  if sellBtn then
    local p = sellBtn:getParent()
    while p do
      if p.selectTab then
        pcall(function() p:selectTab(sellBtn) end)
        break
      end
      p = p:getParent()
    end
    local pos = sellBtn:getPosition()
    local center = {x = pos.x + math.floor(sellBtn:getWidth()/2), y = pos.y + math.floor(sellBtn:getHeight()/2)}
    pcall(function() sellBtn:focus() end)
    pcall(function() if sellBtn.setOn then sellBtn:setOn(true) end end)
    pcall(function() if sellBtn.setChecked then sellBtn:setChecked(true) end end)
    pcall(function() if sellBtn.onMousePress then sellBtn:onMousePress(center, 1) end end)
    pcall(function() if sellBtn.onMouseRelease then sellBtn:onMouseRelease(center, 1) end end)
    pcall(function() if sellBtn.onClick then sellBtn:onClick(center) end end)
  end

  -- 3. Also try module functions
  pcall(function()
    if modules.game_npctrade and modules.game_npctrade.setTradeType then
      modules.game_npctrade.setTradeType(modules.game_npctrade.SELL or 2)
    end
    if modules.game_npctrader and modules.game_npctrader.setTradeType then
      modules.game_npctrader.setTradeType(modules.game_npctrader.SELL or 2)
    end
  end)
end

CaveBot.Extensions.SellAll.setup = function()
  local callback = function(value, retries)
    local val = string.split(value, ",")
    local wait = false

    for i, v in ipairs(val) do
      v = v:trim()
      v = tonumber(v) or v
      val[i] = v
    end

    if table.find(val, "yes", true) then
      wait = true
    end

    local npcName = val[1] and tostring(val[1]):trim() or "NPC"
    local customDelay = tonumber(val[2])

    -- Check if we already sold everything to this NPC in the previous sequential waypoint
    if retries <= 0 then
      if lastSoldSuccessNpc and lastSoldSuccessNpc == npcName:lower() and (os.time() - lastSoldSuccessTime < 20) and not isTradeWindowOpen() then
        warn("CaveBot[SellAll]: Already finished selling to " .. npcName .. ". Skipping duplicate waypoint.")
        return true
      end
    end

    -- Timeout protection: if we've retried 10 times without opening trade or completing, proceed
    if retries >= 10 then
      warn("CaveBot[SellAll]: Max retries reached for " .. npcName .. ", proceeding.")
      safeCloseTrade()
      lastSoldSuccessNpc = npcName:lower()
      lastSoldSuccessTime = os.time()
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

    -- If trade window is not open, say hi/trade and wait 2.5 seconds
    if not isTradeWindowOpen() then
      warn("CaveBot[SellAll]: Saying hi/trade to " .. tostring(npcName) .. "...")
      CaveBot.OpenNpcTrade()
      local waitTrade = 2500
      delay(waitTrade)
      CaveBot.delay(waitTrade)
      return "retry"
    end

    -- Trade window is open!
    local win = getNpcTradeWindow()
    if modules.game_npctrade then modules.game_npctrade.npcWindow = win end
    if modules.game_npctrader then modules.game_npctrader.npcWindow = win end

    switchToSellTab()
    delay(300)
    CaveBot.delay(300)

    -- Say "yes" in case of autoloot bag
    pcall(function()
      if NPC and NPC.say then NPC.say("yes") end
      say("yes")
    end)

    -- Slower, human-paced delay between passes (default 650ms) to completely prevent server kicks
    local passDelay = customDelay or 650
    local maxPasses = 18
    local consecutiveEmpty = 0

    warn(string.format("CaveBot[SellAll]: Executing %d sell passes with %dms delay for %s...", maxPasses, passDelay, npcName))

    for pass = 1, maxPasses do
      -- 1. Native module sellAll (sells items according to client's internal routine)
      pcall(function()
        if modules.game_npctrade and modules.game_npctrade.sellAll then
          modules.game_npctrade.sellAll(wait, val)
        elseif modules.game_npctrader and modules.game_npctrader.sellAll then
          modules.game_npctrader.sellAll(wait, val)
        end
      end)

      -- 2. Direct single-item sell backup to ensure 100% of items sell without packet flood
      local soldAny = false
      pcall(function()
        local sellItems = (NPC and NPC.getSellItems and NPC.getSellItems()) or {}
        for _, entry in ipairs(sellItems) do
          local isException = false
          for i = 2, #val do
            if val[i] == entry.id or val[i] == entry.name then
              isException = true
              break
            end
          end
          if not isException then
            local qty = 0
            pcall(function() qty = NPC.getSellQuantity(entry.item) end)
            if not qty or qty <= 0 then
              pcall(function() qty = NPC.getSellQuantity(entry.id) end)
            end
            if qty and qty > 0 then
              NPC.sell(entry.item, qty, true)
              soldAny = true
              break -- only sell ONE item per pass directly to avoid flood/kicks!
            end
          end
        end
      end)

      if soldAny then
        consecutiveEmpty = 0
      else
        consecutiveEmpty = consecutiveEmpty + 1
        -- If for 4 consecutive passes nothing could be sold directly and at least 4 passes have run, everything is sold!
        if pass >= 4 and consecutiveEmpty >= 4 then
          warn("CaveBot[SellAll]: All items sold successfully! Finishing early at pass " .. pass .. ".")
          break
        end
      end

      delay(passDelay)
      CaveBot.delay(passDelay)
    end

    warn("CaveBot[SellAll]: Completed selling to " .. npcName .. "! Closing trade window.")
    safeCloseTrade()
    lastSoldSuccessNpc = npcName:lower()
    lastSoldSuccessTime = os.time()
    delay(800)
    CaveBot.delay(800)
    return true
  end

  CaveBot.Actions["sellall"] = nil
  CaveBot.Actions["SellAll"] = nil
  CaveBot.registerAction("SellAll", "#C300FF", callback)

  if CaveBot.Actions then
    CaveBot.Actions["sellall"] = {
      color = "#C300FF",
      callback = callback
    }
    CaveBot.Actions["SellAll"] = {
      color = "#C300FF",
      callback = callback
    }
  end

  CaveBot.Editor.registerAction("sellall", "sell all", {
    value="NPC",
    title="Sell All",
    description="NPC Name, delay in ms (default 650), exceptions: id separated by comma",
  })
end

CaveBot.Extensions.SellAll.setup()