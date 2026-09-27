CaveBot.Extensions.SellAll = {}

if CaveBot and CaveBot.Actions then
  CaveBot.Actions["sellall"] = nil
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

-- Switch to the "Vender" tab
local function switchToSellTab()
  local win = getNpcTradeWindow()
  if not win then return end

  -- Sync npcWindow variable so modules.game_npctrade doesn't fail
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

    local npcName = val[1]
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

    -- Timeout protection
    if retries >= 4 then
      warn("CaveBot[SellAll]: Timeout limit reached, closing trade window and proceeding.")
      safeCloseTrade()
      delay(800)
      CaveBot.delay(800)
      return true
    end

    delay(300)
    CaveBot.delay(300)
    if npc and not CaveBot.ReachNPC(npcName) then
      return "retry"
    end

    -- Open trade window if not open
    if not isTradeWindowOpen() then
      warn("CaveBot[SellAll]: Saying hi/trade to " .. tostring(npcName) .. ", waiting 7s for trade window...")
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

    warn("CaveBot[SellAll]: Trade window is open! Switching to 'Vender' tab...")
    switchToSellTab()
    delay(500)
    CaveBot.delay(500)

    -- Also say "yes" in case of autoloot bag
    pcall(function()
      if NPC and NPC.say then NPC.say("yes") end
      say("yes")
    end)

    warn("CaveBot[SellAll]: Executing 12 sell passes to sell all items...")
    for round = 1, 12 do
      -- 1. Native module sellAll
      pcall(function()
        if modules.game_npctrade and modules.game_npctrade.sellAll then
          modules.game_npctrade.sellAll(wait, val)
        end
        if modules.game_npctrader and modules.game_npctrader.sellAll then
          modules.game_npctrader.sellAll(wait, val)
        end
        if NPC and NPC.sellAll then
          NPC.sellAll()
        end
      end)

      -- 2. Direct inventory selling via NPC.sell
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
            end
          end
        end
      end)

      delay(120)
    end

    local afterDelay = wait and 1800 or 1000
    delay(afterDelay)
    CaveBot.delay(afterDelay)

    warn("CaveBot[SellAll]: All 12 sell passes completed! Closing trade window.")
    safeCloseTrade()
    delay(600)
    CaveBot.delay(600)
    return true
  end

  CaveBot.Actions["sellall"] = nil
  CaveBot.registerAction("SellAll", "#C300FF", callback)

  if CaveBot.Actions then
    CaveBot.Actions["sellall"] = {
      color = "#C300FF",
      callback = callback
    }
  end

  CaveBot.Editor.registerAction("sellall", "sell all", {
    value="NPC",
    title="Sell All",
    description="NPC Name, 'yes' if sell with delay, exceptions: id separated by comma",
  })
end

CaveBot.Extensions.SellAll.setup()