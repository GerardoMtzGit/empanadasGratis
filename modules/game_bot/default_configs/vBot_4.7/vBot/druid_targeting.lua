local targetingTab = storage.extras and storage.extras.joinBot and "Cave" or "Target"
setDefaultTab(targetingTab)

local panelName = "druid_targeting"

if not storage[panelName] then
  storage[panelName] = {
    enabled = false,
    ulusSpell = "exevo ulus tera",
    ulusCooldown = 4000,   -- Cooldown en ms
    useFrigoHur = true,
    frigoSpell = "exevo gran frigo hur",
    frigoCooldown = 8000,  -- Cooldown en ms
    useTeraHur = true,
    teraSpell = "exevo tera hur",
    teraCooldown = 4000,   -- Cooldown en ms
    areaRuneId = 3202,     -- Thunderstorm / Thunderlord
    singleSpell = "exori gran tera",
    powerRatio = 23,       -- 2.3x ratio de potencia Ulus vs Runa
    delay = 201,           -- 201 ms delay entre ataques
    autoTurn = true,       -- Auto-girar en waves hacia donde haga mas daño
    safePvp = true,        -- No dañar jugadores ni aliados
    prioritizeMana = true, -- Reservar >20% de mana para curarse
    autoTarget = true      -- Atacar al mas cercano si no hay target
  }
end

local config = storage[panelName]

-- Validaciones de configuracion
if not config.ulusSpell or config.ulusSpell == "" then config.ulusSpell = "exevo ulus tera" end
if not config.ulusCooldown or config.ulusCooldown <= 0 then config.ulusCooldown = 4000 end
if config.useFrigoHur == nil then config.useFrigoHur = true end
if not config.frigoSpell or config.frigoSpell == "" then config.frigoSpell = "exevo gran frigo hur" end
if not config.frigoCooldown or config.frigoCooldown <= 0 then config.frigoCooldown = 8000 end
if config.useTeraHur == nil then config.useTeraHur = true end
if not config.teraSpell or config.teraSpell == "" then config.teraSpell = "exevo tera hur" end
if not config.teraCooldown or config.teraCooldown <= 0 then config.teraCooldown = 4000 end
if not config.areaRuneId or config.areaRuneId <= 0 then config.areaRuneId = 3202 end
if not config.singleSpell or config.singleSpell == "" then config.singleSpell = "exori gran tera" end
if not config.powerRatio then config.powerRatio = 23 end
if not config.delay or config.delay <= 0 then config.delay = 201 end
if config.autoTurn == nil then config.autoTurn = true end
if config.safePvp == nil then config.safePvp = true end
if config.prioritizeMana == nil then config.prioritizeMana = true end
if config.autoTarget == nil then config.autoTarget = true end

-- Helper de tiempo a prueba de fallos
local function getNow()
  return now or (g_clock and g_clock.millis and g_clock.millis()) or (os.time() * 1000)
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

-- Actualizacion con throttling para prevenir freezes de interfaz
local lastStatusText = ""
local lastStatusTime = 0
local function updateStatus(customText)
  local nowMs = getNow()
  if customText then
    if customText == lastStatusText and (lastStatusTime + 300 > nowMs) then
      return
    end
    lastStatusText = customText
    lastStatusTime = nowMs
    pcall(function()
      ui.status:setText(customText)
      ui.status:setColor(config.enabled and "#55ff55" or "#a0a0a0")
    end)
    return
  end

  local onText = config.enabled and "[ON]" or "[OFF]"
  local ratioText = string.format("%.1fx", (config.powerRatio or 23) / 10.0)
  local defText = string.format("%s Druid High DPS | Ulus / %s", onText, getRuneName(config.areaRuneId))
  lastStatusText = defText
  lastStatusTime = nowMs
  pcall(function()
    ui.status:setText(defText)
    ui.status:setColor(config.enabled and "#55ff55" or "#a0a0a0")
  end)
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
druidWindow.ulusSpell:setText(config.ulusSpell or "exevo ulus tera")
druidWindow.ulusCooldown:setText(tostring(config.ulusCooldown or 4000))

druidWindow.useFrigoHur:setChecked(config.useFrigoHur)
druidWindow.frigoSpell:setText(config.frigoSpell or "exevo gran frigo hur")
druidWindow.frigoCooldown:setText(tostring(config.frigoCooldown or 8000))

druidWindow.useTeraHur:setChecked(config.useTeraHur)
druidWindow.teraSpell:setText(config.teraSpell or "exevo tera hur")
druidWindow.teraCooldown:setText(tostring(config.teraCooldown or 4000))

druidWindow.areaRuneCombo:setCurrentOptionByData(config.areaRuneId or 3202)
druidWindow.singleSpell:setText(config.singleSpell or "exori gran tera")
druidWindow.powerRatio:setValue(config.powerRatio or 23)
druidWindow.ratioLabel:setText(string.format("Multiplicador Dano Ulus vs Runa: %.1fx", (config.powerRatio or 23) / 10.0))

druidWindow.delay:setValue(config.delay or 201)
druidWindow.delayLabel:setText(string.format("Delay entre ataques: %d ms", config.delay or 201))

druidWindow.autoTurn:setChecked(config.autoTurn)
druidWindow.safePvp:setChecked(config.safePvp)
druidWindow.prioritizeMana:setChecked(config.prioritizeMana)

-- Callbacks de UI
druidWindow.ulusSpell.onTextChange = function(widget, text)
  config.ulusSpell = text:trim()
end

druidWindow.ulusCooldown.onTextChange = function(widget, text)
  local val = tonumber(text:trim())
  if val and val > 0 then
    config.ulusCooldown = val
  end
end

druidWindow.useFrigoHur.onClick = function(widget)
  config.useFrigoHur = not config.useFrigoHur
  widget:setChecked(config.useFrigoHur)
end

druidWindow.frigoSpell.onTextChange = function(widget, text)
  config.frigoSpell = text:trim()
end

druidWindow.frigoCooldown.onTextChange = function(widget, text)
  local val = tonumber(text:trim())
  if val and val > 0 then
    config.frigoCooldown = val
  end
end

druidWindow.useTeraHur.onClick = function(widget)
  config.useTeraHur = not config.useTeraHur
  widget:setChecked(config.useTeraHur)
end

druidWindow.teraSpell.onTextChange = function(widget, text)
  config.teraSpell = text:trim()
end

druidWindow.teraCooldown.onTextChange = function(widget, text)
  local val = tonumber(text:trim())
  if val and val > 0 then
    config.teraCooldown = val
  end
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
  druidWindow.ratioLabel:setText(string.format("Multiplicador Dano Ulus vs Runa: %.1fx", value / 10.0))
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
-- ALGORITMOS MATEMÁTICOS DE DAÑO, GEOMETRÍA Y COOLDOWNS
-- =========================================================================

local lastUlusCast = 0
local lastFrigoCast = 0
local lastTeraCast = 0
local lastRuneCast = 0
local lastAttack = 0
local lastAutoTargetTime = 0

-- Escuchar chat para actualizar cooldowns si se tiran manualmente o por hotkeys
onTalk(function(name, level, mode, text, channelId, pos)
  if not g_game.isOnline() or not player then return end
  local pName = player.getName and player:getName()
  if not pName or name ~= pName then return end

  local phrase = text:lower():trim()
  local currentNow = getNow()

  if config.ulusSpell and phrase == config.ulusSpell:lower():trim() then
    lastUlusCast = currentNow
  elseif config.frigoSpell and phrase == config.frigoSpell:lower():trim() then
    lastFrigoCast = currentNow
  elseif config.teraSpell and phrase == config.teraSpell:lower():trim() then
    lastTeraCast = currentNow
  end
end)

-- Validar si una criatura es un monstruo atacable (excluye jugadores, familiars, summons aliados)
local function isTargetableCreature(spec)
  if not spec then return false end
  local isLocal = false
  pcall(function() isLocal = spec:isLocalPlayer() end)
  if isLocal then return false end

  local isP = false
  pcall(function() isP = spec:isPlayer() end)
  if isP then return false end

  local isN = false
  pcall(function() isN = spec:isNpc() end)
  if isN then return false end

  local p = spec.getPosition and spec:getPosition()
  if not p or p.z ~= posz() then return false end

  local hp = spec.getHealthPercent and spec:getHealthPercent()
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

  if spec.isMonster and spec:isMonster() then return true end
  return true
end

-- Calculo matematico de daño base esperado por objetivo
local function getBaseDamage(spellType)
  if not player then return 100 end
  local lvl = (player.getLevel and player:getLevel()) or 500
  local ml = (player.getMagicLevel and player:getMagicLevel()) or 100

  -- Formula estandar de Runa de Area (Thunderstorm, Avalanche, GFB):
  local runeBase = math.max(50, math.floor(lvl * 0.15 + ml * 2.8 + 15))

  if spellType == "rune" then
    return runeBase
  elseif spellType == "ulus" then
    local ratio = (config.powerRatio or 23) / 10.0
    return math.max(100, math.floor(runeBase * ratio))
  elseif spellType == "frigo" then
    return math.max(90, math.floor(runeBase * 1.9))
  elseif spellType == "tera" then
    return math.max(80, math.floor(runeBase * 1.6))
  elseif spellType == "single" then
    return math.max(80, math.floor(lvl * 0.20 + ml * 4.2 + 20))
  end
  return runeBase
end

-- Comprobar si una spell especifica esta disponible (cooldown transcurrido)
local function isSpellReady(spellKey, cdMs)
  local currentNow = getNow()
  local lastCast = 0
  local words = ""

  if spellKey == "ulus" then
    lastCast = lastUlusCast
    words = config.ulusSpell
  elseif spellKey == "frigo" then
    lastCast = lastFrigoCast
    words = config.frigoSpell
  elseif spellKey == "tera" then
    lastCast = lastTeraCast
    words = config.teraSpell
  end

  -- 1. Cooldown interno
  if lastCast + cdMs > currentNow then
    local remaining = math.max(0.1, (lastCast + cdMs - currentNow) / 1000.0)
    return false, remaining
  end

  -- 2. canCast de vlib si esta registrado
  if canCast and words ~= "" and not canCast(words, false, false) then
    return false, 0.5
  end

  -- 3. Icono de cooldown en gamelib si existe
  if modules.game_cooldown and getSpellData and words ~= "" then
    local data = getSpellData(words)
    if data and data.id and modules.game_cooldown.isCooldownIconActive(data.id) then
      return false, 0.5
    end
  end

  return true, 0
end

-- =========================================================================
-- GEOMETRÍA EXACTA DE SPELLS Y ÁREAS
-- =========================================================================

-- 1. EXEVO ULUS TERA: Donut AoE (Area Grande de Radio 6 con centro vacio de 3x3)
-- "como puedes ver no pega en los 8 sqms pegados al personaje ten en cuenta esto para el calculo"
local function isInsideUlusDonut(px, py, mx, my)
  if not mx or not my then return false end
  local dx = mx - px
  local dy = my - py
  local absX = math.abs(dx)
  local absY = math.abs(dy)

  -- EL CENTRO VACÍO: Los 8 SQMs pegados al personaje y la casilla del personaje NO reciben daño
  if absX <= 1 and absY <= 1 then
    return false
  end

  -- CÍRCULO EXTERIOR: Area Grande de 13x13 (Radio 6 exacto)
  if absY == 0 then return absX <= 6
  elseif absY == 1 then return absX <= 5
  elseif absY == 2 then return absX <= 4
  elseif absY == 3 then return absX <= 3
  elseif absY == 4 then return absX <= 2
  elseif absY == 5 then return absX <= 1
  elseif absY == 6 then return absX == 0
  end

  return false
end

-- 2. EXEVO GRAN FRIGO HUR: Cono de Onda de Hielo (Small Wave 7 SQMs)
local function isInsideGranFrigoHur(px, py, dir, mx, my)
  if not mx or not my then return false end
  local dx = mx - px
  local dy = my - py

  if dir == 0 then -- Norte (dy < 0)
    if dx == 0 and dy == -1 then return true end
    if (dy == -2 or dy == -3) and math.abs(dx) <= 1 then return true end
  elseif dir == 1 then -- Este (dx > 0)
    if dy == 0 and dx == 1 then return true end
    if (dx == 2 or dx == 3) and math.abs(dy) <= 1 then return true end
  elseif dir == 2 then -- Sur (dy > 0)
    if dx == 0 and dy == 1 then return true end
    if (dy == 2 or dy == 3) and math.abs(dx) <= 1 then return true end
  elseif dir == 3 then -- Oeste (dx < 0)
    if dy == 0 and dx == -1 then return true end
    if (dx == -2 or dx == -3) and math.abs(dy) <= 1 then return true end
  end
  return false
end

-- 3. EXEVO TERA HUR: Onda de Tierra (3x3 Wave / Haz de 5 SQMs, 11 SQMs)
local function isInsideTeraHur(px, py, dir, mx, my)
  if not mx or not my then return false end
  local dx = mx - px
  local dy = my - py

  if dir == 0 then -- Norte (dy < 0)
    if dx == 0 and (dy == -1 or dy == -2) then return true end
    if (dy >= -5 and dy <= -3) and math.abs(dx) <= 1 then return true end
  elseif dir == 1 then -- Este (dx > 0)
    if dy == 0 and (dx == 1 or dx == 2) then return true end
    if (dx >= 3 and dx <= 5) and math.abs(dy) <= 1 then return true end
  elseif dir == 2 then -- Sur (dy > 0)
    if dx == 0 and (dy == 1 or dy == 2) then return true end
    if (dy >= 3 and dy <= 5) and math.abs(dy) <= 1 then return true end
  elseif dir == 3 then -- Oeste (dx < 0)
    if dy == 0 and (dx == -1 or dx == -2) then return true end
    if (dx >= -5 and dx <= -3) and math.abs(dy) <= 1 then return true end
  end
  return false
end

-- 4. RUNA DE ÁREA BASE (37 SQMs - Thunderlord / Thunderstorm / Avalanche / GFB)
local function isBlastHit(cx, cy, mx, my)
  if not mx or not my then return false end
  local dx = math.abs(mx - cx)
  local dy = math.abs(my - cy)
  return (dx <= 3 and dy <= 3) and (dx + dy <= 4 or (dx <= 2 and dy <= 2))
end

-- =========================================================================
-- EVALUADORES DE OBJETIVOS CON PROTECCIÓN PVP
-- =========================================================================

-- Evaluar monstruos alcanzados por Exevo Ulus Tera (Donut)
local function evaluateUlusDonut(playerPos, aliveMonsters, innocentPlayers)
  local px, py = playerPos.x, playerPos.y

  if config.safePvp then
    for _, inno in ipairs(innocentPlayers) do
      if isInsideUlusDonut(px, py, inno.pos.x, inno.pos.y) then
        return 0 -- Bloqueado para evitar skull / dañar aliados
      end
    end
  end

  local count = 0
  for _, m in ipairs(aliveMonsters) do
    if isInsideUlusDonut(px, py, m.pos.x, m.pos.y) then
      count = count + 1
    end
  end

  return count
end

-- Evaluar mejor direccion para Exevo Gran Frigo Hur
local function evaluateGranFrigoHur(playerPos, aliveMonsters, innocentPlayers)
  local px, py = playerPos.x, playerPos.y
  local currentDir = (player and player.getDirection and player:getDirection()) or 0
  local bestDir = currentDir
  local maxHits = 0

  for dir = 0, 3 do
    local blocked = false
    if config.safePvp then
      for _, inno in ipairs(innocentPlayers) do
        if isInsideGranFrigoHur(px, py, dir, inno.pos.x, inno.pos.y) then
          blocked = true
          break
        end
      end
    end

    if not blocked then
      local count = 0
      for _, m in ipairs(aliveMonsters) do
        if isInsideGranFrigoHur(px, py, dir, m.pos.x, m.pos.y) then
          count = count + 1
        end
      end

      if count > maxHits or (count == maxHits and dir == currentDir) then
        maxHits = count
        bestDir = dir
      end
    end
  end

  return bestDir, maxHits
end

-- Evaluar mejor direccion para Exevo Tera Hur
local function evaluateTeraHur(playerPos, aliveMonsters, innocentPlayers)
  local px, py = playerPos.x, playerPos.y
  local currentDir = (player and player.getDirection and player:getDirection()) or 0
  local bestDir = currentDir
  local maxHits = 0

  for dir = 0, 3 do
    local blocked = false
    if config.safePvp then
      for _, inno in ipairs(innocentPlayers) do
        if isInsideTeraHur(px, py, dir, inno.pos.x, inno.pos.y) then
          blocked = true
          break
        end
      end
    end

    if not blocked then
      local count = 0
      for _, m in ipairs(aliveMonsters) do
        if isInsideTeraHur(px, py, dir, m.pos.x, m.pos.y) then
          count = count + 1
        end
      end

      if count > maxHits or (count == maxHits and dir == currentDir) then
        maxHits = count
        bestDir = dir
      end
    end
  end

  return bestDir, maxHits
end

-- Optimizar el disparo de la Runa de Área al cluster con mas monstruos (rapido y seguro)
local function getBestRuneBlastTarget(playerPos, aliveMonsters, currentTarget, innocentPlayers)
  local pz = playerPos.z

  -- OPTIMIZACION CRITICA: Cuando el jugador esta trapeado/boxeado (>= 3 monstruos cuerpo a cuerpo)
  -- Disparar la runa de area en el propio jugador golpea a todos los monstruos adyacentes (360°)
  -- y evita el costo de generar pares y evaluar decenas de combinaciones.
  local adjacentCount = 0
  for _, m in ipairs(aliveMonsters) do
    if getDistanceBetween(playerPos, m.pos) <= 1 then
      adjacentCount = adjacentCount + 1
    end
  end

  if adjacentCount >= 3 then
    local pvpBlocked = false
    if config.safePvp then
      for _, inno in ipairs(innocentPlayers) do
        if isBlastHit(playerPos.x, playerPos.y, inno.pos.x, inno.pos.y) then
          pvpBlocked = true
          break
        end
      end
    end

    if not pvpBlocked then
      local hits = 0
      for _, m in ipairs(aliveMonsters) do
        if isBlastHit(playerPos.x, playerPos.y, m.pos.x, m.pos.y) then
          hits = hits + 1
        end
      end

      local bestCreature = nil
      if currentTarget then
        local tp = currentTarget.getPosition and currentTarget:getPosition()
        if tp and tp.z == pz and getDistanceBetween(playerPos, tp) <= 1 then
          bestCreature = currentTarget
        end
      end
      return playerPos, bestCreature, hits
    end
  end

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

  if currentTarget then
    local tp = currentTarget.getPosition and currentTarget:getPosition()
    if tp and tp.z == pz then
      addCandidate(tp, currentTarget)
    end
  end

  -- Añadir cada posicion de monstruo como centro potencial
  for i = 1, #aliveMonsters do
    addCandidate(aliveMonsters[i].pos, aliveMonsters[i].creature)
  end

  -- Puntos medios entre pares de monstruos (hasta max 15 pares para mantener 0 lag)
  local pairCount = 0
  for i = 1, #aliveMonsters do
    if pairCount >= 15 then break end
    local p1 = aliveMonsters[i].pos
    for j = i + 1, #aliveMonsters do
      if pairCount >= 15 then break end
      local p2 = aliveMonsters[j].pos
      local dist = math.max(math.abs(p1.x - p2.x), math.abs(p1.y - p2.y))
      if dist <= 5 then
        local midX = math.floor((p1.x + p2.x) / 2)
        local midY = math.floor((p1.y + p2.y) / 2)
        addCandidate({ x = midX, y = midY, z = pz }, nil)
        pairCount = pairCount + 1
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
          for _, inno in ipairs(innocentPlayers) do
            if isBlastHit(cp.x, cp.y, inno.pos.x, inno.pos.y) then
              pvpBlocked = true
              break
            end
          end
        end

        if not pvpBlocked then
          local hits = 0
          for _, m in ipairs(aliveMonsters) do
            if isBlastHit(cp.x, cp.y, m.pos.x, m.pos.y) then
              hits = hits + 1
            end
          end

          local isCurTarget = currentTarget and cand.creature and (cand.creature == currentTarget)
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

local dirNames = { [0] = "North", [1] = "East", [2] = "South", [3] = "West" }

-- =========================================================================
-- MOTOR PRINCIPAL: DECISIÓN MATEMÁTICA DE ALTO DPS
-- "en teoria es siempre tira la runa hasta que alguna spell que haga mas daño
-- este disponible y solo si de verdad hara mas daño"
-- =========================================================================

-- Macro principal de ataque y decisión de máximo daño (100ms)
macro(100, function()
  if not config.enabled then return end
  if not g_game.isOnline() or not player or isInPz() then return end

  local currentNow = getNow()
  local delayMs = tonumber(config.delay) or 201

  -- Cooldown de ataque respetado antes de hacer cualquier cálculo
  if lastAttack + delayMs > currentNow then return end

  -- Priorizar tener >20% de mana antes de gastar en ataques masivos
  if config.prioritizeMana and (manapercent() or 100) <= 20 then
    updateStatus("[MANA BAJA] Priorizando curacion (>20% MP)")
    lastAttack = currentNow - delayMs + 200
    return
  end

  local playerPos = pos()
  if not playerPos then return end
  local pz = playerPos.z
  local allSpecs = getSpectators()

  -- Clasificar espectadores EN UN SOLO PASE limpio
  local aliveMonsters = {}
  local innocentPlayers = {}

  for _, spec in ipairs(allSpecs) do
    local sp = spec and spec.getPosition and spec:getPosition()
    if sp and sp.z == pz then
      if isTargetableCreature(spec) then
        local dist = getDistanceBetween(playerPos, sp)
        if dist <= 7 then
          table.insert(aliveMonsters, { creature = spec, pos = sp })
        end
      else
        local isLocal = false
        pcall(function() isLocal = spec:isLocalPlayer() end)
        if not isLocal then
          table.insert(innocentPlayers, { creature = spec, pos = sp })
        end
      end
    end
  end

  if #aliveMonsters == 0 then
    updateStatus("[WAITING] Sin monstruos en rango")
    lastAttack = currentNow - delayMs + 200
    return
  end

  local currentTarget = g_game.getAttackingCreature()
  if currentTarget and not isTargetableCreature(currentTarget) then
    g_game.cancelAttackAndFollow()
    currentTarget = nil
  end
  if config.autoTarget and not currentTarget and #aliveMonsters > 0 then
    currentTarget = aliveMonsters[1].creature
    g_game.attack(currentTarget)
  end

  -- =======================================================================
  -- 1. BASELINE: CALCULAR DAÑO TOTAL DE LA RUNA DE ÁREA
  -- =======================================================================
  local baseRuneDmg = getBaseDamage("rune")
  local bestRunePos, bestRuneCreature, runeHits = getBestRuneBlastTarget(playerPos, aliveMonsters, currentTarget, innocentPlayers)
  runeHits = math.max(0, runeHits or 0)
  local totalRuneDmg = runeHits * baseRuneDmg

  -- =======================================================================
  -- 2. EVALUAR SPELLS DISPONIBLES (OFF COOLDOWN) Y SUS DAÑOS TOTALES
  -- =======================================================================

  -- 2a. Exevo Ulus Tera (Donut: Vacio en los 8 SQMs pegados al jugador)
  local ulusReady, ulusCdRemain = isSpellReady("ulus", config.ulusCooldown or 4000)
  local baseUlusDmg = getBaseDamage("ulus")
  local ulusHits = 0
  local totalUlusDmg = 0

  if ulusReady then
    ulusHits = evaluateUlusDonut(playerPos, aliveMonsters, innocentPlayers)
    totalUlusDmg = ulusHits * baseUlusDmg
  end

  -- 2b. Exevo Gran Frigo Hur (Strong Ice Wave)
  local frigoReady, frigoCdRemain = isSpellReady("frigo", config.frigoCooldown or 8000)
  local baseFrigoDmg = getBaseDamage("frigo")
  local frigoHits = 0
  local bestFrigoDir = (player and player.getDirection and player:getDirection()) or 0
  local totalFrigoDmg = 0

  if config.useFrigoHur and frigoReady then
    bestFrigoDir, frigoHits = evaluateGranFrigoHur(playerPos, aliveMonsters, innocentPlayers)
    totalFrigoDmg = frigoHits * baseFrigoDmg
  end

  -- 2c. Exevo Tera Hur (Terra Wave)
  local teraReady, teraCdRemain = isSpellReady("tera", config.teraCooldown or 4000)
  local baseTeraDmg = getBaseDamage("tera")
  local teraHits = 0
  local bestTeraDir = (player and player.getDirection and player:getDirection()) or 0
  local totalTeraDmg = 0

  if config.useTeraHur and teraReady then
    bestTeraDir, teraHits = evaluateTeraHur(playerPos, aliveMonsters, innocentPlayers)
    totalTeraDmg = teraHits * baseTeraDmg
  end

  -- =======================================================================
  -- 3. COMPARAR QUÉ SPELL HACE EL MÁXIMO DAÑO ENTRE LAS DISPONIBLES
  -- =======================================================================
  local bestSpellKey = nil
  local maxSpellDmg = 0
  local bestSpellHits = 0
  local bestSpellDir = (player and player.getDirection and player:getDirection()) or 0
  local bestSpellWords = ""

  -- Candidato 1: Ulus
  if ulusReady and ulusHits >= 1 and totalUlusDmg > maxSpellDmg then
    maxSpellDmg = totalUlusDmg
    bestSpellKey = "ulus"
    bestSpellHits = ulusHits
    bestSpellWords = config.ulusSpell
  end

  -- Candidato 2: Gran Frigo Hur
  if config.useFrigoHur and frigoReady and frigoHits >= 1 and totalFrigoDmg > maxSpellDmg then
    maxSpellDmg = totalFrigoDmg
    bestSpellKey = "frigo"
    bestSpellHits = frigoHits
    bestSpellDir = bestFrigoDir
    bestSpellWords = config.frigoSpell
  end

  -- Candidato 3: Tera Hur
  if config.useTeraHur and teraReady and teraHits >= 1 and totalTeraDmg > maxSpellDmg then
    maxSpellDmg = totalTeraDmg
    bestSpellKey = "tera"
    bestSpellHits = teraHits
    bestSpellDir = bestTeraDir
    bestSpellWords = config.teraSpell
  end

  -- =======================================================================
  -- 4. LA DECISIÓN DE ORO:
  -- "siempre tira la runa hasta que alguna spell que haga mas daño este
  -- disponible y solo si de verdad hara mas daño"
  -- =======================================================================

  if bestSpellKey and maxSpellDmg > totalRuneDmg and maxSpellDmg > 0 and bestSpellHits >= 1 then
    -- Si es una ola frontal (Frigo Hur o Tera Hur), acomodar direccion si autoTurn esta activo
    if (bestSpellKey == "frigo" or bestSpellKey == "tera") and config.autoTurn then
      if player:getDirection() ~= bestSpellDir then
        turn(bestSpellDir)
      end
    end

    -- Ejecutar la spell ganadora
    say(bestSpellWords)

    if bestSpellKey == "ulus" then
      lastUlusCast = currentNow
    elseif bestSpellKey == "frigo" then
      lastFrigoCast = currentNow
    elseif bestSpellKey == "tera" then
      lastTeraCast = currentNow
    end
    lastAttack = currentNow

    local statusMsg = string.format("[DPS: %s] %dm (~%d dmg) > Rune %dm (~%d)",
      bestSpellKey:upper(), bestSpellHits, maxSpellDmg, runeHits, totalRuneDmg)
    if bestSpellKey == "frigo" or bestSpellKey == "tera" then
      statusMsg = statusMsg .. string.format(" | Dir: %s", dirNames[bestSpellDir] or "?")
    end
    updateStatus(statusMsg)

    if logCaveBot then
      logCaveBot("DRUID TARGETING", statusMsg)
    end
    return
  end

  -- SI NINGUNA SPELL SUPERA A LA RUNA (O ESTAN EN COOLDOWN O NO PEGAN MEJOR):
  -- Disparar la Runa de Área al mejor punto!
  if runeHits >= 1 and bestRunePos and totalRuneDmg > 0 then
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

      local statusMsg = string.format("[DPS: RUNE] %dm (~%d dmg) | Best Spell: %s (~%d)",
        runeHits, totalRuneDmg, bestSpellKey and bestSpellKey:upper() or "NONE", maxSpellDmg)
      updateStatus(statusMsg)

      if logCaveBot and runeHits >= 3 then
        logCaveBot("DRUID TARGETING", statusMsg)
      end
      return
    end
  end

  -- =======================================================================
  -- 5. FALLBACK: SINGLE TARGET (1 monstruo aislado o remate)
  -- =======================================================================
  local singleTarget = currentTarget or aliveMonsters[1].creature
  if singleTarget and isTargetableCreature(singleTarget) then
    local tPos = singleTarget.getPosition and singleTarget:getPosition()
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

  -- Si no se realizo ningun ataque en este ciclo, evitar busy-loop inmediato
  lastAttack = currentNow - delayMs + 100
end)
