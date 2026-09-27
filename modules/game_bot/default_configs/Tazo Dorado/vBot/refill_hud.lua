-- Refill Estimator HUD (Top-Right Screen)
-- Muestra los minutos restantes de refill antes de que se agoten:
-- Ultimate Mana Potion, Avalanche, Sudden Death (SD) o Great Fireball (GFB)

local panelName = "refillHud"
if not storage[panelName] then
  storage[panelName] = {
    enabled = true,
    compact = false,
    soundAlert = true,
    alertMinutes = 5,
    lockPosition = false,
    pos = nil
  }
end

local config = storage[panelName]
if config.enabled == nil then config.enabled = true end
if config.compact == nil then config.compact = false end
if config.soundAlert == nil then config.soundAlert = true end
if config.alertMinutes == nil then config.alertMinutes = 5 end

-- Definicion de los 4 suministros clave
local Supplies = {
  {
    key = "ump",
    name = "Ultimate Mana Potion",
    shortName = "UMP",
    iconId = 23373,
    ids = { 23373, 438 }
  },
  {
    key = "ava",
    name = "Avalanches",
    shortName = "Avalanche",
    iconId = 3161,
    ids = { 3161, 2274 }
  },
  {
    key = "sd",
    name = "Sudden Deaths",
    shortName = "SD",
    iconId = 3155,
    ids = { 3155, 2268 }
  },
  {
    key = "gfb",
    name = "Great Fireballs",
    shortName = "GFB",
    iconId = 3191,
    ids = { 3191, 2304 }
  }
}

-- Estado de consumo de la sesion
local huntSession = {
  startTime = os.time(),
  lastCounts = {},
  consumedTotal = {},
  samples = {}, -- muestras recientes por item: { {time, amount}, ... }
  lastAlertTime = 0
}

local function resetHuntStats()
  huntSession.startTime = os.time()
  huntSession.lastCounts = {}
  huntSession.consumedTotal = {}
  huntSession.samples = {}
  huntSession.lastAlertTime = 0
  for _, s in ipairs(Supplies) do
    huntSession.consumedTotal[s.key] = 0
    huntSession.samples[s.key] = {}
  end
end
resetHuntStats()

-- Contar cantidad total de un suministro en inventario / contenedores
local function getSupplyAmount(supply)
  if not g_game.isOnline() or not player then return 0 end
  local total = 0
  for _, id in ipairs(supply.ids) do
    if itemAmount then
      pcall(function()
        total = total + (itemAmount(id) or 0)
      end)
    elseif player and player.getItemsCount then
      pcall(function()
        total = total + (player:getItemsCount(id) or 0)
      end)
    end
  end
  return total
end

-- Variables de la interfaz
local hudWidget = nil
local rowWidgets = {}
local alertBtnWidget = nil
local alertWidget = nil
local iconosSwitchWidget = nil
local toolsSwitchWidget = nil

local function updateMuteState()
  if hudWidget and hudWidget.header and hudWidget.header.muteBtn then
    if config.soundAlert then
      hudWidget.header.muteBtn:setText("MUTE")
      hudWidget.header.muteBtn:setColor("#4ade80")
      hudWidget.header.muteBtn:setTooltip("Alarma sonora: ACTIVA\nClic para silenciarla/apagarla.")
    else
      hudWidget.header.muteBtn:setText("OFF")
      hudWidget.header.muteBtn:setColor("#f87171")
      hudWidget.header.muteBtn:setTooltip("Alarma sonora: APAGADA\nClic para encenderla.")
    end
  end

  if alertBtnWidget then
    if config.soundAlert then
      alertBtnWidget:setText("Apagar Alarma Sonora (Activa)")
      alertBtnWidget:setColor("#f87171")
    else
      alertBtnWidget:setText("Encender Alarma Sonora (Apagada)")
      alertBtnWidget:setColor("#4ade80")
    end
  end

  if alertWidget then
    alertWidget:setChecked(config.soundAlert)
  end
end

local function createOrUpdateHud()
  local gameMapPanel = modules.game_interface and modules.game_interface.getMapPanel()
  if not gameMapPanel then return end

  if not hudWidget then
    local old = gameMapPanel:getChildById("refillHudFloating")
    if old then old:destroy() end

    hudWidget = g_ui.createWidget("RefillHudWidget", gameMapPanel)
    hudWidget:setId("refillHudFloating")
    hudWidget.botWidget = true

    -- Crear filas para cada suministro
    rowWidgets = {}
    for _, s in ipairs(Supplies) do
      local row = g_ui.createWidget("RefillSupplyRow", hudWidget.rowsContainer)
      row:setId("row_" .. s.key)
      row.itemIcon:setItemId(s.iconId)
      row.itemName:setText(s.shortName)
      rowWidgets[s.key] = row
    end

    -- Boton de cierre 'x' para ocultar el HUD directamente desde la pantalla
    if hudWidget.header and hudWidget.header.closeBtn then
      hudWidget.header.closeBtn.onClick = function(widget)
        config.enabled = false
        hudWidget:setVisible(false)
        if iconosSwitchWidget then
          iconosSwitchWidget:setOn(false)
        end
        if toolsSwitchWidget then
          toolsSwitchWidget:setOn(false)
        end
        return true
      end
    end

    -- Boton para silenciar/apagar la alarma directamente en el HUD
    if hudWidget.header and hudWidget.header.muteBtn then
      hudWidget.header.muteBtn.onClick = function(widget)
        config.soundAlert = not config.soundAlert
        if not config.soundAlert then
          pcall(function() stopSound() end)
        end
        updateMuteState()
        return true
      end
    end

    -- Alternar modo compacto al hacer click en el header
    hudWidget.header.onClick = function()
      config.compact = not config.compact
      hudWidget.rowsContainer:setVisible(not config.compact)
      hudWidget:setHeight(config.compact and 46 or 148)
    end

    -- Soporte para arrastrar con mouse (Ctrl presionado o libre)
    hudWidget.onDragEnter = function(self, mousePos)
      if config.lockPosition and not g_keyboard.isCtrlPressed() then
        return false
      end
      self.movingReference = { x = mousePos.x - self:getX(), y = mousePos.y - self:getY() }
      self.isBeingDragged = true
      return true
    end

    hudWidget.onDragLeave = function(self)
      self.isBeingDragged = false
      return true
    end

    hudWidget.onDragMove = function(self, mousePos, moved)
      local parent = self:getParent()
      if not parent then return false end
      local parentRect = parent:getRect()

      local newX = mousePos.x - self.movingReference.x
      local newY = mousePos.y - self.movingReference.y

      newX = math.max(parentRect.x, math.min(newX, parentRect.x + parentRect.width - self:getWidth()))
      newY = math.max(parentRect.y, math.min(newY, parentRect.y + parentRect.height - self:getHeight()))

      self:breakAnchors()
      self:setPosition({ x = newX, y = newY })
      config.pos = { x = newX - parentRect.x, y = newY - parentRect.y }
      return true
    end
  end

  -- Restaurar estado visual
  hudWidget:setVisible(config.enabled)
  hudWidget.rowsContainer:setVisible(not config.compact)
  hudWidget:setHeight(config.compact and 46 or 148)

  if config.pos then
    local parent = hudWidget:getParent()
    if parent then
      local parentRect = parent:getRect()
      hudWidget:breakAnchors()
      hudWidget:setPosition({ x = parentRect.x + config.pos.x, y = parentRect.y + config.pos.y })
    end
  end

  updateMuteState()
end

createOrUpdateHud()
schedule(500, function()
  createOrUpdateHud()
end)

-- Macro principal: actualiza calculos cada 1000 ms
macro(1000, function()
  if not g_game.isOnline() or not player then return end
  if not config.enabled then
    if hudWidget and hudWidget:isVisible() then
      hudWidget:setVisible(false)
    end
    return
  end

  if not hudWidget then
    createOrUpdateHud()
    return
  end

  if not hudWidget:isVisible() then
    hudWidget:setVisible(true)
  end

  local nowSec = os.time()
  local elapsedTotal = math.max(1, nowSec - huntSession.startTime)

  local curCounts = {}
  local rates = {}      -- consumo por minuto
  local minsLeft = {}   -- minutos restantes antes de agotarse
  local criticalSupply = nil
  local minMins = 999999

  -- 1. Analizar cada suministro y registrar consumo
  for _, s in ipairs(Supplies) do
    local current = getSupplyAmount(s)
    curCounts[s.key] = current

    local prev = huntSession.lastCounts[s.key]
    if prev ~= nil then
      if current < prev then
        local diff = prev - current
        huntSession.consumedTotal[s.key] = (huntSession.consumedTotal[s.key] or 0) + diff
        table.insert(huntSession.samples[s.key], { time = nowSec, amount = diff })
      end
    end
    huntSession.lastCounts[s.key] = current

    -- Limpiar muestras de mas de 10 minutos (600s)
    local filtered = {}
    local recentSum = 0
    for _, sample in ipairs(huntSession.samples[s.key] or {}) do
      if (nowSec - sample.time) <= 600 then
        table.insert(filtered, sample)
        recentSum = recentSum + sample.amount
      end
    end
    huntSession.samples[s.key] = filtered

    -- Calcular tasa de consumo (ponderada entre reciente y sesion completa)
    local ratePerMin = 0
    if #filtered > 0 and elapsedTotal >= 15 then
      local sampleWindow = math.min(elapsedTotal, 600)
      local recentRate = (recentSum / sampleWindow) * 60
      local totalRate = ((huntSession.consumedTotal[s.key] or 0) / elapsedTotal) * 60
      -- 70% reciente, 30% sesion completa
      ratePerMin = (recentRate * 0.70) + (totalRate * 0.30)
    elseif (huntSession.consumedTotal[s.key] or 0) > 0 and elapsedTotal >= 10 then
      ratePerMin = ((huntSession.consumedTotal[s.key] or 0) / elapsedTotal) * 60
    end
    rates[s.key] = ratePerMin

    -- Calcular minutos restantes
    if current == 0 then
      minsLeft[s.key] = 0
      if minMins > 0 then
        minMins = 0
        criticalSupply = s
      end
    elseif ratePerMin > 0.05 then
      local mins = current / ratePerMin
      minsLeft[s.key] = mins
      if mins < minMins then
        minMins = mins
        criticalSupply = s
      end
    else
      minsLeft[s.key] = nil -- Sin uso o tasa casi cero
    end
  end

  -- 2. Determinar estado global y actualizar encabezado
  local banner = hudWidget.header.mainBanner
  local sub = hudWidget.header.subBanner

  if minMins >= 999999 or not criticalSupply then
    -- Sin consumo detectado aun
    banner:setText("[REFILL] CALCULANDO...")
    banner:setColor("#38bdf8")
    sub:setText("Monitoreando UMP y Runas (gasta para estimar)")
    sub:setColor("#94a3b8")
    hudWidget:setBorderColor("#38bdf866")
  elseif minMins == 0 then
    -- Suministro completamente agotado!
    banner:setText("[REFILL YA] (0 MIN)")
    banner:setColor("#ef4444")
    sub:setText("¡Se agotaron las " .. criticalSupply.name .. "!")
    sub:setColor("#fca5a5")
    hudWidget:setBorderColor("#ef4444aa")

    if config.soundAlert and (nowSec - huntSession.lastAlertTime > 45) then
      huntSession.lastAlertTime = nowSec
      pcall(function() playSound("/sounds/alarm.ogg") end)
    end
  elseif minMins <= (config.alertMinutes or 5) then
    -- Peligro critico (< 5 min)
    local roundedMins = math.max(1, math.ceil(minMins))
    banner:setText(string.format("[ALERTA] ¡REFILL EN ~%d MIN! (%s)", roundedMins, criticalSupply.shortName))
    banner:setColor("#f87171")
    sub:setText(string.format("Quedan %d %s (gasto: %d/min)", curCounts[criticalSupply.key], criticalSupply.shortName, math.ceil(rates[criticalSupply.key] or 0)))
    sub:setColor("#fecaca")
    hudWidget:setBorderColor("#ef4444aa")

    if config.soundAlert and (nowSec - huntSession.lastAlertTime > 90) then
      huntSession.lastAlertTime = nowSec
      pcall(function() playSound("/sounds/alarm.ogg") end)
    end
  elseif minMins <= 15 then
    -- Advertencia moderada (5 a 15 min)
    local roundedMins = math.ceil(minMins)
    banner:setText(string.format("Te quedan ~%d min de refill", roundedMins))
    banner:setColor("#fbbf24")
    sub:setText(string.format("Se agotan primero: %s (~%d min)", criticalSupply.name, roundedMins))
    sub:setColor("#fde68a")
    hudWidget:setBorderColor("#f59e0b88")
  else
    -- Tiempo suficiente (> 15 min)
    local roundedMins = math.ceil(minMins)
    banner:setText(string.format("Te quedan ~%d min de refill", roundedMins))
    banner:setColor("#4ade80")
    sub:setText(string.format("Se agotan primero: %s (~%d min)", criticalSupply.name, roundedMins))
    sub:setColor("#bbf7d0")
    hudWidget:setBorderColor("#10b98166")
  end

  -- 3. Actualizar filas individuales
  for _, s in ipairs(Supplies) do
    local row = rowWidgets[s.key]
    if row then
      local count = curCounts[s.key] or 0
      row.itemCount:setText(tostring(count))

      local m = minsLeft[s.key]
      local r = rates[s.key] or 0

      if m == 0 then
        row.itemTime:setText("¡AGOTADO!")
        row.itemTime:setColor("#ef4444")
      elseif m ~= nil then
        local rounded = math.ceil(m)
        row.itemTime:setText(string.format("~%dm (%d/m)", rounded, math.ceil(r)))
        if rounded <= 5 then
          row.itemTime:setColor("#f87171")
        elseif rounded <= 15 then
          row.itemTime:setColor("#fbbf24")
        else
          row.itemTime:setColor("#4ade80")
        end
      else
        if count > 0 then
          row.itemTime:setText("- (sin uso)")
          row.itemTime:setColor("#94a3b8")
        else
          row.itemTime:setText("- (0)")
          row.itemTime:setColor("#64748b")
        end
      end
    end
  end
end)

-- ==========================================
-- 1. Integracion en la pestaña "Iconos" de vBot
-- ==========================================
setDefaultTab("Iconos")
UI.Separator()
UI.Label("-- [[ Refill HUD (Tiempo de Caza) ]] --")

iconosSwitchWidget = addSwitch("refillHudEnableIconos", "Refill HUD en Pantalla", function(widget)
  widget:setOn(not widget:isOn())
  config.enabled = widget:isOn()
  if hudWidget then
    hudWidget:setVisible(config.enabled)
  end
  if toolsSwitchWidget then
    toolsSwitchWidget:setOn(config.enabled)
  end
end)
iconosSwitchWidget:setOn(config.enabled)

UI.Button("Reiniciar Posicion Refill HUD (Top-Right)", function()
  config.pos = nil
  if hudWidget then
    local parent = hudWidget:getParent()
    if parent then
      hudWidget:breakAnchors()
      hudWidget:setMarginTop(10)
      hudWidget:setMarginRight(10)
      hudWidget:addAnchor(AnchorTop, 'parent', AnchorTop)
      hudWidget:addAnchor(AnchorRight, 'parent', AnchorRight)
    end
  end
end)

-- ==========================================
-- 2. Integracion en la pestaña "Tools" de vBot
-- ==========================================
setDefaultTab("Tools")
UI.Separator()
UI.Label("Refill Time Estimator (HUD Superior Derecho)")

toolsSwitchWidget = addSwitch("refillHudEnable", "Show Refill HUD", function(widget)
  widget:setOn(not widget:isOn())
  config.enabled = widget:isOn()
  if hudWidget then
    hudWidget:setVisible(config.enabled)
  end
  if iconosSwitchWidget then
    iconosSwitchWidget:setOn(config.enabled)
  end
end)
toolsSwitchWidget:setOn(config.enabled)

alertBtnWidget = UI.Button("Apagar Alarma Sonora (Activa)", function(widget)
  config.soundAlert = not config.soundAlert
  if not config.soundAlert then
    pcall(function() stopSound() end)
  end
  updateMuteState()
end)

local compactWidget = addSwitch("refillHudCompact", "Compact Mode", function(widget)
  widget:setOn(not widget:isOn())
  config.compact = widget:isOn()
  if hudWidget then
    hudWidget.rowsContainer:setVisible(not config.compact)
    hudWidget:setHeight(config.compact and 46 or 148)
  end
end)
compactWidget:setOn(config.compact)

alertWidget = addSwitch("refillHudSound", "Sound Alert (< 5 min)", function(widget)
  widget:setOn(not widget:isOn())
  config.soundAlert = widget:isOn()
  if not config.soundAlert then
    pcall(function() stopSound() end)
  end
  updateMuteState()
end)
alertWidget:setOn(config.soundAlert)

updateMuteState()

local lockWidget = addSwitch("refillHudLock", "Lock Position (Hold Ctrl to Drag)", function(widget)
  widget:setOn(not widget:isOn())
  config.lockPosition = widget:isOn()
end)
lockWidget:setOn(config.lockPosition)

UI.Button("Reset Hunt Stats", function()
  resetHuntStats()
  if hudWidget then
    hudWidget.header.mainBanner:setText("[REFILL] REINICIADO")
    hudWidget.header.subBanner:setText("Estadísticas reiniciadas, monitoreando...")
  end
end)

UI.Button("Reset Position (Top-Right)", function()
  config.pos = nil
  if hudWidget then
    local parent = hudWidget:getParent()
    if parent then
      hudWidget:breakAnchors()
      hudWidget:setMarginTop(10)
      hudWidget:setMarginRight(10)
      hudWidget:addAnchor(AnchorTop, 'parent', AnchorTop)
      hudWidget:addAnchor(AnchorRight, 'parent', AnchorRight)
    end
  end
end)
