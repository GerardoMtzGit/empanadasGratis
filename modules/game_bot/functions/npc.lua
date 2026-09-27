local context = G.botContext

context.NPC = {}

context.NPC.talk = function(text)
  if g_game.getClientVersion() >= 810 then
    g_game.talkChannel(11, 0, text) 
  else
    return context.say(text)
  end
end
context.NPC.say = context.NPC.talk

context.NPC.isTrading = function()
  if modules.game_npctrade and modules.game_npctrade.npcWindow and modules.game_npctrade.npcWindow:isVisible() then
    return true
  end
  if modules.game_npctrader then
    for _, var in ipairs({"npcWindow", "tradeWindow", "window", "traderWindow", "ui"}) do
      if modules.game_npctrader[var] and modules.game_npctrader[var].isVisible and modules.game_npctrader[var]:isVisible() then
        return true
      end
    end
  end
  local root = g_ui and g_ui.getRootWidget and g_ui.getRootWidget()
  if root then
    for _, w in ipairs(root:getChildren() or {}) do
      if w:isVisible() then
        local t = w.getText and tostring(w:getText()):lower() or ""
        local id = tostring(w:getId()):lower()
        if t:find("intercambio con npc") or t:find("npc trade") or id:find("npctrade") or id:find("npcwindow") then
          return true
        end
        local title = w:getChildById("title") or w:getChildById("windowText")
        if title and title.getText and tostring(title:getText()):lower():find("intercambio con npc") then
          return true
        end
      end
    end
  end
  return false
end
context.NPC.hasTrade = context.NPC.isTrading
context.NPC.hasTradeWindow = context.NPC.isTrading
context.NPC.isTradeOpen = context.NPC.isTrading

context.NPC.getSellItems = function()
  if not context.NPC.isTrading() then return {} end
  local items = {}
  local tradeItems = (modules.game_npctrade and modules.game_npctrade.tradeItems) or (modules.game_npctrader and (modules.game_npctrader.tradeItems or modules.game_npctrader.items))
  local sellType = (modules.game_npctrade and modules.game_npctrade.SELL) or (modules.game_npctrader and modules.game_npctrader.SELL) or 2
  if tradeItems and tradeItems[sellType] then
    for i, item in ipairs(tradeItems[sellType]) do
      local itPtr = item.ptr or (item.getId and item)
      local itId = (itPtr and itPtr:getId()) or item.id or (item.getItemId and item:getItemId())
      if itId then
        table.insert(items, {
          item = itPtr or Item.create(itId),
          id = itId,
          count = (itPtr and itPtr:getCount()) or item.count or 1,
          name = item.name or "",
          subType = (itPtr and itPtr:getSubType()) or 0,
          weight = (item.weight or 0) / 100,
          price = item.price or 0
        })
      end
    end
  end
  return items
end

context.NPC.getBuyItems = function()
  if not context.NPC.isTrading() then return {} end
  local items = {}
  local tradeItems = (modules.game_npctrade and modules.game_npctrade.tradeItems) or (modules.game_npctrader and (modules.game_npctrader.tradeItems or modules.game_npctrader.items))
  local buyType = (modules.game_npctrade and modules.game_npctrade.BUY) or (modules.game_npctrader and modules.game_npctrader.BUY) or 1
  if tradeItems and tradeItems[buyType] then
    for i, item in ipairs(tradeItems[buyType]) do
      local itPtr = item.ptr or (item.getId and item)
      local itId = (itPtr and itPtr:getId()) or item.id or (item.getItemId and item:getItemId())
      if itId then
        table.insert(items, {
          item = itPtr or Item.create(itId),
          id = itId,
          count = (itPtr and itPtr:getCount()) or item.count or 1,
          name = item.name or "",
          subType = (itPtr and itPtr:getSubType()) or 0,
          weight = (item.weight or 0) / 100,
          price = item.price or 0
        })
      end
    end
  end
  return items
end

context.NPC.getSellQuantity = function(item)
  if not context.NPC.isTrading() then return 0 end
  if type(item) == 'number' then
     item = Item.create(item)
  end
  if modules.game_npctrade and modules.game_npctrade.getSellQuantity then
    return modules.game_npctrade.getSellQuantity(item)
  end
  if modules.game_npctrader and modules.game_npctrader.getSellQuantity then
    return modules.game_npctrader.getSellQuantity(item)
  end
  return 0
end

context.NPC.canTradeItem = function(item)
  if not context.NPC.isTrading() then return false end
  if type(item) == 'number' then
     item = Item.create(item)
  end
  if modules.game_npctrade and modules.game_npctrade.canTradeItem then
    return modules.game_npctrade.canTradeItem(item)
  end
  if modules.game_npctrader and modules.game_npctrader.canTradeItem then
    return modules.game_npctrader.canTradeItem(item)
  end
  return false
end

context.NPC.sell = function(item, count, ignoreEquipped)
  local itemObj = nil
  if type(item) == 'number' then
    for i, entry in ipairs(context.NPC.getSellItems()) do
       if entry.id == item then
         itemObj = entry.item
         break
       end
    end
    if not itemObj then
      pcall(function() itemObj = Item.create(item) end)
    end
  else
    itemObj = item
  end
  if count == 0 then
    count = 1
  end
  if count == nil or count == -1 then
    count = context.NPC.getSellQuantity(itemObj or item)
  end
  if ignoreEquipped == nil then
    ignoreEquipped = true
  end
  if itemObj and g_game and g_game.sellItem then
    pcall(function() g_game.sellItem(itemObj, count, ignoreEquipped) end)
  end
end

context.NPC.buy = function(item, count, ignoreCapacity, withBackpack)
  local itemObj = nil
  if type(item) == 'number' then
    for i, entry in ipairs(context.NPC.getBuyItems()) do
       if entry.id == item then
         itemObj = entry.item
         break
       end
    end
    if not itemObj then
      pcall(function() itemObj = Item.create(item) end)
    end
  else
    itemObj = item
  end
  if count == nil or count <= 0 then
    count = 1
  end
  if ignoreCapacity == nil then
    ignoreCapacity = false
  end
  if withBackpack == nil then
    withBackpack = false
  end
  pcall(function()
    if modules.game_npctrader and modules.game_npctrader.buyItem then
      modules.game_npctrader.buyItem(itemObj or item, count)
    end
  end)
  pcall(function()
    if modules.game_npctrade and modules.game_npctrade.buyItem then
      modules.game_npctrade.buyItem(itemObj or item, count)
    end
  end)
  if itemObj and g_game and g_game.buyItem then
    pcall(function()
      g_game.buyItem(itemObj, count, ignoreCapacity, withBackpack)
    end)
  end
end

context.NPC.sellAll = function()
  if not context.NPC.isTrading() then return false end
  modules.game_npctrade.sellAll()
end

context.NPC.closeTrade = function()
  modules.game_npctrade.closeNpcTrade()
end
context.NPC.close = context.NPC.closeTrade
context.NPC.finish = context.NPC.closeTrade
context.NPC.endTrade = context.NPC.closeTrade
context.NPC.finishTrade = context.NPC.closeTrade