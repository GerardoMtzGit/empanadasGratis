CaveBot.Extensions.SellAll = {}

-- Clear existing registered action so CaveBot reload actually updates the callback!
if CaveBot and CaveBot.Actions then
  CaveBot.Actions["sellall"] = nil
end

local sellAllCap = -1
local sellState = 0 -- 0: idle/init, 1: trading/selling

-- Helper to switch UI tab to 'Vender' (Sell) in case OTClient trade UI requires it
local function switchToSellTab()
  if not modules.game_npctrade or not modules.game_npctrade.npcWindow then return end
  local win = modules.game_npctrade.npcWindow
  
  -- Try native enum/function if available
  pcall(function()
    if modules.game_npctrade.setTradeType and modules.game_npctrade.SELL then
      modules.game_npctrade.setTradeType(modules.game_npctrade.SELL)
    end
  end)
  
  -- Try clicking known widget ids
  pcall(function()
    local sellTab = win:recursiveGetChildById("sellTab") or win:recursiveGetChildById("tabSell") or win:recursiveGetChildById("sellButton")
    if sellTab then
      sellTab:focus()
      if sellTab.onClick then sellTab:onClick() end
    end
  end)
  
  -- Try finding tab button with text "Vender" or "Sell"
  pcall(function()
    local function findChildByText(widget)
      if not widget then return nil end
      if widget.getText then
        local t = tostring(widget:getText()):lower()
        if t == "vender" or t == "sell" then
          return widget
        end
      end
      for _, child in ipairs(widget:getChildren() or {}) do
        local found = findChildByText(child)
        if found then return found end
      end
      return nil
    end
    local btn = findChildByText(win)
    if btn then
      btn:focus()
      if btn.onClick then btn:onClick() end
    end
  end)
end

-- Helper to safely close trade
local function safeCloseTrade()
  pcall(function()
    if NPC and NPC.closeTrade then
      NPC.closeTrade()
    elseif modules.game_npctrade and modules.game_npctrade.closeNpcTrade then
      modules.game_npctrade.closeNpcTrade()
    end
  end)
  pcall(function()
    if modules.game_npctrade and modules.game_npctrade.npcWindow and modules.game_npctrade.npcWindow:isVisible() then
      modules.game_npctrade.npcWindow:hide()
    end
  end)
end

CaveBot.Extensions.SellAll.setup = function()
  local callback = function(value, retries)
    local val = string.split(value, ",")
    local wait = false

    -- table formatting
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
    if not npc then 
      print("CaveBot[SellAll]: NPC '" .. tostring(npcName) .. "' not found! skipping")
      safeCloseTrade()
      sellAllCap = -1
      return false 
    end

    -- Timeout protection: if stuck for too many retries, close trade and proceed so cavebot does not freeze
    if retries > 35 then
      print("CaveBot[SellAll]: Max retries reached (" .. retries .. "), closing trade and proceeding")
      safeCloseTrade()
      sellAllCap = -1
      delay(1000)
      CaveBot.delay(1000)
      return true
    end

    -- Reset capacity baseline on fresh start
    if retries == 0 then
      sellAllCap = -1
      sellState = 0
    end

    delay(600)
    CaveBot.delay(600)
    if not CaveBot.ReachNPC(npcName) then
      return "retry"
    end

    -- If trade is not open, open it and wait at least 7 seconds as requested!
    if not NPC.isTrading() then
      print("CaveBot[SellAll]: Saying hi/trade to " .. tostring(npcName) .. ", waiting 7s for trade window...")
      CaveBot.OpenNpcTrade()
      local waitTrade = 7000
      delay(waitTrade)
      CaveBot.delay(waitTrade)
      sellState = 1
      return "retry"
    end

    -- Switch to "Vender" tab
    switchToSellTab()

    -- Check sellable items
    local sellItems = {}
    pcall(function() sellItems = NPC.getSellItems() end)
    if not sellItems then sellItems = {} end

    -- Count how many sellable items the player actually has
    local itemsToSell = {}
    local totalItemsCount = 0
    for _, entry in ipairs(sellItems) do
      -- Check exceptions
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
          table.insert(itemsToSell, { item = entry.item, id = entry.id, name = entry.name, count = qty })
          totalItemsCount = totalItemsCount + qty
        end
      end
    end

    -- If we have sold before (sellState == 2) or no items to sell:
    if totalItemsCount == 0 or (sellState == 2 and freecap() == sellAllCap) then
      print("CaveBot[SellAll]: All items sold! Closing trade window and proceeding.")
      safeCloseTrade()
      sellAllCap = -1
      sellState = 0
      delay(1000)
      CaveBot.delay(1000)
      return true
    end

    -- Now perform selling
    print("CaveBot[SellAll]: Found " .. #itemsToSell .. " item types (" .. totalItemsCount .. " items) to sell.")
    sellAllCap = freecap()
    sellState = 2

    -- 1) Try native OTC sellAll
    pcall(function()
      modules.game_npctrade.sellAll(wait, val)
    end)

    -- 2) Direct selling of each item to guarantee everything sells even if UI sellAll fails
    for _, toSell in ipairs(itemsToSell) do
      pcall(function()
        print("CaveBot[SellAll]: Selling " .. toSell.count .. "x " .. (toSell.name or toSell.id))
        NPC.sell(toSell.item, toSell.count, true)
      end)
      if wait then
        delay(150)
      end
    end

    local afterSellDelay = wait and 2500 or 1500
    delay(afterSellDelay)
    CaveBot.delay(afterSellDelay)
    return "retry"
  end

  CaveBot.Actions["sellall"] = nil
  CaveBot.registerAction("SellAll", "#C300FF", callback)

  -- In case CaveBot.registerAction skipped due to duplicate, force direct assignment
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