local targetingTab = storage.extras and storage.extras.joinBot and "Cave" or "Target"
setDefaultTab(targetingTab)

local panelName = "druid_targeting"

if not storage[panelName] then
  storage[panelName] = {
    enabled = false,
    ulusSpell = "exevo ulus tera",
    ulusCooldown = 4000, -- Cooldown en ms
    ulusShape = 1,       -- 1: Onda Frontal (Wave con auto-giro), 2: Area 360 (UE), 3: Auto
    areaRuneId = 3202,   -- Thunderstorm / Thunderlord
    singleSpell = "exori gran tera",
    powerRatio = 22,     -- 2.2x ratio de potencia Ulus vs Runa
    delay = 201,         -- 201 ms delay entre ataques
    autoTurn = true,     -- Acomodar direccion para onda
    autoStep = false,    -- Acomodar paso de 1 SQM si gana >= 2 monstruos
    safePvp = true,      -- No dañar jugadores ni aliados
    ignoreParty = true,  -- Ignorar party y familiars aliados
    prioritizeMana = true, -- Reservar >20% de mana para curarse
    autoTarget = true    -- Atacar al mas cercano si no hay target
  }
end

local config = storage[panelName]

-- Validaciones de configuracion
if not config.ulusSpell or config.ulusSpell == "" then
  config.ulusSpell = "exevo ulus tera"
end
if not config.ulusCooldown or config.ulusCooldown <= 0 then
  config.ulusCooldown = 4000
end
if not config.ulusShape then
  config.ulusShape = 1
end
if not config.areaRuneId or config.areaRuneId <= 0 then
  config.areaRuneId = 3202
end
if not config.singleSpell or config.singleSpell == "" then
  config.singleSpell = "exori gran tera"
end
if not config.powerRatio then
  config.powerRatio = 22
end
if not config.delay or config.delay <= 0 then
  config.delay = 201
end
if config.autoTurn == nil then
  config.autoTurn = true
end
if config.safePvp == nil then
  config.safePvp = true
end
if config.prioritizeMana == nil then
  config.prioritizeMana = true
end
if config.autoTarget == nil then
  config.autoTarget = true
end

-- Interfaz en la pestaña Target
local ui = setupUI([[
Panel
  height: 52
  margin-top: 5
  margin-left: 2
  margin-right: 2

  BotSwitch
    id: title
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: configBtn.left
    margin-right: 4
    height: 20
    text-align: center
    !text: tr('Targeting de Druid')

  Button
    id: configBtn
    anchors.top: parent.top
    anchors.right: parent.right
    width: 48
    height: 20
    text: Setup
    font: cipsoftFont

  Label
    id: status
    anchors.top: prev.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    margin-top: 3
    font: cipsoftFont
    text-align: center
    color: #a0a0a0
    text: [OFF] Targeting de Druid (High DPS)

  HorizontalSeparator
    anchors.top: prev.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    margin-top: 5
]])

-- Ventana de configuracion
local druidWindow = UI.createWindow('DruidTargetingWindow')
druidWindow:hide()

local runeNames = {
  [3202] = "Thunderstorm / Thunderlord",
  [2315] = "Thunderstorm / Thunderlord",
  [3161] = "Avalanche",
  [2274] = "Avalanche",
  [3175] = "Stone Shower",
  [2288] = "Stone Shower",
  [3191] = "Great Fireball (GFB)",
  [2304] = "Great Fireball (GFB)",
  [3155] = "Sudden Death (SD)",
  [2268] = "Sudden Death (SD)"
}

local runeAltIds = {
  [3202] = 2315, [2315] = 3202,
  [3161] = 2274, [2274] = 3161,
  [3175] = 2288, [2288] = 3175,
  [3191] = 2304, [2304] = 3191,
  [3155] = 2268, [2268] = 3155
}

local function getRuneName(id)
  return runeNames[id] or ("ID:" .. tostring(id))
end

local function updateStatus(customText)
  if customText then
    ui.status:setText(customText)
    ui.status:setColor(config.enabled and "#55ff55" or "#a0a0a0")
    return
  end

  local onText = config.enabled and "[ON]" or "[OFF]"
  local ratioText = string.format("%.1fx", (config.powerRatio or 22) / 10.0)
  ui.status:setText(string.format("%s Druid DPS | Ulus / %s (Ratio %s)", onText, getRuneName(config.areaRuneId), ratioText))
  ui.status:setColor(config.enabled and "#55ff55" or "#a0a0a0")
end

-- Poblar opciones de formas de spell
local shapeOptions = {
  { text = "Onda Frontal / Wave (Auto-Acomodar giro)", id = 1 },
  { text = "Area Grande 360 (UE / Mas Tera)", id = 2 },
  { text = "Auto (Elige mejor dano)", id = 3 }
}
for _, opt in ipairs(shapeOptions) do
  druidWindow.ulusShapeCombo:addOption(opt.text, opt.id)
end

-- Poblar opciones de runas
local areaRuneOptions = {
  { text = "Thunderstorm / Thunderlord (3202)", id = 3202 },
  { text = "Avalanche (3161)", id = 3161 },
  { text = "Stone Shower (3175)", id = 3175 },
  { text = "Great Fireball (3191)", id = 3191 }
}
for _, r in ipairs(areaRuneOptions) do
  druidWindow.areaRuneCombo:addOption(r.text, r.id)
end

-- Sincronizar UI con Storage
druidWindow.ulusSpell:setText(config.ulusSpell)
druidWindow.ulusCooldown:setText(tostring(config.ulusCooldown or 4000))
druidWindow.singleSpell:setText(config.singleSpell)
druidWindow.powerRatio:setValue(config.powerRatio or 22)
druidWindow.ratioLabel:setText(string.format("Potencia Ulus vs Runa (Ratio x): %.1fx", (config.powerRatio or 22) / 10.0))
druidWindow.delay:setValue(config.delay or 201)
druidWindow.delayLabel:setText(string.format("Delay entre ataques: %d ms", config.delay or 201))
druidWindow.autoTurn:setChecked(config.autoTurn)
druidWindow.autoStep:setChecked(config.autoStep)
druidWindow.safePvp:setChecked(config.safePvp)
druidWindow.prioritizeMana:setChecked(config.prioritizeMana)

-- Callbacks de UI
druidWindow.ulusSpell.onTextChange = function(widget, text)
  config.ulusSpell = text:trim()
  updateStatus()
end

druidWindow.ulusCooldown.onTextChange = function(widget, text)
  local n = tonumber(text)
  if n and n >= 500 then
    config.ulusCooldown = n
  end
end

druidWindow.ulusShapeCombo.onOptionChange = function(widget, text, data)
  config.ulusShape = data
end

druidWindow.areaRuneCombo.onOptionChange = function(widget, text, data)
  config.areaRuneId = data
  updateStatus()
end

druidWindow.singleSpell.onTextChange = function(widget, text)
  config.singleSpell = text:trim()
end

druidWindow.powerRatio.onValueChange = function(widget, value)
  config.powerRatio = value
  druidWindow.ratioLabel:setText(string.format("Potencia Ulus vs Runa (Ratio x): %.1fx", value / 10.0))
  updateStatus()
end

druidWindow.delay.onValueChange = function(widget, value)
  config.delay = value
  druidWindow.delayLabel:setText(string.format("Delay entre ataques: %d ms", value))
end

druidWindow.autoTurn.onClick = function(widget)
  config.autoTurn = not config.autoTurn
  widget:setChecked(config.autoTurn)
end

druidWindow.autoStep.onClick = function(widget)
  config.autoStep = not config.autoStep
  widget:setChecked(config.autoStep)
end

druidWindow.safePvp.onClick = function(widget)
  config.safePvp = not config.safePvp
  widget:setChecked(config.safePvp)
end

druidWindow.prioritizeMana.onClick = function(widget)
  config.prioritizeMana = not config.prioritizeMana
  widget:setChecked(config.prioritizeMana)
end

druidWindow.closeButton.onClick = function()
  druidWindow:hide()
end

ui.configBtn.onClick = function()
  druidWindow:show()
  druidWindow:raise()
  druidWindow:focus()
end

ui.title:setOn(config.enabled)
ui.title.onClick = function(widget)
  config.enabled = not config.enabled
  widget:setOn(config.enabled)
  updateStatus()
end

updateStatus()

-- =========================================================================
-- ALGORITMOS MATEMÁTICOS DE DAÑO, GEOMETRÍA Y ACOMODAMIENTO
-- =========================================================================

local lastUlusCast = 0
local lastRuneCast = 0
local lastAttack = 0
local lastStepReposition = 0

-- Validar si una criatura es un monstruo atacable (excluye jugadores, familiars, summons aliados)
local function isTargetableCreature(spec)
  if not spec or spec:isLocalPlayer() then return false end
  if spec:isPlayer() then return false end
  if spec:isNpc() then return false end

  local p = spec:getPosition()
  if not p or p.z ~= posz() then return false end
  local hp = spec:getHealthPercent()
  if not hp or hp <= 0 then return false end

  if isIgnoredSummonOrFamiliar and isIgnoredSummonOrFamiliar(spec) then
    return false
  end

  local sName = spec.getName and tostring(spec:getName()):lower():trim() or ""
  if sName:find("familiar") or sName:find("summon") or sName:find("sumon") then
    return false
  end
  if sName == "grovebeast" or sName == "feuerhexe" or sName == "skullfrost" or sName == "phantom" then
    return false
  end

  if spec.getType then
    local st = spec:getType()
    if st == 3 or st == 4 then return false end
  end
  if spec.isSummon and spec:isSummon() then return false end
  if spec.isPet and spec:isPet() then return false end
  if spec.getMaster and spec:getMaster() ~= nil then return false end
  if spec.isPartyMember and spec:isPartyMember() then return false end

  if spec:isMonster() then return true end
  if not spec:isPlayer() and not spec:isNpc() then return true end

  return false
end

-- Calculo matematico de daño esperado por objetivo
local function getBaseDamage(spellType)
  local lvl = player:getLevel() or 500
  local ml = (player.getMagicLevel and player:getMagicLevel()) or 100

  if spellType == "rune" then
    -- Formula estandar de Runa de Area (Thunderstorm, Avalanche, GFB):
    -- Dmg medio = (Level * 0.15) + (MagicLevel * 2.8) + 15
    return math.max(50, math.floor(lvl * 0.15 + ml * 2.8 + 15))
  elseif spellType == "ulus" then
    -- Formula de Spell Ulus de alto impacto:
    -- Multiplicada por el ratio de potencia configurado (ej: 2.2x)
    local ratio = (config.powerRatio or 22) / 10.0
    local runeDmg = lvl * 0.15 + ml * 2.8 + 15
    return math.max(100, math.floor(runeDmg * ratio))
  elseif spellType == "single" then
    -- Formula de Spell Single Strike (exori gran tera):
    return math.max(80, math.floor(lvl * 0.20 + ml * 4.2 + 20))
  end
  return 100
end

-- Comprobar disponibilidad de cooldown para Exevo Ulus Tera
local function isUlusReady()
  local currentNow = now
  local cd = tonumber(config.ulusCooldown) or 4000

  -- 1. Cooldown interno por temporizador
  if lastUlusCast + cd > currentNow then
    local remaining = math.max(0.1, (lastUlusCast + cd - currentNow) / 1000.0)
    return false, remaining
  end

  -- 2. Cooldown via canCast de vlib si esta registrado
  if canCast and not canCast(config.ulusSpell, false, false) then
    return false, 0.5
  end

  -- 3. Cooldown via gamelib cooldown icons
  if modules.game_cooldown and getSpellData then
    local data = getSpellData(config.ulusSpell)
    if data and data.id and modules.game_cooldown.isCooldownIconActive(data.id) then
      return false, 0.5
    end
  end

  return true, 0
end

-- Geometria de la Onda Frontal (Wave) segun direccion (0: Norte, 1: Este, 2: Sur, 3: Oeste)
local function isInsideWave(px, py, dir, mx, my)
  local dx = mx - px
  local dy = my - py

  if dir == 0 then -- Norte (arriba, dy < 0)
    local distY = -dy
    if distY < 1 or distY > 5 then return false end
    if distY <= 2 then
      return math.abs(dx) <= 1
    elseif distY <= 4 then
      return math.abs(dx) <= 2
    else
      return math.abs(dx) <= 1
    end
  elseif dir == 1 then -- Este (derecha, dx > 0)
    local distX = dx
    if distX < 1 or distX > 5 then return false end
    if distX <= 2 then
      return math.abs(dy) <= 1
    elseif distX <= 4 then
      return math.abs(dy) <= 2
    else
      return math.abs(dy) <= 1
    end
  elseif dir == 2 then -- Sur (abajo, dy > 0)
    local distY = dy
    if distY < 1 or distY > 5 then return false end
    if distY <= 2 then
      return math.abs(dx) <= 1
    elseif distY <= 4 then
      return math.abs(dx) <= 2
    else
      return math.abs(dx) <= 1
    end
  elseif dir == 3 then -- Oeste (izquierda, dx < 0)
    local distX = -dx
    if distX < 1 or distX > 5 then return false end
    if distX <= 2 then
      return math.abs(dy) <= 1
    elseif distX <= 4 then
      return math.abs(dy) <= 2
    else
      return math.abs(dy) <= 1
    end
  end
  return false
end

-- Geometria de Area 360° (centrada en el jugador)
local function isInsideArea360(px, py, mx, my, radius)
  radius = radius or 4
  local dx = math.abs(mx - px)
  local dy = math.abs(my - py)
  return (dx <= radius and dy <= radius) and (dx + dy <= radius + 2)
end

-- Evaluar direccion optima para Onda Frontal (Wave) y calcular monstruos alcanzados
local function evaluateWaveDirection(playerPos, aliveMonsters, allSpecs)
  local px, py, pz = playerPos.x, playerPos.y, playerPos.z
  local currentDir = player:getDirection()
  local bestDir = currentDir
  local maxHits = 0
  local dirHits = { [0] = 0, [1] = 0, [2] = 0, [3] = 0 }

  for dir = 0, 3 do
    local blockedBySafe = false
    if config.safePvp then
      for _, spec in ipairs(allSpecs) do
        if not spec:isLocalPlayer() and spec:getPosition().z == pz then
          local sp = spec:getPosition()
          if isInsideWave(px, py, dir, sp.x, sp.y) then
            if not isTargetableCreature(spec) then
              blockedBySafe = true
              break
            end
          end
        end
      end
    end

    if not blockedBySafe then
      local count = 0
      for _, m in ipairs(aliveMonsters) do
        local mp = m:getPosition()
        if isInsideWave(px, py, dir, mp.x, mp.y) then
          count = count + 1
        end
      end
      dirHits[dir] = count
      if count > maxHits or (count == maxHits and dir == currentDir) then
        maxHits = count
        bestDir = dir
      end
    end
  end

  return bestDir, maxHits, dirHits
end

-- Evaluar Area 360° para Ulus
local function evaluateArea360(playerPos, aliveMonsters, allSpecs)
  local px, py, pz = playerPos.x, playerPos.y, playerPos.z

  if config.safePvp then
    for _, spec in ipairs(allSpecs) do
      if not spec:isLocalPlayer() and spec:getPosition().z == pz then
        local sp = spec:getPosition()
        if isInsideArea360(px, py, sp.x, sp.y, 4) then
          if not isTargetableCreature(spec) then
            return 0 -- Bloqueado por PVP
          end
        end
      end
    end
  end

  local count = 0
  for _, m in ipairs(aliveMonsters) do
    local mp = m:getPosition()
    if isInsideArea360(px, py, mp.x, mp.y, 4) then
      count = count + 1
    end
  end

  return count
end

-- Geometria de la Runa de Area (37 SQMs - Thunderstorm / Avalanche / GFB)
local function isBlastHit(cx, cy, mx, my)
  local dx = math.abs(mx - cx)
  local dy = math.abs(my - cy)
  return (dx <= 3 and dy <= 3) and (dx + dy <= 4 or (dx <= 2 and dy <= 2))
end

-- Optimizar el centro de la runa de area para golpear al maximo numero de monstruos
local function getBestRuneBlastTarget(playerPos, aliveMonsters, currentTarget, allSpecs)
  local pz = playerPos.z
  local candidatePositions = {}
  local visited = {}

  local function addCandidate(p, creature)
    if not p then return end
    local key = p.x .. "," .. p.y
    if not visited[key] then
      visited[key] = true
      table.insert(candidatePositions, { pos = p, creature = creature })
    end
  end

  if currentTarget and currentTarget:getPosition().z == pz then
    addCandidate(currentTarget:getPosition(), currentTarget)
  end

  for i = 1, #aliveMonsters do
    local m = aliveMonsters[i]
    addCandidate(m:getPosition(), m)
  end

  -- Puntos medios entre pares de monstruos
  for i = 1, #aliveMonsters do
    local p1 = aliveMonsters[i]:getPosition()
    for j = i + 1, #aliveMonsters do
      local p2 = aliveMonsters[j]:getPosition()
      local dist = math.max(math.abs(p1.x - p2.x), math.abs(p1.y - p2.y))
      if dist <= 6 then
        local midX = math.floor((p1.x + p2.x) / 2)
        local midY = math.floor((p1.y + p2.y) / 2)
        addCandidate({ x = midX, y = midY, z = pz }, nil)
        local cX = math.ceil((p1.x + p2.x) / 2)
        local cY = math.ceil((p1.y + p2.y) / 2)
        if cX ~= midX or cY ~= midY then
          addCandidate({ x = cX, y = cY, z = pz }, nil)
        end
      end
    end
  end

  local bestScore = -1
  local bestPos = nil
  local bestCreature = nil

  for _, cand in ipairs(candidatePositions) do
    local cp = cand.pos
    local distFromPlayer = getDistanceBetween(playerPos, cp)
    if distFromPlayer <= 6 then
      local tile = g_map.getTile(cp)
      if tile and tile:canShoot() then
        local pvpBlocked = false
        if config.safePvp then
          for _, spec in ipairs(allSpecs) do
            if not spec:isLocalPlayer() and spec:getPosition().z == pz then
              local sp = spec:getPosition()
              if isBlastHit(cp.x, cp.y, sp.x, sp.y) then
                if not isTargetableCreature(spec) then
                  pvpBlocked = true
                  break
                end
              end
            end
          end
        end

        if not pvpBlocked then
          local hits = 0
          for _, m in ipairs(aliveMonsters) do
            local mp = m:getPosition()
            if isBlastHit(cp.x, cp.y, mp.x, mp.y) then
              hits = hits + 1
            end
          end

          local isCurTarget = currentTarget and (cp.x == currentTarget:getPosition().x and cp.y == currentTarget:getPosition().y)
          if hits > bestScore or (hits == bestScore and isCurTarget) then
            bestScore = hits
            bestPos = cp
            bestCreature = cand.creature
          end
        end
      end
    end
  end

  return bestPos, bestCreature, bestScore
end

-- Disparo fiable de Runa
local function shootRune(runeId, targetThing)
  if not runeId or runeId <= 0 or not targetThing then return false end
  local altId = runeAltIds[runeId]
  local subType = (g_game.getClientVersion and g_game.getClientVersion() >= 860) and 0 or 1
  local ok = false

  pcall(function()
    g_game.useInventoryItemWith(runeId, targetThing, subType)
    ok = true
  end)

  if not ok and altId then
    pcall(function()
      g_game.useInventoryItemWith(altId, targetThing, subType)
      ok = true
    end)
  end

  if not ok then
    local it = findItem(runeId) or (altId and findItem(altId))
    if it then
      pcall(function()
        g_game.useWith(it, targetThing, subType)
        ok = true
      end)
    end
  end

  return ok
end

-- Direcciones legibles
local dirNames = { [0] = "North", [1] = "East", [2] = "South", [3] = "West" }

-- =========================================================================
-- MOTOR PRINCIPAL DE TARGETING Y DECISIÓN DE DAÑO (HIGH DPS)
-- =========================================================================

-- Macro rápido de auto-target (50ms)
macro(50, function()
  if not config.enabled then return end
  if isInPz() then return end
  if not config.autoTarget then return end

  local pPos = pos()
  local pz = pPos.z
  local currentTarget = g_game.getAttackingCreature()

  if currentTarget then
    local tPos = currentTarget:getPosition()
    if not tPos or tPos.z ~= pz or currentTarget:getHealthPercent() <= 0 or not isTargetableCreature(currentTarget) then
      if not isTargetableCreature(currentTarget) then
        g_game.cancelAttackAndFollow()
      end
      currentTarget = nil
    end
  end

  if not currentTarget then
    local closestDist = 999
    local closestCreature = nil
    for _, spec in ipairs(getSpectators()) do
      if isTargetableCreature(spec) then
        local dist = getDistanceBetween(pPos, spec:getPosition())
        if dist < closestDist and dist <= 7 then
          closestDist = dist
          closestCreature = spec
        end
      end
    end
    if closestCreature then
      g_game.attack(closestCreature)
    end
  end
end)

-- Macro de decisión matemática de daño y ataque (20ms)
macro(20, function()
  if not config.enabled then return end
  if isInPz() then return end

  -- Priorizar tener >20% de mana antes de gastar en ataques masivos
  if config.prioritizeMana and (manapercent() or 100) <= 20 then
    updateStatus("[MANA BAJA] Priorizando curacion (>20% MP)")
    return
  end

  local currentNow = now
  local delayMs = tonumber(config.delay) or 201
  if lastAttack + delayMs > currentNow then return end

  local playerPos = pos()
  local pz = playerPos.z
  local allSpecs = getSpectators()

  -- Recopilar monstruos vivos en rango
  local aliveMonsters = {}
  for _, spec in ipairs(allSpecs) do
    if isTargetableCreature(spec) then
      local dist = getDistanceBetween(playerPos, spec:getPosition())
      if dist <= 7 then
        table.insert(aliveMonsters, spec)
      end
    end
  end

  if #aliveMonsters == 0 then
    updateStatus("[WAITING] Sin monstruos en rango")
    return
  end

  local currentTarget = g_game.getAttackingCreature()
  if currentTarget and not isTargetableCreature(currentTarget) then
    g_game.cancelAttackAndFollow()
    currentTarget = nil
  end
  if not currentTarget and #aliveMonsters > 0 then
    currentTarget = aliveMonsters[1]
    g_game.attack(currentTarget)
  end

  -- 1. Calcular Daño Esperado de Runa de Area (Thunderlord / Thunderstorm)
  local baseRuneDmg = getBaseDamage("rune")
  local bestRunePos, bestRuneCreature, runeHits = getBestRuneBlastTarget(playerPos, aliveMonsters, currentTarget, allSpecs)
  runeHits = math.max(0, runeHits or 0)
  local totalRuneDmg = runeHits * baseRuneDmg

  -- 2. Calcular Daño Esperado de Exevo Ulus Tera
  local ulusReady, remainingCd = isUlusReady()
  local baseUlusDmg = getBaseDamage("ulus")
  local bestWaveDir = player:getDirection()
  local waveHits = 0
  local areaHits = 0
  local bestUlusHits = 0
  local useWaveMode = (config.ulusShape == 1)

  if ulusReady then
    if config.ulusShape == 1 then -- Onda Frontal (Wave)
      bestWaveDir, waveHits = evaluateWaveDirection(playerPos, aliveMonsters, allSpecs)
      bestUlusHits = waveHits
    elseif config.ulusShape == 2 then -- Area 360
      areaHits = evaluateArea360(playerPos, aliveMonsters, allSpecs)
      bestUlusHits = areaHits
      useWaveMode = false
    else -- Auto (compara wave vs area)
      bestWaveDir, waveHits = evaluateWaveDirection(playerPos, aliveMonsters, allSpecs)
      areaHits = evaluateArea360(playerPos, aliveMonsters, allSpecs)
      if waveHits >= areaHits then
        bestUlusHits = waveHits
        useWaveMode = true
      else
        bestUlusHits = areaHits
        useWaveMode = false
      end
    end
  end

  local totalUlusDmg = (ulusReady and bestUlusHits > 0) and (bestUlusHits * baseUlusDmg) or 0

  -- 3. Acomodar paso de 1 SQM (Reposition) si se gana ventaja significativa
  if config.autoStep and ulusReady and bestUlusHits <= 1 and (lastStepReposition + 1000 < currentNow) and not player:isWalking() then
    local stepOffsets = { {x=0, y=-1}, {x=1, y=0}, {x=0, y=1}, {x=-1, y=0} }
    for _, off in ipairs(stepOffsets) do
      local testPos = { x = playerPos.x + off.x, y = playerPos.y + off.y, z = pz }
      local tile = g_map.getTile(testPos)
      if tile and tile:isWalkable() and not tile:hasCreature() then
        local _, tHits = evaluateWaveDirection(testPos, aliveMonsters, allSpecs)
        if tHits >= bestUlusHits + 2 then
          autoWalk(testPos, 1, { ignoreCreatures = false })
          lastStepReposition = currentNow
          return
        end
      end
    end
  end

  -- 4. COMPARACIÓN MATEMÁTICA Y EJECUCIÓN (Máximo DPS)
  -- Si Ulus está disponible y su daño total supera o iguala a la runa grupal:
  if ulusReady and bestUlusHits >= 1 and totalUlusDmg >= totalRuneDmg then
    -- ACOMODAR: Girar el personaje hacia la mejor direccion antes de tirar la onda
    if useWaveMode and config.autoTurn then
      if player:getDirection() ~= bestWaveDir then
        turn(bestWaveDir)
      end
    end

    say(config.ulusSpell)
    lastUlusCast = currentNow
    lastAttack = currentNow

    local statusMsg = string.format("[DPS: ULUS] %dm (~%d dmg) >= Thunder %dm (~%d) | Dir: %s",
      bestUlusHits, totalUlusDmg, runeHits, totalRuneDmg, dirNames[bestWaveDir] or "?")
    updateStatus(statusMsg)

    if logCaveBot then
      logCaveBot("DRUID TARGETING", statusMsg)
    end
    return
  end

  -- Si la Runa de Area (Thunderlord / Thunderstorm) hace mas daño O si Ulus esta en cooldown:
  if runeHits >= 2 and totalRuneDmg > 0 and bestRunePos then
    local targetThing = bestRuneCreature
    if not targetThing then
      local tile = g_map.getTile(bestRunePos)
      if tile then
        targetThing = tile:getTopUseThing() or tile:getGround() or tile
      end
    end

    if targetThing then
      shootRune(config.areaRuneId, targetThing)
      lastRuneCast = currentNow
      lastAttack = currentNow

      local cdText = ulusReady and "" or string.format(" [Ulus CD: %.1fs]", remainingCd or 0)
      local statusMsg = string.format("[DPS: THUNDER] %dm (~%d dmg) > Ulus %dm (~%d)%s",
        runeHits, totalRuneDmg, bestUlusHits, totalUlusDmg, cdText)
      updateStatus(statusMsg)

      if logCaveBot and runeHits >= 3 then
        logCaveBot("DRUID TARGETING", statusMsg)
      end
      return
    end
  end

  -- Caso Remate / Single Target (1 solo monstruo o sin agrupacion favorable para area)
  local singleTarget = currentTarget or aliveMonsters[1]
  if singleTarget and isTargetableCreature(singleTarget) then
    local tPos = singleTarget:getPosition()
    if tPos and tPos.z == pz then
      local dist = getDistanceBetween(playerPos, tPos)
      if dist <= 5 then
        if config.singleSpell and config.singleSpell:len() > 0 then
          say(config.singleSpell)
          lastAttack = currentNow
          updateStatus(string.format("[SINGLE: %s] Target: %s", config.singleSpell, singleTarget:getName()))
          return
        else
          shootRune(3155, singleTarget) -- SD fallback
          lastAttack = currentNow
          updateStatus(string.format("[SINGLE: SD] Target: %s", singleTarget:getName()))
          return
        end
      end
    end
  end
end)
