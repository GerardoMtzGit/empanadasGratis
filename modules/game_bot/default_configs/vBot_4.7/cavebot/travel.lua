CaveBot.Extensions.Travel = {}

local travelStep = 0
local lastTravelKey = ""
local STEP_DELAY = 2000 -- 2000ms (2 segundos) de cooldown interno entre cada interacción

local function safeSay(text)
  if NPC and NPC.say then
    pcall(NPC.say, text)
  elseif say then
    pcall(say, text)
  elseif g_game and g_game.talk then
    pcall(g_game.talk, text)
  end
end

CaveBot.Extensions.Travel.setup = function()
  CaveBot.registerAction("Travel", "#db5a5a", function(value, retries)
    local data = string.split(value, ",")
    if #data < 2 then
      warn("CaveBot[Travel]: formato incorrecto! Debe ser: NPC, Destino (ej: Captain Bluebear, port hope)")
      return false
    end

    local npcName = data[1]:trim()
    local dest = data[2]:trim()
    local travelKey = npcName:lower() .. ":" .. dest:lower()

    if retries == 0 or travelKey ~= lastTravelKey then
      travelStep = 0
      lastTravelKey = travelKey
    end

    if retries > 20 then
      warn("CaveBot[Travel]: demasiados intentos, no se pudo completar el viaje a '" .. dest .. "' con '" .. npcName .. "'. Continuando ruta.")
      if botLogger and botLogger.write then
        botLogger.write("TRAVEL:TIMEOUT", string.format("Demasiados reintentos para viajar con '%s' a '%s'", npcName, dest))
      end
      travelStep = 0
      return false
    end

    -- 1. Localizar y alcanzar al NPC
    local npc = nil
    if getCreatureByName then
      npc = getCreatureByName(npcName)
    end
    if not npc then
      local pos = player:getPosition()
      local specs = (getSpectators and getSpectators()) or {}
      for _, c in ipairs(specs) do
        if c:isNpc() then
          local cName = c:getName():lower()
          local targetName = npcName:lower()
          if cName == targetName or cName:find(targetName, 1, true) or targetName:find(cName, 1, true) then
            npc = c
            npcName = c:getName()
            break
          elseif pos and c:getPosition() and getDistanceBetween(pos, c:getPosition()) <= 4 then
            npc = c
            npcName = c:getName()
            break
          end
        end
      end
    end

    if not npc then
      if retries >= 5 then
        warn("CaveBot[Travel]: NPC '" .. npcName .. "' no encontrado cerca. Continuando ruta.")
        travelStep = 0
        return false
      end
      CaveBot.delay(600)
      return "retry"
    end

    if CaveBot.ReachNPC and not CaveBot.ReachNPC(npcName) then
      CaveBot.delay(500)
      return "retry"
    end

    -- 2. Máquina de estados con cooldown interno de al menos 2 segundos entre cada acción
    if travelStep == 0 then
      -- Paso 1: Saludar (HI) y esperar al menos 2 segundos
      warn("CaveBot[Travel]: Iniciando viaje con " .. npcName .. " -> diciendo 'hi'...")
      if botLogger and botLogger.write then
        botLogger.write("TRAVEL", string.format("Paso 1: Saludando a '%s' (hi) | Esperando %dms", npcName, STEP_DELAY))
      end
      safeSay("hi")
      travelStep = 1
      CaveBot.delay(STEP_DELAY)
      return "retry"

    elseif travelStep == 1 then
      -- Paso 2: Decir Destino y esperar al menos 2 segundos
      warn("CaveBot[Travel]: Solicitando viajar a '" .. dest .. "'...")
      if botLogger and botLogger.write then
        botLogger.write("TRAVEL", string.format("Paso 2: Pidiendo destino '%s' a '%s' | Esperando %dms", dest, npcName, STEP_DELAY))
      end
      safeSay(dest)
      travelStep = 2
      CaveBot.delay(STEP_DELAY)
      return "retry"

    elseif travelStep == 2 then
      -- Paso 3: Confirmar viaje con YES y esperar al menos 2 segundos
      warn("CaveBot[Travel]: Confirmando viaje ('yes')...")
      if botLogger and botLogger.write then
        botLogger.write("TRAVEL", string.format("Paso 3: Confirmando viaje (yes) a '%s' | Esperando %dms", dest, STEP_DELAY))
      end
      safeSay("yes")
      travelStep = 3
      CaveBot.delay(STEP_DELAY)
      return "retry"

    elseif travelStep == 3 then
      -- Paso 4: Viaje finalizado con éxito
      warn("CaveBot[Travel]: Viaje a '" .. dest .. "' completado con éxito. Continuando ruta...")
      if botLogger and botLogger.write then
        botLogger.write("TRAVEL:COMPLETE", string.format("Viaje a '%s' completado con éxito tras pausas de %dms. Continuando ruta.", dest, STEP_DELAY))
      end
      travelStep = 0
      CaveBot.delay(1000) -- Pausa de 1 segundo de seguridad para estabilizarse en el nuevo barco
      return true
    end

    travelStep = 0
    return true
  end)

  CaveBot.Editor.registerAction("travel", "travel", {
    value = "Captain Bluebear, port hope",
    title = "Travel",
    description = "Nombre del NPC, Nombre de la ciudad (espera 2s entre cada mensaje)",
  })
end