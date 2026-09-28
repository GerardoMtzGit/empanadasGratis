-- Auto Equip (HP Tab) - Anillos, Amuletos y Equipamiento Automatico
setDefaultTab("HP")
local scripts = 2 -- Panel 1: Neck (Amuletos/Collares), Panel 2: Finger (Anillos/Rings)

UI.Label("Auto equip")
if type(storage.autoEquip) ~= "table" then
  storage.autoEquip = {}
end

-- Pares de transformacion conocidos (desgastado <-> activo/usado)
local itemTransformPairs = {
  -- Rings
  [3049] = 3086, [3086] = 3049, -- Stealth Ring
  [3050] = 3087, [3087] = 3050, -- Power Ring
  [3051] = 3088, [3088] = 3051, -- Energy Ring
  [3052] = 3089, [3089] = 3052, -- Life Ring
  [3053] = 3090, [3090] = 3053, -- Time Ring
  [3091] = 3094, [3094] = 3091, -- Club Ring
  [3092] = 3095, [3095] = 3092, -- Sword Ring
  [3093] = 3096, [3096] = 3093, -- Axe Ring
  [3097] = 3099, [3099] = 3097, -- Dwarven Ring
  [3098] = 3100, [3100] = 3098, -- Ring of Healing
  [16114] = 16264, [16264] = 16114, -- Prismatic Ring
  [31621] = 31616, [31616] = 31621, -- Blister Ring
  [32621] = 32635, [32635] = 32621, -- Ring of Souls
  [23537] = 23543, [23543] = 23537, -- Ring of Blue Plasma
  [23535] = 23541, [23541] = 23535, -- Ring of Green Plasma
  [23539] = 23544, [23544] = 23539, -- Ring of Red Plasma

  -- Amulets / Necklaces
  [23531] = 23532, [23532] = 23531, -- Gill Necklace
  [23533] = 23534, [23534] = 23533, -- Prismatic Necklace
  [23529] = 23530, [23530] = 23529, -- Sun Catcher
  [30343] = 30342, [30342] = 30343, -- Sleep Shawl
  [30344] = 30345, [30345] = 30344, -- Enchanted Pendulet
  [30403] = 30402, [30402] = 30403, -- Enchanted Theurgic Amulet
  [23538] = 23542, [23542] = 23538, -- Collar of Blue Plasma
  [23536] = 23540, [23540] = 23536, -- Collar of Green Plasma
  [23540] = 23545, [23545] = 23540  -- Collar of Red Plasma
}

local function isMatching(itemId, target1, target2)
  if not itemId or itemId <= 0 then return false end
  local targets = {}
  local function add(t)
    if t and t > 0 then
      targets[t] = true
      if itemTransformPairs[t] then targets[itemTransformPairs[t]] = true end
      if getActiveItemId and getActiveItemId(t) then targets[getActiveItemId(t)] = true end
      if getInactiveItemId and getInactiveItemId(t) then targets[getInactiveItemId(t)] = true end
    end
  end
  add(target1)
  add(target2)
  return targets[itemId] == true
end

for i=1,scripts do
  if not storage.autoEquip[i] then
    storage.autoEquip[i] = {
      on = false,
      title = i == 1 and "Auto Equip Neck" or "Auto Equip Ring",
      item1 = i == 1 and 3081 or 3052,
      item2 = i == 1 and 0 or 3089,
      slot = i == 1 and 2 or 9
    }
  end

  -- Garantizar que el slot nunca quede en 0 o vacio (2=Neck, 9=Finger)
  if not storage.autoEquip[i].slot or storage.autoEquip[i].slot <= 0 then
    storage.autoEquip[i].slot = (i == 1 and 2 or 9)
  end

  -- Titulo descriptivo para identificar que equipa cada seccion
  if storage.autoEquip[i].title == "Auto Equip" or not storage.autoEquip[i].title then
    storage.autoEquip[i].title = (storage.autoEquip[i].slot == 2 and "Auto Equip Neck") or (storage.autoEquip[i].slot == 9 and "Auto Equip Ring") or "Auto Equip"
  end

  UI.TwoItemsAndSlotPanel(storage.autoEquip[i], function(widget, newParams)
    storage.autoEquip[i] = newParams
  end)
end

-- =========================================================================
-- Emergencia: Auto SSA + Might Ring (< 15% Mana)
-- =========================================================================
UI.Separator()

if type(storage.emergencyEquip) ~= "table" then
  storage.emergencyEquip = {
    enabled = false,
    manaPercent = 15,
    ssaId = 3081,
    ringId = 3048
  }
end
local emConfig = storage.emergencyEquip
if emConfig.manaPercent == nil then emConfig.manaPercent = 15 end
if emConfig.ssaId == nil then emConfig.ssaId = 3081 end
if emConfig.ringId == nil then emConfig.ringId = 3048 end

local emUi = setupUI([[
Panel
  height: 68
  margin-top: 4
  margin-left: 1
  margin-right: 1

  BotSwitch
    id: switch
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: 18
    text-align: center
    !text: tr('Auto SSA + Might Ring')

  BotItem
    id: ssaItem
    anchors.top: switch.bottom
    anchors.left: parent.left
    margin-top: 3
    margin-left: 2
    tooltip: Stone Skin Amulet (Slot 2 / Cuello)

  BotItem
    id: ringItem
    anchors.top: prev.top
    anchors.left: prev.right
    margin-left: 4
    tooltip: Might Ring (Slot 9 / Anillo)

  Label
    id: manaLabel
    anchors.verticalCenter: prev.verticalCenter
    anchors.left: prev.right
    margin-left: 6
    font: cipsoftFont
    text: MP <

  TextEdit
    id: manaPercent
    anchors.verticalCenter: prev.verticalCenter
    anchors.left: prev.right
    margin-left: 3
    width: 28
    height: 18
    font: cipsoftFont
    text-align: center

  Label
    id: percentSign
    anchors.verticalCenter: prev.verticalCenter
    anchors.left: prev.right
    margin-left: 2
    font: cipsoftFont
    text: %

  Label
    id: status
    anchors.top: ssaItem.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    margin-top: 3
    font: cipsoftFont
    text-align: center
    color: #a0a0a0
    text: [OFF] Inactivo
]])

local lastStatusText = ""
local function updateStatus()
  if not emUi or not emUi.status then return end
  if not emConfig.enabled then
    if lastStatusText ~= "OFF" then
      emUi.status:setText("[OFF] Inactivo")
      emUi.status:setColor("#a0a0a0")
      lastStatusText = "OFF"
    end
  else
    local mp = manapercent() or 100
    local threshold = tonumber(emConfig.manaPercent) or 15
    if mp < threshold then
      local text = string.format("[!] EMERGENCIA (<%d%% MP)", threshold)
      if lastStatusText ~= text then
        emUi.status:setText(text)
        emUi.status:setColor("#ff4444")
        lastStatusText = text
      end
    else
      local text = string.format("[ON] Monitoreando (MP: %d%%)", mp)
      if lastStatusText ~= text then
        emUi.status:setText(text)
        emUi.status:setColor("#55ff55")
        lastStatusText = text
      end
    end
  end
end

emUi.switch:setOn(emConfig.enabled)
emUi.switch.onClick = function(widget)
  emConfig.enabled = not emConfig.enabled
  widget:setOn(emConfig.enabled)
  updateStatus()
end

emUi.ssaItem:setItemId(emConfig.ssaId or 3081)
emUi.ssaItem.onItemChange = function(widget)
  emConfig.ssaId = widget:getItemId()
end

emUi.ringItem:setItemId(emConfig.ringId or 3048)
emUi.ringItem.onItemChange = function(widget)
  emConfig.ringId = widget:getItemId()
end

emUi.manaPercent:setText(tostring(emConfig.manaPercent or 15))
emUi.manaPercent.onTextChange = function(widget, text)
  local val = tonumber(text)
  if val then
    emConfig.manaPercent = val
  end
end

updateStatus()

local function equipItemDirect(item, slot)
  if not item then return false end
  local itemId = (type(item) == "userdata" or type(item) == "table") and (item.getId and item:getId() or item.id) or item
  local count = (slot == 10 and item.isStackable and item:isStackable() and item:getCount()) or 1

  -- Metodo 1: Quick-equip nativo del cliente/servidor por ID
  if g_game.equipItemId and itemId and tonumber(itemId) then
    pcall(function() g_game.equipItemId(tonumber(itemId)) end)
  end

  -- Metodo 2: Mover directamente al slot (compatible con 8.60 y todos los protocolos)
  if type(item) == "userdata" or (type(item) == "table" and item.getId) then
    pcall(function()
      g_game.move(item, {x = 65535, y = slot, z = 0}, count)
    end)
  end

  return true
end

local function findItemById(id)
  if not id or id <= 0 then return nil end
  local containers = g_game.getContainers()
  for _, container in pairs(containers) do
    for _, item in ipairs(container:getItems()) do
      if item:getId() == id then
        return item
      end
    end
  end
  if findItem then
    local it = findItem(id)
    if it then return it end
  end
  return nil
end

-- Macro de emergencia rapido (80ms) para respuesta inmediata bajo fuego
macro(80, function()
  if not emConfig.enabled then return end
  if not g_game.isOnline() then return end
  if isInPz and isInPz() then return end

  local mp = manapercent() or 100
  local threshold = tonumber(emConfig.manaPercent) or 15

  updateStatus()

  if mp >= threshold then
    return
  end

  -- Modo emergencia: MP < threshold
  -- 1. Prioridad Cuello: Stone Skin Amulet (Slot 2)
  local ssaId = emConfig.ssaId or 3081
  if ssaId > 0 then
    local currentNeck = getSlot(2)
    if not currentNeck or currentNeck:getId() ~= ssaId then
      local ssaItem = findItemById(ssaId)
      if ssaItem then
        equipItemDirect(ssaItem, 2)
        delay(100)
        return
      elseif g_game.equipItemId then
        pcall(function() g_game.equipItemId(ssaId) end)
      end
    end
  end

  -- 2. Dedo: Might Ring (Slot 9)
  local ringId = emConfig.ringId or 3048
  if ringId > 0 then
    local currentRing = getSlot(9)
    if not currentRing or currentRing:getId() ~= ringId then
      local ringItem = findItemById(ringId)
      if ringItem then
        equipItemDirect(ringItem, 9)
        delay(100)
        return
      elseif g_game.equipItemId then
        pcall(function() g_game.equipItemId(ringId) end)
      end
    end
  end
end)

macro(250, function()
  if not g_game.isOnline() then return end

  local isEmergencyActive = emConfig and emConfig.enabled and ((manapercent() or 100) < (tonumber(emConfig.manaPercent) or 15))

  for index, autoEquip in ipairs(storage.autoEquip) do
    if autoEquip.on and autoEquip.slot and autoEquip.slot > 0 then
      -- Si la emergencia de SSA/Might Ring esta activa, no interferir con los slots 2 (Neck) y 9 (Finger)
      if isEmergencyActive and (autoEquip.slot == 2 or autoEquip.slot == 9) then
        -- Saltear autoEquip normal en estos slots para priorizar SSA y Might Ring
      else
        local id1 = autoEquip.item1 or 0
        local id2 = autoEquip.item2 or 0

        -- Procesar solo si hay al menos un item seleccionado en alguno de los dos slots
        if id1 > 0 or id2 > 0 then
          local slotItem = getSlot(autoEquip.slot)

          -- Si el slot no tiene el item deseado (o esta vacio o tiene un item diferente)
          if not slotItem or not isMatching(slotItem:getId(), id1, id2) then
            local itemToEquip = nil
            local containers = g_game.getContainers()

            -- 1. Buscar en mochilas abiertas (visibles, minimizadas u ocultas)
            for _, container in pairs(containers) do
              for __, item in ipairs(container:getItems()) do
                if isMatching(item:getId(), id1, id2) then
                  itemToEquip = item
                  break
                end
              end
              if itemToEquip then break end
            end

            -- 2. Respaldo por findItem si no se encontro en el primer barrido
            if not itemToEquip then
              if id1 > 0 and findItem(id1) then
                itemToEquip = findItem(id1)
              elseif id2 > 0 and findItem(id2) then
                itemToEquip = findItem(id2)
              elseif id1 > 0 and itemTransformPairs[id1] and findItem(itemTransformPairs[id1]) then
                itemToEquip = findItem(itemTransformPairs[id1])
              elseif id2 > 0 and itemTransformPairs[id2] and findItem(itemTransformPairs[id2]) then
                itemToEquip = findItem(itemTransformPairs[id2])
              end
            end

            -- 3. Si encontramos el item en cualquier mochila abierta, equiparlo directamente
            if itemToEquip then
              equipItemDirect(itemToEquip, autoEquip.slot)
              delay(350) -- Evitar spam de paquetes
              return
            end

            -- 4. Si NO esta en mochilas abiertas, intentar quick-equip nativo por ID de inmediato
            local targetId = (id1 > 0 and id1) or id2
            if targetId > 0 and g_game.equipItemId then
              pcall(function() g_game.equipItemId(targetId) end)
              if itemTransformPairs[targetId] then
                pcall(function() g_game.equipItemId(itemTransformPairs[targetId]) end)
              end
            end
          end
        end
      end
    end
  end
end)