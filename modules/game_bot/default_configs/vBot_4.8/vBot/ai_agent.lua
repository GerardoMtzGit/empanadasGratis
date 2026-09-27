-- ============================================================
-- HegalOT AI Agent - Modulo Lua del cliente
-- Lee comandos del agente IA y los ejecuta en el juego
-- 
-- INSTALACION: Copia este archivo a:
--   %APPDATA%\hegalot\hegalot\hegalot\bot\vBot_4.8\vBot\ai_agent.lua
-- Y agregalo al final del _Loader.lua con:
--   dofile("vBot/ai_agent.lua")
-- ============================================================

local AI = {}
local AI_COMMANDS_FILE = "/bot/vBot_4.8/storage/ai_commands.json"
local AI_STATE_FILE    = "/bot/vBot_4.8/storage/ai_state.json"
local lastCommandTs = 0
local stateUpdateInterval = 1000  -- ms entre cada actualizacion de estado

-- -------------------------------------------------------
-- EXPORTAR ESTADO DEL JUEGO al archivo ai_state.json
-- Para que el agente IA sepa que esta pasando en el juego
-- -------------------------------------------------------
local function exportGameState()
  if not player then return end
  local pos = player:getPosition()
  local monsters = 0
  if pos then
    local specs = g_map.getSpectatorsInRange(pos, false, 7, 7)
    for _, spec in ipairs(specs) do
      if spec:isMonster() then monsters = monsters + 1 end
    end
  end

  local state = {
    hp       = player:getHealth(),
    hp_max   = player:getMaxHealth(),
    mp       = player:getMana(),
    mp_max   = player:getMaxMana(),
    level    = player:getLevel(),
    pos      = pos and {x=pos.x, y=pos.y, z=pos.z} or {x=0,y=0,z=0},
    monsters = monsters,
    cavebot  = CaveBot and CaveBot.isOn and CaveBot.isOn() or false,
    targetbot= TargetBot and TargetBot.isOn and TargetBot.isOn() or false,
    last_update = tostring(os.time()),
  }

  local ok, encoded = pcall(json.encode, state)
  if ok and encoded then
    g_resources.writeFileContents(AI_STATE_FILE, encoded)
  end
end

-- -------------------------------------------------------
-- EJECUTAR COMANDO recibido del agente IA
-- -------------------------------------------------------
local function executeCommand(action, params)
  params = params or {}

  if action == "cavebot_on" then
    if CaveBot and CaveBot.setOn then
      CaveBot.setOn()
      print("[AI Agent] CaveBot activado")
    end

  elseif action == "cavebot_off" then
    if CaveBot and CaveBot.setOff then
      CaveBot.setOff()
      print("[AI Agent] CaveBot desactivado")
    end

  elseif action == "targetbot_on" then
    if TargetBot and TargetBot.setOn then
      TargetBot.setOn()
      print("[AI Agent] TargetBot activado")
    end

  elseif action == "targetbot_off" then
    if TargetBot and TargetBot.setOff then
      TargetBot.setOff()
      print("[AI Agent] TargetBot desactivado")
    end

  elseif action == "healbot_on" then
    -- HealBot usa storage para activarse (ajustar segun vBot)
    if storage and storage.healbot ~= nil then
      storage.healbot = true
      print("[AI Agent] HealBot activado")
    else
      print("[AI Agent] HealBot no disponible en este perfil")
    end

  elseif action == "healbot_off" then
    if storage and storage.healbot ~= nil then
      storage.healbot = false
      print("[AI Agent] HealBot desactivado")
    end

  elseif action == "dynamiclure_on" then
    -- Activa dynamic lure en la config activa del targetbot
    if TargetBot and TargetBot.targetList then
      for _, entry in ipairs(TargetBot.targetList:getChildren()) do
        if entry.value then
          entry.value.dynamicLure = true
          entry.value.dynamicLureDelay = true
        end
      end
      TargetBot.Creature.resetConfigsCache()
      print("[AI Agent] Dynamic Lure activado en todas las criaturas")
    end

  elseif action == "dynamiclure_off" then
    if TargetBot and TargetBot.targetList then
      for _, entry in ipairs(TargetBot.targetList:getChildren()) do
        if entry.value then
          entry.value.dynamicLure = false
          entry.value.dynamicLureDelay = false
        end
      end
      TargetBot.Creature.resetConfigsCache()
      print("[AI Agent] Dynamic Lure desactivado")
    end

  elseif action == "status" then
    -- Forzar exportacion de estado inmediatamente
    exportGameState()
    local hp = player:getHealth()
    local mp = player:getMana()
    local lvl = player:getLevel()
    print(string.format("[AI Agent] HP:%d  MP:%d  Lvl:%d", hp, mp, lvl))

  elseif action == "none" then
    -- No hacer nada

  else
    print("[AI Agent] Comando desconocido: " .. tostring(action))
  end
end

-- -------------------------------------------------------
-- LOOP PRINCIPAL: lee comandos cada 500ms
-- -------------------------------------------------------
local lastStateExport = 0

macro(500, function()
  local nowMs = now or 0

  -- Exportar estado del juego periodicamente
  if nowMs - lastStateExport >= stateUpdateInterval then
    lastStateExport = nowMs
    exportGameState()
  end

  -- Leer comandos del agente IA
  if not g_resources.fileExists(AI_COMMANDS_FILE) then return end

  local ok, data = pcall(function()
    local raw = g_resources.readFileContents(AI_COMMANDS_FILE)
    if not raw or raw:len() < 3 then return nil end
    return json.decode(raw)
  end)

  if not ok or not data then return end

  local ts = tonumber(data.ts) or 0
  if ts <= lastCommandTs then return end  -- ya procesamos este comando

  lastCommandTs = ts
  local action = data.action or "none"
  local params = data.params or {}

  if action ~= "none" then
    print("[AI Agent] Ejecutando: " .. action)
    local cmdOk, err = pcall(executeCommand, action, params)
    if not cmdOk then
      print("[AI Agent] Error ejecutando comando: " .. tostring(err))
    end
  end
end)

print("[AI Agent] Modulo cargado. Esperando instrucciones de voz...")
