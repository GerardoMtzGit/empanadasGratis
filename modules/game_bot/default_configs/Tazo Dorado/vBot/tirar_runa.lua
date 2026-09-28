local targetingTab = storage.extras and storage.extras.joinBot and "Cave" or "Target"
setDefaultTab(targetingTab)

local panelName = "tirar_runa"

if not storage[panelName] then
  storage[panelName] = {
    enabled = false,
    mode = 1, -- 1: Dinamico, 2: Solo 1, 3: Varios (Area)
    singleType = "spell", -- "spell" o "rune"
    singleSpell = "exori gran tera", -- Spell por defecto
    singleRuneId = 3155, -- SD default si es runa
    singleApproach = true, -- Acercarse a 3 SQM
    singleApproachDist = 3,
    areaRuneId = 3191,   -- GFB default
    minMonsters = 2,
    delay = 201,         -- 201 ms default
    areaRadius = 3,
    maxRange = 6,
    autoTarget = true,   -- Auto-apuntar a donde pegue a mas monstruos
    safePvp = true,
    ignoreParty = true,
    prioritizeMana = true -- Priorizar tener >20% de mana antes de tirar runa/spell
  }
end

local config = storage[panelName]
if config.delay == 2000 or not config.delay then
  config.delay = 201
end
if config.singleType == nil then
  config.singleType = "spell"
end
if config.singleSpell == nil then
  config.singleSpell = "exori gran tera"
end
if not config.singleRuneId or config.singleRuneId <= 0 then
  config.singleRuneId = 3155
end
if config.singleApproach == nil then
  config.singleApproach = true
end
if config.singleApproachDist == nil then
  config.singleApproachDist = 3
end
if config.prioritizeMana == nil then
  config.prioritizeMana = true
end

-- Main UI panel in Target Tab (Placed prominently at top)
local ui = setupUI([[
Panel
  height: 48
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
    !text: tr('Tirar Runa')

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
    text: [OFF] Dinamico | exori gran tera / GFB (>=2)

  HorizontalSeparator
    anchors.top: prev.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    margin-top: 5
]])

local runeNames = {
  [3155] = "SD",
  [2268] = "SD",
  [3198] = "HMM",
  [2311] = "HMM",
  [3158] = "Icicle",
  [2271] = "Icicle",
  [3189] = "Fireball",
  [2287] = "Fireball",
  [3179] = "Stalagmite",
  [2292] = "Stalagmite",
  [3182] = "Holy",
  [2295] = "Holy",
  [3200] = "Explo",
  [2313] = "Explo",
  [3191] = "GFB",
  [2304] = "GFB",
  [3161] = "Ava",
  [2274] = "Ava",
  [3202] = "Thunder",
  [2315] = "Thunder",
  [3175] = "Stone",
  [2288] = "Stone",
  [3192] = "FBomb",
  [2305] = "FBomb",
  [3173] = "PBomb",
  [2286] = "PBomb",
  [3149] = "EBomb",
  [2262] = "EBomb"
}

local runeAltIds = {
  [3155] = 2268, [2268] = 3155, -- SD
  [3161] = 2274, [2274] = 3161, -- Avalanche
  [3191] = 2304, [2304] = 3191, -- GFB
  [3202] = 2315, [2315] = 3202, -- Thunderstorm
  [3175] = 2288, [2288] = 3175, -- Stone Shower
  [3158] = 2271, [2271] = 3158, -- Icicle
  [3198] = 2311, [2311] = 3198, -- HMM
  [3200] = 2313, [2313] = 3200, -- Explosion
  [3182] = 2295, [2295] = 3182, -- Holy Missile
  [3189] = 2287, [2287] = 3189, -- Fireball
  [3179] = 2292, [2292] = 3179, -- Stalagmite
  [3192] = 2305, [2305] = 3192, -- Fire Bomb
  [3173] = 2286, [2286] = 3173, -- Poison Bomb
  [3149] = 2262, [2262] = 3149  -- Energy Bomb
}

local function getRuneShortName(id)
  return runeNames[id] or ("ID:" .. tostring(id))
end

local function getSingleTargetName()
  if config.singleType == "spell" then
    return config.singleSpell or "exori frigo"
  else
    return getRuneShortName(config.singleRuneId)
  end
end

local function updateStatus()
  local modeText = "Dinamico"
  if config.mode == 2 then
    modeText = "Solo 1"
  elseif config.mode == 3 then
    modeText = "Area"
  end
  local onText = config.enabled and "[ON]" or "[OFF]"
  local sName = getSingleTargetName()
  local aName = getRuneShortName(config.areaRuneId)
  local mpTag = config.prioritizeMana and " [>20%MP]" or ""
  if config.mode == 2 then
    ui.status:setText(string.format("%s %s (%s)%s [%dms]", onText, modeText, sName, mpTag, config.delay or 201))
  elseif config.mode == 3 then
    ui.status:setText(string.format("%s %s (%s)%s [%dms]", onText, modeText, aName, mpTag, config.delay or 201))
  else
    ui.status:setText(string.format("%s %s (%s/%s >=%d)%s [%dms]", onText, modeText, sName, aName, config.minMonsters or 2, mpTag, config.delay or 201))
  end
  if config.enabled then
    ui.status:setColor("#00ff00")
  else
    ui.status:setColor("#a0a0a0")
  end
end

-- Create configuration window
local runeWindow = UI.createWindow('TirarRunaWindow')
runeWindow:hide()

-- Banderas de proteccion contra recursion en eventos de UI (evita que el cliente crashee/se cierre)
local updatingSingleUI = false
local updatingAreaUI = false

-- Populate Mode ComboBox
local modes = {
  { text = "Dinamico (1=Single, 2+=Area)", id = 1 },
  { text = "Solo 1 Monster (Single)", id = 2 },
  { text = "Varios Monsters (Area)", id = 3 }
}
for _, m in ipairs(modes) do
  runeWindow.modeCombo:addOption(m.text, m.id)
end

-- Preset single runes / spells
local singleOptions = {
  { text = "[Spell] exori gran tera", type = "spell", spell = "exori gran tera", id = 0 },
  { text = "[Spell] exori gran frigo", type = "spell", spell = "exori gran frigo", id = 0 },
  { text = "[Spell] exori gran flam", type = "spell", spell = "exori gran flam", id = 0 },
  { text = "[Spell] exori gran vis", type = "spell", spell = "exori gran vis", id = 0 },
  { text = "[Spell] exori tera", type = "spell", spell = "exori tera", id = 0 },
  { text = "[Spell] exori frigo", type = "spell", spell = "exori frigo", id = 0 },
  { text = "[Spell] exori flam", type = "spell", spell = "exori flam", id = 0 },
  { text = "[Spell] exori vis", type = "spell", spell = "exori vis", id = 0 },
  { text = "[Spell] exori mort", type = "spell", spell = "exori mort", id = 0 },
  { text = "[Spell] exori san", type = "spell", spell = "exori san", id = 0 },
  { text = "[Spell] exori hur", type = "spell", spell = "exori hur", id = 0 },
  { text = "[Spell] exori ico", type = "spell", spell = "exori ico", id = 0 },
  { text = "[Spell] exori con", type = "spell", spell = "exori con", id = 0 },
  { text = "[Spell] Personalizada", type = "spell", spell = "exori gran tera", id = 0 },
  { text = "[Runa] Sudden Death (SD)", type = "rune", spell = "", id = 3155 },
  { text = "[Runa] Heavy Magic Missile", type = "rune", spell = "", id = 3198 },
  { text = "[Runa] Icicle", type = "rune", spell = "", id = 3158 },
  { text = "[Runa] Fireball", type = "rune", spell = "", id = 3189 },
  { text = "[Runa] Stalagmite", type = "rune", spell = "", id = 3179 },
  { text = "[Runa] Holy Missile", type = "rune", spell = "", id = 3182 },
  { text = "[Runa] Explosion", type = "rune", spell = "", id = 3200 },
  { text = "[Runa] Custom ID", type = "rune", spell = "", id = 0 }
}
for _, r in ipairs(singleOptions) do
  runeWindow.singlePanel.singleCombo:addOption(r.text, r)
end

-- Preset area runes
local areaRunes = {
  { text = "Thunderstorm / Thunderlord", id = 3202 },
  { text = "Great Fireball (GFB)", id = 3191 },
  { text = "Avalanche", id = 3161 },
  { text = "Stone Shower", id = 3175 },
  { text = "Fire Bomb", id = 3192 },
  { text = "Poison Bomb", id = 3173 },
  { text = "Energy Bomb", id = 3149 },
  { text = "Personalizada", id = 0 }
}
for _, r in ipairs(areaRunes) do
  runeWindow.areaPanel.areaCombo:addOption(r.text, r.id)
end

local function setSingleOptionUI()
  if updatingSingleUI then return end
  updatingSingleUI = true

  if config.singleType == "spell" then
    local currentSpell = config.singleSpell or "exori frigo"
    local found = false
    for _, opt in ipairs(singleOptions) do
      if opt.type == "spell" and opt.spell == currentSpell and opt.text ~= "[Spell] Personalizada" then
        runeWindow.singlePanel.singleCombo:setOption(opt.text)
        found = true
        break
      end
    end
    if not found then
      runeWindow.singlePanel.singleCombo:setOption("[Spell] Personalizada")
    end
    runeWindow.singlePanel.singleItem:setItemId(0)
    runeWindow.singlePanel.singleId:setText(currentSpell)
    runeWindow.singlePanel.singleIdLabel:setText("Spell:")
  else
    local currentRune = config.singleRuneId or 3155
    local found = false
    for _, opt in ipairs(singleOptions) do
      if opt.type == "rune" and opt.id == currentRune and opt.id ~= 0 then
        runeWindow.singlePanel.singleCombo:setOption(opt.text)
        found = true
        break
      end
    end
    if not found then
      runeWindow.singlePanel.singleCombo:setOption("[Runa] Custom ID")
    end
    runeWindow.singlePanel.singleItem:setItemId(currentRune)
    runeWindow.singlePanel.singleId:setText(tostring(currentRune))
    runeWindow.singlePanel.singleIdLabel:setText("Item ID:")
  end

  updatingSingleUI = false
end

local function setAreaRuneOption(runeId)
  if updatingAreaUI then return end
  updatingAreaUI = true

  local found = false
  for _, r in ipairs(areaRunes) do
    if r.id == runeId and r.id ~= 0 then
      runeWindow.areaPanel.areaCombo:setOption(r.text)
      found = true
      break
    end
  end
  if not found then
    runeWindow.areaPanel.areaCombo:setOption("Personalizada")
  end
  runeWindow.areaPanel.areaItem:setItemId(runeId)
  runeWindow.areaPanel.areaId:setText(tostring(runeId))

  updatingAreaUI = false
end

-- Init values in window
for _, m in ipairs(modes) do
  if m.id == config.mode then
    runeWindow.modeCombo:setOption(m.text)
    break
  end
end
setSingleOptionUI()
setAreaRuneOption(config.areaRuneId)

runeWindow.minMonsters:setValue(config.minMonsters or 2)
runeWindow.minMonstersLabel:setText("Min. Monsters para Area: " .. tostring(config.minMonsters or 2))

runeWindow.delay:setValue(config.delay or 201)
runeWindow.delayLabel:setText("Delay entre Runas: " .. tostring(config.delay or 201) .. " ms")

runeWindow.singleApproach:setChecked(config.singleApproach)
runeWindow.autoTarget:setChecked(config.autoTarget)
runeWindow.safePvp:setChecked(config.safePvp)
if runeWindow.prioritizeMana then
  runeWindow.prioritizeMana:setChecked(config.prioritizeMana)
end

-- Event listeners con proteccion completa contra recursividad infinita
runeWindow.modeCombo.onOptionChange = function(widget, option, data)
  for _, m in ipairs(modes) do
    if m.text == option then
      config.mode = m.id
      break
    end
  end
  updateStatus()
end

runeWindow.singlePanel.singleCombo.onOptionChange = function(widget, option, data)
  if updatingSingleUI then return end
  updatingSingleUI = true

  for _, opt in ipairs(singleOptions) do
    if opt.text == option then
      if opt.type == "spell" then
        config.singleType = "spell"
        if opt.text ~= "[Spell] Personalizada" then
          config.singleSpell = opt.spell
        end
        runeWindow.singlePanel.singleItem:setItemId(0)
        runeWindow.singlePanel.singleId:setText(config.singleSpell)
        runeWindow.singlePanel.singleIdLabel:setText("Spell:")
      else
        config.singleType = "rune"
        if opt.id > 0 then
          config.singleRuneId = opt.id
        end
        runeWindow.singlePanel.singleItem:setItemId(config.singleRuneId)
        runeWindow.singlePanel.singleId:setText(tostring(config.singleRuneId))
        runeWindow.singlePanel.singleIdLabel:setText("Item ID:")
      end
      break
    end
  end

  updatingSingleUI = false
  updateStatus()
end

runeWindow.singlePanel.singleItem.onItemChange = function(widget)
  if updatingSingleUI then return end
  local itemId = widget:getItemId()
  if itemId and itemId > 0 then
    config.singleType = "rune"
    config.singleRuneId = itemId
    setSingleOptionUI()
    updateStatus()
  end
end

runeWindow.singlePanel.singleId.onTextChange = function(widget, text)
  if updatingSingleUI then return end
  text = text:trim()
  local num = tonumber(text)
  if num and num > 0 then
    config.singleType = "rune"
    config.singleRuneId = num
    updatingSingleUI = true
    runeWindow.singlePanel.singleItem:setItemId(num)
    runeWindow.singlePanel.singleIdLabel:setText("Item ID:")
    local found = false
    for _, opt in ipairs(singleOptions) do
      if opt.type == "rune" and opt.id == num then
        runeWindow.singlePanel.singleCombo:setOption(opt.text)
        found = true
        break
      end
    end
    if not found then
      runeWindow.singlePanel.singleCombo:setOption("[Runa] Custom ID")
    end
    updatingSingleUI = false
  elseif text:len() > 0 then
    config.singleType = "spell"
    config.singleSpell = text
    updatingSingleUI = true
    runeWindow.singlePanel.singleItem:setItemId(0)
    runeWindow.singlePanel.singleIdLabel:setText("Spell:")
    local found = false
    for _, opt in ipairs(singleOptions) do
      if opt.type == "spell" and opt.spell == text and opt.text ~= "[Spell] Personalizada" then
        runeWindow.singlePanel.singleCombo:setOption(opt.text)
        found = true
        break
      end
    end
    if not found then
      runeWindow.singlePanel.singleCombo:setOption("[Spell] Personalizada")
    end
    updatingSingleUI = false
  end
  updateStatus()
end

runeWindow.areaPanel.areaCombo.onOptionChange = function(widget, option, data)
  if updatingAreaUI then return end
  updatingAreaUI = true

  for _, r in ipairs(areaRunes) do
    if r.text == option then
      if r.id > 0 then
        config.areaRuneId = r.id
        runeWindow.areaPanel.areaItem:setItemId(r.id)
        runeWindow.areaPanel.areaId:setText(tostring(r.id))
      end
      break
    end
  end

  updatingAreaUI = false
  updateStatus()
end

runeWindow.areaPanel.areaItem.onItemChange = function(widget)
  if updatingAreaUI then return end
  local itemId = widget:getItemId()
  if itemId and itemId > 0 and itemId ~= config.areaRuneId then
    config.areaRuneId = itemId
    setAreaRuneOption(itemId)
    updateStatus()
  end
end

runeWindow.areaPanel.areaId.onTextChange = function(widget, text)
  if updatingAreaUI then return end
  local val = tonumber(text:trim())
  if val and val > 0 and val ~= config.areaRuneId then
    config.areaRuneId = val
    updatingAreaUI = true
    runeWindow.areaPanel.areaItem:setItemId(val)
    local found = false
    for _, r in ipairs(areaRunes) do
      if r.id == val and r.id ~= 0 then
        runeWindow.areaPanel.areaCombo:setOption(r.text)
        found = true
        break
      end
    end
    if not found then
      runeWindow.areaPanel.areaCombo:setOption("Personalizada")
    end
    updatingAreaUI = false
    updateStatus()
  end
end

runeWindow.minMonsters.onValueChange = function(widget, value)
  config.minMonsters = value
  runeWindow.minMonstersLabel:setText("Min. Monsters para Area: " .. tostring(value))
  updateStatus()
end

runeWindow.delay.onValueChange = function(widget, value)
  config.delay = value
  runeWindow.delayLabel:setText("Delay entre Runas: " .. tostring(value) .. " ms")
  updateStatus()
end

runeWindow.singleApproach.onClick = function(widget)
  config.singleApproach = not config.singleApproach
  widget:setChecked(config.singleApproach)
end

runeWindow.autoTarget.onClick = function(widget)
  config.autoTarget = not config.autoTarget
  widget:setChecked(config.autoTarget)
end

runeWindow.safePvp.onClick = function(widget)
  config.safePvp = not config.safePvp
  widget:setChecked(config.safePvp)
end

if runeWindow.prioritizeMana then
  runeWindow.prioritizeMana.onClick = function(widget)
    config.prioritizeMana = not config.prioritizeMana
    widget:setChecked(config.prioritizeMana)
    updateStatus()
  end
end

runeWindow.closeButton.onClick = function()
  runeWindow:hide()
end

-- Main switch wiring
ui.title:setOn(config.enabled)
ui.title.onClick = function(widget)
  config.enabled = not config.enabled
  widget:setOn(config.enabled)
  if config.enabled then
    lastRuneCast = 0
  end
  updateStatus()
end

ui.configBtn.onClick = function()
  runeWindow:show()
  runeWindow:raise()
  runeWindow:focus()
end

updateStatus()

-- Determine if creature is a valid monster target (STRICTLY excludes players and familiars/summons)
local function isTargetableCreature(spec)
  if not spec or spec:isLocalPlayer() then return false end
  if spec:isPlayer() then return false end -- NEVER target any player
  if spec:isNpc() then return false end
  local p = spec:getPosition()
  if not p or p.z ~= posz() then return false end
  local hp = spec:getHealthPercent()
  if not hp or hp <= 0 then return false end

  -- Exclude summons and familiars (Druid Familiar, Sorcerer Familiar, etc.)
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

-- Reliable rune caster: uses hotkey inventory first, falls back to open backpacks
local function shootRune(runeId, targetThing)
  if not runeId or runeId <= 0 or not targetThing then return false end

  -- Priorizar tener >20% de mana antes de tirar runa
  if config.prioritizeMana and (manapercent() or 100) <= 20 then
    return false
  end

  -- Safeguard: ensure creature target is alive and valid
  if targetThing.isCreature and targetThing:isCreature() then
    local p = targetThing:getPosition()
    if not p or p.z ~= posz() or targetThing:getHealthPercent() <= 0 then
      return false
    end
  end

  local altId = runeAltIds[runeId]
  local subType = (g_game.getClientVersion and g_game.getClientVersion() >= 860) and 0 or 1
  local ok = false

  -- 1. Intentar usar por inventario / hotkey directo con runeId
  pcall(function()
    g_game.useInventoryItemWith(runeId, targetThing, subType)
    ok = true
  end)

  -- 2. Si no funciono, intentar con ID alternativo (client ID vs server ID)
  if not ok and altId then
    pcall(function()
      g_game.useInventoryItemWith(altId, targetThing, subType)
      ok = true
    end)
  end

  -- 3. Si no esta en hotkeys, buscar item en mochilas abiertas
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

-- Check whether (mx, my) is within standard 37-tile Tibia area rune blast centered at (cx, cy)
local function isBlastHit(cx, cy, mx, my)
  local dx = math.abs(mx - cx)
  local dy = math.abs(my - cy)
  return (dx <= 3 and dy <= 3) and (dx + dy <= 4 or (dx <= 2 and dy <= 2))
end

-- Function to find optimal target position where area rune hits the most monsters
local function getBestAreaTarget(aliveMonsters, currentTarget)
  local playerPos = pos()
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

  -- Midpoints between pairs of monsters
  for i = 1, #aliveMonsters do
    local p1 = aliveMonsters[i]:getPosition()
    for j = i + 1, #aliveMonsters do
      local p2 = aliveMonsters[j]:getPosition()
      local dist = math.max(math.abs(p1.x - p2.x), math.abs(p1.y - p2.y))
      if dist <= 6 then
        local midX = math.floor((p1.x + p2.x) / 2)
        local midY = math.floor((p1.y + p2.y) / 2)
        addCandidate({ x = midX, y = midY, z = pz }, nil)
        local ceilX = math.ceil((p1.x + p2.x) / 2)
        local ceilY = math.ceil((p1.y + p2.y) / 2)
        if ceilX ~= midX or ceilY ~= midY then
          addCandidate({ x = ceilX, y = ceilY, z = pz }, nil)
        end
      end
    end
  end

  -- Triangle centroids for triads of monsters (finds perfect 3-target center)
  local triadCount = 0
  for i = 1, #aliveMonsters do
    if triadCount > 30 then break end
    local p1 = aliveMonsters[i]:getPosition()
    for j = i + 1, #aliveMonsters do
      if triadCount > 30 then break end
      local p2 = aliveMonsters[j]:getPosition()
      for k = j + 1, #aliveMonsters do
        if triadCount > 30 then break end
        local p3 = aliveMonsters[k]:getPosition()
        local maxD = math.max(getDistanceBetween(p1, p2), getDistanceBetween(p2, p3), getDistanceBetween(p1, p3))
        if maxD <= 6 then
          local cenX = math.floor((p1.x + p2.x + p3.x) / 3)
          local cenY = math.floor((p1.y + p2.y + p3.y) / 3)
          addCandidate({ x = cenX, y = cenY, z = pz }, nil)
          triadCount = triadCount + 1
        end
      end
    end
  end

  local allSpecs = getSpectators()
  local bestScore = -1
  local bestPos = nil
  local bestCreature = nil

  for _, cand in ipairs(candidatePositions) do
    local cp = cand.pos
    local distFromPlayer = getDistanceBetween(playerPos, cp)
    if distFromPlayer <= (config.maxRange or 6) then
      local tile = g_map.getTile(cp)
      if tile and tile:canShoot() then
        -- PVP / Familiar Safe check: ensure no non-party player or summon/familiar is hit by this blast
        local pvpBlocked = false
        if config.safePvp then
          for _, spec in ipairs(allSpecs) do
            if not spec:isLocalPlayer() and spec:getPosition().z == pz then
              local sp = spec:getPosition()
              if isBlastHit(cp.x, cp.y, sp.x, sp.y) then
                if spec:isPlayer() then
                  if not config.ignoreParty or spec:getShield() <= 2 then
                    pvpBlocked = true
                    break
                  end
                elseif not isTargetableCreature(spec) then
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
          local better = hits > bestScore or (hits == bestScore and isCurTarget)
          if better then
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

-- Core Rune/Spell Loop
local lastRuneCast = 0
local lastWalkApproach = 0

-- Fast auto-target macro (50ms): immediately attacks first monster seen on screen
macro(50, function()
  if not config.enabled then return end
  if storage.druid_targeting and storage.druid_targeting.enabled then return end
  if isInPz() then return end

  local pPos = pos()
  local pz = pPos.z

  local currentTarget = g_game.getAttackingCreature()
  if currentTarget then
    local tPos = currentTarget:getPosition()
    if not tPos or tPos.z ~= pz or currentTarget:getHealthPercent() <= 0 or currentTarget:isPlayer() or not isTargetableCreature(currentTarget) then
      if not isTargetableCreature(currentTarget) then
        g_game.cancelAttackAndFollow()
      end
      currentTarget = nil
    end
  end

  -- If not attacking a valid monster, attack the first/closest monster on screen!
  if not currentTarget then
    local closestDist = 999
    local closestCreature = nil
    for _, spec in ipairs(getSpectators()) do
      if isTargetableCreature(spec) then
        local sPos = spec:getPosition()
        local dist = getDistanceBetween(pPos, sPos)
        if dist < closestDist and dist <= (config.maxRange or 8) then
          closestDist = dist
          closestCreature = spec
        end
      end
    end

    if closestCreature and not closestCreature:isPlayer() then
      g_game.attack(closestCreature)
    end
  end
end)

-- Main rune and spell casting loop
macro(20, function()
  if not config.enabled then return end
  if storage.druid_targeting and storage.druid_targeting.enabled then return end
  if storage.sdOnly and storage.sdOnly.enabled then return end
  if isInPz() then return end

  -- Priorizar tener >20% de mana antes de tirar avalanche o cualquier runa / spell
  if config.prioritizeMana and (manapercent() or 100) <= 20 then
    return
  end

  local currentNow = now
  local delayMs = tonumber(config.delay) or 201
  if lastRuneCast + delayMs > currentNow then return end

  local playerPos = pos()
  local pz = playerPos.z

  -- 1. Gather all alive targetable creatures on current floor within range
  local aliveMonsters = {}
  for _, spec in ipairs(getSpectators()) do
    if isTargetableCreature(spec) then
      local dist = getDistanceBetween(playerPos, spec:getPosition())
      if dist <= (config.maxRange or 7) then
        table.insert(aliveMonsters, spec)
      end
    end
  end

  if #aliveMonsters == 0 then return end

  -- 2. Find current target
  local currentTarget = g_game.getAttackingCreature()
  if currentTarget then
    local tPos = currentTarget:getPosition()
    if not tPos or tPos.z ~= pz or currentTarget:getHealthPercent() <= 0 or currentTarget:isPlayer() or not isTargetableCreature(currentTarget) then
      if not isTargetableCreature(currentTarget) then
        g_game.cancelAttackAndFollow()
      end
      currentTarget = nil
    end
  end

  -- If no target, pick closest monster as target and attack immediately
  if not currentTarget then
    local closestDist = 999
    local closestMonster = nil
    for _, m in ipairs(aliveMonsters) do
      local dist = getDistanceBetween(playerPos, m:getPosition())
      if dist < closestDist then
        closestDist = dist
        closestMonster = m
      end
    end
    if closestMonster and not closestMonster:isPlayer() then
      currentTarget = closestMonster
      g_game.attack(closestMonster)
    end
  end

  -- 3. Determine if we should shoot Area or Single target
  local wantArea = false
  if config.mode == 3 then
    wantArea = true
  elseif config.mode == 1 then
    wantArea = #aliveMonsters >= (config.minMonsters or 2)
  else
    wantArea = false
  end

  -- 4. Execute shooting
  if wantArea and config.areaRuneId and config.areaRuneId > 0 then
    -- AREA RUNE: Aim where it hits the MAXIMUM number of monsters
    local bestPos, bestCreature, bestScore = nil, nil, 0
    if config.autoTarget then
      bestPos, bestCreature, bestScore = getBestAreaTarget(aliveMonsters, currentTarget)
    elseif currentTarget then
      bestPos = currentTarget:getPosition()
      bestCreature = currentTarget
      bestScore = 1
    end

    if bestPos then
      local targetThing = bestCreature
      if not targetThing then
        local tile = g_map.getTile(bestPos)
        if tile then
          targetThing = tile:getTopUseThing() or tile:getGround() or tile
        end
      end
      if targetThing then
        shootRune(config.areaRuneId, targetThing)
        lastRuneCast = currentNow
        return
      end
    end
    -- Fallback to Single Target if area had no valid spot
  end

  -- SINGLE TARGET: Spell (e.g. exori frigo) or Rune (e.g. SD)
  local targetToShoot = currentTarget or aliveMonsters[1]
  if not targetToShoot then return end

  -- ABSOLUTE SAFETY GUARD: Never shoot single spell or rune at a player!
  if targetToShoot:isPlayer() or targetToShoot:isNpc() or not isTargetableCreature(targetToShoot) then
    return
  end

  if g_game.getAttackingCreature() ~= targetToShoot then
    g_game.attack(targetToShoot)
  end

  local tPos = targetToShoot:getPosition()
  if not tPos or tPos.z ~= pz or targetToShoot:getHealthPercent() <= 0 then
    return
  end

  local dist = getDistanceBetween(playerPos, tPos)

  if config.singleType == "spell" and config.singleSpell and config.singleSpell:len() > 0 then
    if config.singleApproach and dist > (config.singleApproachDist or 3) then
      if not player:isWalking() or (lastWalkApproach + 300 < currentNow) then
        autoWalk(tPos, 20, {ignoreNonPathable = true, marginMin = 1, marginMax = (config.singleApproachDist or 3), ignoreCreatures = true})
        lastWalkApproach = currentNow
      end
      return
    end

    say(config.singleSpell)
    lastRuneCast = currentNow
    return
  elseif config.singleRuneId and config.singleRuneId > 0 then
    shootRune(config.singleRuneId, targetToShoot)
    lastRuneCast = currentNow
    return
  end
end)
