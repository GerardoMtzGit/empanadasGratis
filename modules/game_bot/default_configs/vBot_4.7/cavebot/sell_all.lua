CaveBot.Extensions.SellAll = {}

if CaveBot and CaveBot.Actions then
  CaveBot.Actions["sellall"] = nil
  CaveBot.Actions["SellAll"] = nil
end

local function isTrading()
  if NPC and NPC.isTrading then
    local ok, res = pcall(NPC.isTrading)
    if ok and res then return true end
  end
  if modules.game_npctrade and modules.game_npctrade.npcWindow and modules.game_npctrade.npcWindow:isVisible() then
    return true
  end
  if modules.game_npctrader and modules.game_npctrader.npcWindow and modules.game_npctrader.npcWindow:isVisible() then
    return true
  end
  return false
end

local function closeTrade()
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
end

local function getCap()
  if freecap then return freecap() end
  if player and player.getFreeCapacity then return player:getFreeCapacity() end
  return 0
end

local function getTotalContainerItems()
  local total = 0
  local containers = getContainers() or {}
  for _, c in pairs(containers) do
    local items = c:getItems() or {}
    total = total + #items
  end
  return total
end

local lastTalkTime = 0
local lastSoldNpc = ""
local lastSoldTime = 0
local lastProgressCap = -1
local lastProgressItems = -1
local emptyConfirmCount = 0
local totalSoldRounds = 0

CaveBot.Extensions.SellAll.setup = function()
  local callback = function(value, retries)
    local val = string.split(value, ",")

    for i, v in ipairs(val) do
      v = v:trim()
      v = tonumber(v) or v
      val[i] = v
    end

    local npcName = val[1] and tostring(val[1]):trim() or "NPC"

    -- Initialization on retry 0
    if retries == 0 then
      lastProgressCap = -1
      lastProgressItems = -1
      emptyConfirmCount = 0
      totalSoldRounds = 0
      lastTalkTime = 0

      if botLogger and botLogger.write then
        botLogger.write("SELL:START", string.format("Iniciando waypoint sellall con '%s' | Args: '%s' | Cap: %d | Items: %d", 
          npcName, tostring(value), getCap(), getTotalContainerItems()))
      end

      -- Skip duplicate sequential waypoint if already sold recently
      if lastSoldNpc == npcName:lower() and (os.time() - lastSoldTime < 15) and not isTrading() then
        warn("CaveBot[SellAll]: Todo vendido a " .. npcName .. ". Continuando ruta.")
        return true
      end
    end

    -- Timeout protection ONLY if unable to trade after 30 retries
    if not isTrading() and retries >= 30 then
      warn("CaveBot[SellAll]: No se pudo abrir trade con " .. npcName .. ", continuando ruta.")
      closeTrade()
      return true
    end

    -- 1. Ensure player is NOT moving before interaction
    if player and player.isWalking and player:isWalking() then
      CaveBot.delay(250)
      return "retry"
    end

    -- 2. Reach NPC
    local npc = nil
    if getCreatureByName then
      npc = getCreatureByName(npcName)
    end
    if not npc and not isTrading() then
      local pos = player:getPosition()
      local spectators = (getSpectators and getSpectators()) or {}
      for _, c in ipairs(spectators) do
        if c:isNpc() then
          local cName = c:getName():lower()
          local targetName = npcName:lower()
          if cName == targetName or cName:find(targetName, 1, true) or targetName:find(cName, 1, true) then
            npc = c
            npcName = c:getName()
            break
          elseif getDistanceBetween(pos, c:getPosition()) <= 4 then
            npc = c
            npcName = c:getName()
            break
          end
        end
      end
    end

    if not npc and not isTrading() then
      if retries >= 5 then
        warn("CaveBot[SellAll]: NPC '" .. tostring(npcName) .. "' no encontrado cerca. Saltando acción.")
        if botLogger and botLogger.write then
          botLogger.write("SELL:NOTFOUND", string.format("NPC '%s' no encontrado cerca tras %d intentos. Continuando ruta.", npcName, retries))
        end
        return false
      end
      CaveBot.delay(600)
      return "retry"
    end

    if npc and not isTrading() then
      if CaveBot.ReachNPC and not CaveBot.ReachNPC(npcName) then
        CaveBot.delay(500)
        return "retry"
      end
    end

    -- 3. If trade is NOT open, calmly speak to NPC
    if not isTrading() then
      local now = os.time()
      if (now - lastTalkTime) >= 3 then
        lastTalkTime = now
        warn("CaveBot[SellAll]: Abriendo trade con " .. tostring(npcName) .. "...")
        if botLogger and botLogger.write then
          botLogger.write("SELL:TALK", string.format("Saludando a '%s' (intento #%d)", npcName, retries))
        end

        -- Greet NPC cleanly
        pcall(function()
          if NPC and NPC.say then
            NPC.say("hi")
          elseif say then
            say("hi")
          elseif g_game and g_game.talk then
            g_game.talk("hi")
          end
        end)

        -- Send trade request after 1000ms
        schedule(1000, function()
          if not isTrading() then
            pcall(function()
              if NPC and NPC.say then
                NPC.say("trade")
              elseif say then
                say("trade")
              elseif g_game and g_game.talk then
                g_game.talk("trade")
              end
            end)
          end
        end)

        CaveBot.delay(3000)
        return "retry"
      else
        CaveBot.delay(800)
        return "retry"
      end
    end

    -- 4. Trade window is OPEN!
    local currentCap = getCap()
    local currentItems = getTotalContainerItems()
    local waitParam = (val[2] == "yes" or table.find(val, "yes", true)) and true or false

    -- Custom delay parameter support (e.g. sellall ZurdoGM,1800 or sellall ZurdoGM,yes)
    local customDelay = nil
    for idx = 2, #val do
      if type(val[idx]) == "number" and val[idx] >= 200 then
        customDelay = val[idx]
        break
      end
    end
    -- Slower selling delay to ensure safe, human-paced execution
    local sellDelay = customDelay or (waitParam and 1500 or 1300)

    -- Check progress
    local progressMade = false
    if lastProgressCap >= 0 and currentCap > lastProgressCap then
      progressMade = true
    end
    if lastProgressItems >= 0 and currentItems < lastProgressItems then
      progressMade = true
    end

    if progressMade then
      totalSoldRounds = totalSoldRounds + 1
      emptyConfirmCount = 0
      if botLogger and botLogger.write then
        botLogger.write("SELL:PROGRESS", string.format("Venta detectada! Cap: %d -> %d | Items: %d -> %d (Ronda #%d)", 
          lastProgressCap, currentCap, lastProgressItems, currentItems, totalSoldRounds))
      end
      lastProgressCap = currentCap
      lastProgressItems = currentItems
    elseif lastProgressCap < 0 then
      lastProgressCap = currentCap
      lastProgressItems = currentItems
    end

    -- 5. Execute sellAll cleanly and safely
    pcall(function()
      if modules.game_npctrade and modules.game_npctrade.sellAll then
        modules.game_npctrade.sellAll(waitParam, val)
      elseif modules.game_npctrader and modules.game_npctrader.sellAll then
        modules.game_npctrader.sellAll(waitParam, val)
      elseif NPC and NPC.sellAll then
        NPC.sellAll()
      end
    end)

    if botLogger and botLogger.write and (totalSoldRounds == 0 or progressMade) then
      botLogger.write("SELL:DISPATCH", string.format("sellAll ejecutado (wait=%s, delay=%dms, cap=%d)", 
        tostring(waitParam), sellDelay, currentCap))
    end

    -- If progress was made, continue selling
    if progressMade then
      emptyConfirmCount = 0
      CaveBot.delay(sellDelay)
      return "retry"
    end

    -- 6. No progress: check nested backpacks!
    local openedSubContainer = false
    local containers = getContainers() or {}
    for _, container in pairs(containers) do
      local cId = container:getContainerItem() and container:getContainerItem():getId()
      if cId then
        for _, item in ipairs(container:getItems() or {}) do
          if item:getId() == cId and item:isContainer() then
            if botLogger and botLogger.write then
              botLogger.write("SELL:NESTED", string.format("Abriendo mochila interior ID %d en '%s'...", cId, container:getName() or "Mochila"))
            end
            g_game.open(item, container)
            openedSubContainer = true
            break
          end
        end
      end
      if openedSubContainer then break end
    end

    if openedSubContainer then
      warn("CaveBot[SellAll]: Abriendo siguiente mochila de loot...")
      emptyConfirmCount = 0
      lastProgressItems = -1
      CaveBot.delay(1000)
      return "retry"
    end

    -- 7. No progress and no nested backpacks: increment confirmation checks
    emptyConfirmCount = emptyConfirmCount + 1
    if botLogger and botLogger.write then
      botLogger.write("SELL:CHECK", string.format("Confirmacion %d de 4 (sin cambios en cap ni items)", emptyConfirmCount))
    end

    if emptyConfirmCount < 4 then
      CaveBot.delay(sellDelay)
      return "retry"
    end

    -- 8. Confirmed 100% sold after 4 consecutive rounds!
    warn("CaveBot[SellAll]: 100% de ítems vendidos con éxito. Continuando ruta.")
    if botLogger and botLogger.write then
      botLogger.write("SELL:COMPLETE", string.format("Venta con '%s' completada al 100%% tras %d rondas. Cap final: %d. Cerrando trade.", 
        npcName, totalSoldRounds, getCap()))
    end

    closeTrade()
    lastSoldNpc = npcName:lower()
    lastSoldTime = os.time()
    emptyConfirmCount = 0
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
    description="NPC Name, 'yes' (1500ms delay) or ms (e.g. 1800), exceptions: id separated by comma",
  })
end

CaveBot.Extensions.SellAll.setup()