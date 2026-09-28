-- Tab Iconos - Configuracion central de iconos HUD y Quick-Heal
setDefaultTab("Iconos")

local panelName = "iconsTab"
if not storage[panelName] then
  storage[panelName] = {
    enabled = true,
    targetPercent = 90,
    itemId = 438,
    delay = 250,
    autoMaintain = false,
    lockPosition = true,
    pos = { x = 20, y = 30 }
  }
end
local config = storage[panelName]
if not config.pos then
  config.pos = { x = 20, y = 30 }
end

local PotionAliases = {
  [438] = {23373, 23374, 438}, -- Ultimate Mana (23373) / Ultimate Spirit (23374)
  [23373] = {23373, 438},
  [23374] = {23374, 438},
  [144] = {238, 144},          -- Great Mana
  [238] = {238, 144},
  [93]  = {237, 93},           -- Strong Mana
  [237] = {237, 93},
  [56]  = {268, 56},           -- Mana Potion
  [268] = {268, 56},
  [379] = {7643, 379},         -- Ultimate Health
  [7643] = {7643, 379},
  [625] = {23375, 625},        -- Supreme Health
  [23375] = {23375, 625},
  [225] = {239, 225},          -- Great Health
  [239] = {239, 225},
  [115] = {236, 115},          -- Strong Health
  [236] = {236, 115},
  [50]  = {266, 50},           -- Health Potion
  [266] = {266, 50},
  [228] = {7642, 228},         -- Great Spirit
  [7642] = {7642, 228},
}

local function resolveItem(itemId)
  if not itemId or itemId <= 0 then return nil, itemId end

  -- 1. Look in open containers
  local it = findItem(itemId)
  if it then return it, itemId end

  -- 2. Look in inventory slots (1-10)
  if getInventoryItem then
    for slot = 1, 10 do
      local invItem = getInventoryItem(slot)
      if invItem and invItem:getId() == itemId then
        return invItem, itemId
      end
    end
  end

  -- 3. Check aliases
  local candidates = PotionAliases[itemId]
  if candidates then
    for _, altId in ipairs(candidates) do
      it = findItem(altId)
      if it then return it, altId end
      if getInventoryItem then
        for slot = 1, 10 do
          local invItem = getInventoryItem(slot)
          if invItem and invItem:getId() == altId then
            return invItem, altId
          end
        end
      end
    end
  end

  local fallbackId = (candidates and candidates[1]) or itemId
  return nil, fallbackId
end

local function drinkOnce()
  local id = tonumber(config.itemId) or 438
  local itemObj, actualId = resolveItem(id)
  local targetId = actualId or id
  local ok = false

  -- Primary: useInventoryItemWith directly with ID
  if targetId and targetId > 0 then
    ok = pcall(function() g_game.useInventoryItemWith(targetId, player) end)
  end

  -- Secondary: useWith object if found
  if not ok and itemObj then
    ok = pcall(function() g_game.useWith(itemObj, player) end)
  end

  -- Tertiary: check candidates
  if not ok then
    local candidates = PotionAliases[id]
    if candidates then
      for _, altId in ipairs(candidates) do
        if altId ~= targetId then
          ok = pcall(function() g_game.useInventoryItemWith(altId, player) end)
          if ok then break end
        end
      end
    end
  end

  return ok
end

local isDrinking = false
local manaIconWidget = nil
local statusLabel = nil
local emptyAttempts = 0

local function updateVisuals()
  local target = tonumber(config.targetPercent) or 90
  local curMp = manapercent()

  if manaIconWidget then
    manaIconWidget:setVisible(config.enabled)
    local _, previewId = resolveItem(tonumber(config.itemId) or 438)
    manaIconWidget.item:setItemId(previewId or 23373)
    manaIconWidget:setOn(isDrinking)

    if isDrinking then
      manaIconWidget:setBorderColor("#00ffff")
      manaIconWidget:setBackgroundColor("#1e3a8aee")
      manaIconWidget.status:setBackgroundColor("#00ffff")
      manaIconWidget.text:setColor("#00ffff")
      manaIconWidget.text:setText(curMp .. "%")
    else
      manaIconWidget:setBorderColor("#3b82f6")
      manaIconWidget:setBackgroundColor("#0b1526ee")
      manaIconWidget.status:setBackgroundColor("#3b82f6")
      manaIconWidget.text:setColor("#93c5fd")
      manaIconWidget.text:setText(target .. "%")
    end

    manaIconWidget:setTooltip("Icono de Mana (ID " .. (config.itemId or 438) .. ")\n" ..
                              "Clic: Curar mana al " .. target .. "%\n" ..
                              "Estado: " .. (isDrinking and ("CURANDO AL " .. target .. "% (" .. curMp .. "%)") or "Listo") .. "\n" ..
                              "Clic Derecho: Cancelar\n" ..
                              "Ctrl + Arrastrar para mover")
  end

  if statusLabel then
    if isDrinking then
      statusLabel:setText("Curando Mana: " .. curMp .. "% -> " .. target .. "% (En curso...)")
      statusLabel:setColor("#00ffff")
    else
      statusLabel:setText("Mana Actual: " .. curMp .. "% | Estado: Listo")
      statusLabel:setColor("#60a5fa")
    end
  end
end

local function triggerManaHeal(forceState)
  local target = tonumber(config.targetPercent) or 90
  local curMp = manapercent()

  if forceState == false then
    isDrinking = false
    emptyAttempts = 0
    updateVisuals()
    return
  end

  if curMp >= target then
    isDrinking = false
    emptyAttempts = 0
    updateVisuals()
    if manaIconWidget and manaIconWidget.text then
      manaIconWidget.text:setText("FULL")
      schedule(800, function()
        if not isDrinking and manaIconWidget and manaIconWidget.text then
          manaIconWidget.text:setText(target .. "%")
        end
      end)
    end
    return
  end

  isDrinking = true
  emptyAttempts = 0
  updateVisuals()

  local used = drinkOnce()
  if not used then
    emptyAttempts = emptyAttempts + 1
  end
end

local function createOrUpdateIcon()
  local gameMapPanel = modules.game_interface and modules.game_interface.getMapPanel()
  if not gameMapPanel then return end

  if not manaIconWidget then
    local oldWidget = gameMapPanel:getChildById("manaPotionFloatingIcon")
    if oldWidget then
      oldWidget:destroy()
    end
    manaIconWidget = g_ui.createWidget("QuickHealIconWidget", gameMapPanel)
    manaIconWidget:setId("manaPotionFloatingIcon")
    manaIconWidget.botWidget = true

    manaIconWidget:setMarginLeft(config.pos and config.pos.x or 20)
    manaIconWidget:setMarginTop(config.pos and config.pos.y or 30)
  end

  manaIconWidget.onMousePress = function(self, mousePos, mouseButton)
    if mouseButton == MouseLeftButton or mouseButton == 1 or not mouseButton then
      if not g_keyboard.isCtrlPressed() or not config.lockPosition then
        triggerManaHeal(true)
      end
    end
  end

  manaIconWidget.onMouseRelease = function(self, mousePos, mouseButton)
    if self.isBeingDragged then
      self.isBeingDragged = false
      return true
    end
    if mouseButton == MouseRightButton or mouseButton == 2 then
      triggerManaHeal(false)
      return true
    end
    if mouseButton == MouseLeftButton or mouseButton == 1 or not mouseButton then
      triggerManaHeal(true)
      return true
    end
  end

  manaIconWidget.onClick = function(self)
    triggerManaHeal(true)
  end

  manaIconWidget.onDragEnter = function(self, mousePos)
    if config.lockPosition and not g_keyboard.isCtrlPressed() then
      return false
    end
    self.movingReference = { x = mousePos.x - self:getX(), y = mousePos.y - self:getY() }
    self.isBeingDragged = true
    return true
  end

  manaIconWidget.onDragLeave = function(self)
    self.isBeingDragged = false
    return true
  end

  manaIconWidget.onDragMove = function(self, mousePos, moved)
    local parent = self:getParent()
    if not parent then return false end
    local parentRect = parent:getRect()
    local newX = math.min(math.max(parentRect.x + 5, mousePos.x - self.movingReference.x), parentRect.x + parentRect.width - self:getWidth() - 5)
    local newY = math.min(math.max(parentRect.y + 5, mousePos.y - self.movingReference.y), parentRect.y + parentRect.height - self:getHeight() - 5)

    local relX = newX - parentRect.x
    local relY = newY - parentRect.y

    self:setMarginLeft(relX)
    self:setMarginTop(relY)
    config.pos = { x = relX, y = relY }
    return true
  end

  updateVisuals()
end

createOrUpdateIcon()
if not manaIconWidget then
  schedule(400, function()
    createOrUpdateIcon()
  end)
end

-- UI inside the "Iconos" tab
local tabUi = setupUI([[
Panel
  height: 295

  BotSwitch
    id: enabledSwitch
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    text: Icono de Mana en Pantalla
    height: 20

  Label
    id: statusLabel
    anchors.top: prev.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    margin-top: 6
    text-align: center
    text: Mana Actual: 100% | Estado: Listo
    font: verdana-11px-rounded
    color: #60a5fa

  HorizontalSeparator
    id: sep1
    anchors.top: prev.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    margin-top: 6

  Panel
    id: rowTarget
    anchors.top: prev.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    margin-top: 6
    height: 22

    Label
      text: Llenar mana al:
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      font: verdana-11px-rounded

    Label
      text: %
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      margin-right: 2
      font: verdana-11px-rounded

    TextEdit
      id: targetPercent
      anchors.right: prev.left
      anchors.verticalCenter: parent.verticalCenter
      margin-right: 4
      width: 46
      font: verdana-11px-rounded
      text-align: center

  Panel
    id: rowItem
    anchors.top: prev.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    margin-top: 6
    height: 30

    Label
      text: Pocion a usar:
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      font: verdana-11px-rounded

    BotItem
      id: itemBox
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      size: 26 26

    Label
      text: ID:
      anchors.right: prev.left
      anchors.verticalCenter: parent.verticalCenter
      margin-right: 4
      font: verdana-11px-rounded

    TextEdit
      id: itemId
      anchors.right: prev.left
      anchors.verticalCenter: parent.verticalCenter
      margin-right: 4
      width: 50
      font: verdana-11px-rounded
      text-align: center

  Panel
    id: rowDelay
    anchors.top: prev.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    margin-top: 6
    height: 22

    Label
      text: Retardo (ms):
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      font: verdana-11px-rounded

    Label
      text: ms
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      margin-right: 2
      font: verdana-11px-rounded

    TextEdit
      id: delay
      anchors.right: prev.left
      anchors.verticalCenter: parent.verticalCenter
      margin-right: 4
      width: 46
      font: verdana-11px-rounded
      text-align: center

  HorizontalSeparator
    id: sep2
    anchors.top: prev.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    margin-top: 6

  BotSwitch
    id: autoMaintainSwitch
    anchors.top: prev.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    margin-top: 6
    text: Modo Auto (Mantener siempre)
    height: 18

  BotSwitch
    id: lockPositionSwitch
    anchors.top: prev.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    margin-top: 4
    text: Bloquear pos (Ctrl+Arrastrar)
    height: 18

  HorizontalSeparator
    id: sep3
    anchors.top: prev.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    margin-top: 6

  Button
    id: resetPosBtn
    anchors.top: prev.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    margin-top: 6
    height: 19
    text: Reiniciar Posicion (Top-Left)
    font: cipsoftFont

  Button
    id: testBtn
    anchors.top: prev.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    margin-top: 4
    height: 19
    text: Curar Mana Ahora (Llenar al %)
    font: cipsoftFont
]])

statusLabel = tabUi.statusLabel

tabUi.enabledSwitch:setOn(config.enabled)
tabUi.enabledSwitch.onClick = function(widget)
  config.enabled = not config.enabled
  widget:setOn(config.enabled)
  updateVisuals()
end

tabUi.autoMaintainSwitch:setOn(config.autoMaintain)
tabUi.autoMaintainSwitch.onClick = function(widget)
  config.autoMaintain = not config.autoMaintain
  widget:setOn(config.autoMaintain)
end

tabUi.lockPositionSwitch:setOn(config.lockPosition)
tabUi.lockPositionSwitch.onClick = function(widget)
  config.lockPosition = not config.lockPosition
  widget:setOn(config.lockPosition)
end

tabUi.rowTarget.targetPercent:setText(tostring(config.targetPercent or 90))
tabUi.rowTarget.targetPercent.onTextChange = function(widget, text)
  local num = tonumber(text)
  if num and num > 0 and num <= 100 then
    config.targetPercent = num
    updateVisuals()
  end
end

tabUi.rowDelay.delay:setText(tostring(config.delay or 250))
tabUi.rowDelay.delay.onTextChange = function(widget, text)
  local num = tonumber(text)
  if num and num >= 50 then
    config.delay = num
  end
end

local isSyncing = false

local function updateItemPreview(id)
  local num = tonumber(id)
  if num and num > 0 then
    local _, previewId = resolveItem(num)
    tabUi.rowItem.itemBox:setItemId(previewId or num)
  else
    tabUi.rowItem.itemBox:setItemId(0)
  end
end

tabUi.rowItem.itemId:setText(tostring(config.itemId or 438))
updateItemPreview(config.itemId or 438)

tabUi.rowItem.itemId.onTextChange = function(widget, text)
  if isSyncing then return end
  local num = tonumber(text)
  isSyncing = true
  if num and num > 0 then
    config.itemId = num
    updateItemPreview(num)
    updateVisuals()
  else
    tabUi.rowItem.itemBox:setItemId(0)
  end
  isSyncing = false
end

tabUi.rowItem.itemBox.onItemChange = function(widget)
  if isSyncing then return end
  local id = widget:getItemId()
  if id > 0 then
    isSyncing = true
    config.itemId = id
    tabUi.rowItem.itemId:setText(tostring(id))
    updateVisuals()
    isSyncing = false
  end
end

tabUi.resetPosBtn.onClick = function()
  config.pos = { x = 20, y = 30 }
  if manaIconWidget then
    manaIconWidget:setMarginLeft(20)
    manaIconWidget:setMarginTop(30)
  end
end

tabUi.testBtn.onClick = function()
  triggerManaHeal(true)
end

UI.Separator()
UI.Label("Clic en el icono: Llena el mana hasta el % configurado.")
UI.Separator()

-- Continuous healing loop - DOES NOT STOP until target % is reached!
macro(50, function()
  if not isDrinking and not config.autoMaintain then return end

  local target = tonumber(config.targetPercent) or 90
  local curMp = manapercent()

  if isDrinking then
    -- ONLY stop when target percentage is reached or exceeded!
    if curMp >= target then
      isDrinking = false
      emptyAttempts = 0
      updateVisuals()
      return
    end

    local used = drinkOnce()
    if not used then
      emptyAttempts = emptyAttempts + 1
      if emptyAttempts >= 8 then
        -- Out of potions
        isDrinking = false
        emptyAttempts = 0
        updateVisuals()
        return
      end
    else
      emptyAttempts = 0
    end

    updateVisuals()
    delay(tonumber(config.delay) or 250)
    return
  end

  if config.autoMaintain and curMp < target then
    drinkOnce()
    delay(tonumber(config.delay) or 250)
  end
end)

onManaChange(function(player, mana, maxMana, oldMana, oldMaxMana)
  if isDrinking then
    local target = tonumber(config.targetPercent) or 90
    if manapercent() >= target then
      isDrinking = false
      emptyAttempts = 0
    end
    updateVisuals()
  elseif manaIconWidget then
    updateVisuals()
  end
end)

-- =========================================================================
-- ICONO FLOTANTE DE CAVEBOT (ON / OFF)
-- =========================================================================

g_ui.loadUIFromString([[
CaveBotIconWidget < UIButton
  size: 46 46
  focusable: false
  phantom: false
  draggable: true
  background-color: #0b1526ee
  border-width: 1
  border-color: #22c55e
  anchors.left: parent.left
  anchors.top: parent.top
  margin-left: 75
  margin-top: 30

  $on:
    border-color: #22c55e
    background-color: #052e16ee

  $!on:
    border-color: #ef4444
    background-color: #450a0aee

  $hover:
    border-color: #86efac

  $pressed:
    border-color: #4ade80
    background-color: #166534ee

  UIItem
    id: item
    anchors.top: parent.top
    anchors.horizontalCenter: parent.horizontalCenter
    margin-top: 3
    virtual: true
    phantom: true
    size: 26 26

  UIWidget
    id: status
    anchors.top: parent.top
    anchors.right: parent.right
    size: 7 7
    margin-top: 3
    margin-right: 3
    background-color: #22c55e
    phantom: true

  Label
    id: text
    anchors.bottom: parent.bottom
    anchors.horizontalCenter: parent.horizontalCenter
    margin-bottom: 2
    font: terminus-10px
    color: #22c55e
    phantom: true
    text: ON

TargetIconWidget < UIButton
  size: 46 46
  focusable: false
  phantom: false
  draggable: true
  background-color: #0b1526ee
  border-width: 1
  border-color: #22c55e
  anchors.left: parent.left
  anchors.top: parent.top
  margin-left: 125
  margin-top: 30

  $on:
    border-color: #22c55e
    background-color: #052e16ee

  $!on:
    border-color: #ef4444
    background-color: #450a0aee

  $hover:
    border-color: #86efac

  $pressed:
    border-color: #4ade80
    background-color: #166534ee

  UIItem
    id: item
    anchors.top: parent.top
    anchors.horizontalCenter: parent.horizontalCenter
    margin-top: 3
    virtual: true
    phantom: true
    size: 26 26

  UIWidget
    id: status
    anchors.top: parent.top
    anchors.right: parent.right
    size: 7 7
    margin-top: 3
    margin-right: 3
    background-color: #22c55e
    phantom: true

  Label
    id: text
    anchors.bottom: parent.bottom
    anchors.horizontalCenter: parent.horizontalCenter
    margin-bottom: 2
    font: terminus-10px
    color: #22c55e
    phantom: true
    text: ON
]])

local cbPanelName = "caveBotIcon"
if not storage[cbPanelName] then
  storage[cbPanelName] = {
    enabled = true,
    itemId = 3079, -- Boots of Haste por defecto
    lockPosition = true,
    pos = { x = 75, y = 30 }
  }
end
local cbConfig = storage[cbPanelName]
if not cbConfig.pos then cbConfig.pos = { x = 75, y = 30 } end
if cbConfig.enabled == nil then cbConfig.enabled = true end
if not cbConfig.itemId then cbConfig.itemId = 3079 end
if cbConfig.lockPosition == nil then cbConfig.lockPosition = true end

local caveBotIconWidget = nil
local lastKnownCbState = nil

local function isCaveBotActive()
  if CaveBot and CaveBot.isOn then
    return CaveBot.isOn()
  end
  return false
end

local function updateCaveBotVisuals()
  if not caveBotIconWidget then return end

  if not cbConfig.enabled then
    caveBotIconWidget:hide()
    return
  end
  caveBotIconWidget:show()

  local isCbOn = isCaveBotActive()

  caveBotIconWidget:setOn(isCbOn)

  if caveBotIconWidget.item then
    caveBotIconWidget.item:setItemId(cbConfig.itemId or 3079)
  end

  if caveBotIconWidget.status then
    caveBotIconWidget.status:setBackgroundColor(isCbOn and "#22c55e" or "#ef4444")
  end

  if caveBotIconWidget.text then
    caveBotIconWidget.text:setText(isCbOn and "ON" or "OFF")
    caveBotIconWidget.text:setColor(isCbOn and "#22c55e" or "#ef4444")
  end

  caveBotIconWidget:setTooltip("CaveBot: " .. (isCbOn and "PRENDIDO (ON)" or "APAGADO (OFF)") .. "\nClic para alternar\nCtrl+Arrastrar para mover")
end

local function toggleCaveBot()
  if not CaveBot then return end
  if isCaveBotActive() then
    CaveBot.setOff()
  elseif CaveBot.setOn then
    CaveBot.setOn()
  end
  updateCaveBotVisuals()
end

local function createOrUpdateCaveBotIcon()
  local gameMapPanel = modules.game_interface and modules.game_interface.getMapPanel()
  if not gameMapPanel then return end

  if not caveBotIconWidget then
    local oldWidget = gameMapPanel:getChildById("caveBotFloatingIcon")
    if oldWidget then
      oldWidget:destroy()
    end
    caveBotIconWidget = g_ui.createWidget("CaveBotIconWidget", gameMapPanel)
    caveBotIconWidget:setId("caveBotFloatingIcon")
    caveBotIconWidget.botWidget = true

    caveBotIconWidget:setMarginLeft(cbConfig.pos and cbConfig.pos.x or 75)
    caveBotIconWidget:setMarginTop(cbConfig.pos and cbConfig.pos.y or 30)
  end

  caveBotIconWidget.onClick = function(self)
    toggleCaveBot()
  end

  caveBotIconWidget.onMouseRelease = function(self, mousePos, mouseButton)
    if self.isBeingDragged then
      self.isBeingDragged = false
      return true
    end
    if mouseButton == MouseLeftButton or mouseButton == 1 or not mouseButton then
      toggleCaveBot()
      return true
    end
  end

  caveBotIconWidget.onDragEnter = function(self, mousePos)
    if cbConfig.lockPosition and not g_keyboard.isCtrlPressed() then
      return false
    end
    self.movingReference = { x = mousePos.x - self:getX(), y = mousePos.y - self:getY() }
    self.isBeingDragged = true
    return true
  end

  caveBotIconWidget.onDragLeave = function(self)
    self.isBeingDragged = false
    return true
  end

  caveBotIconWidget.onDragMove = function(self, mousePos, moved)
    local parent = self:getParent()
    if not parent then return false end
    local parentRect = parent:getRect()
    local newX = math.min(math.max(parentRect.x + 5, mousePos.x - self.movingReference.x), parentRect.x + parentRect.width - self:getWidth() - 5)
    local newY = math.min(math.max(parentRect.y + 5, mousePos.y - self.movingReference.y), parentRect.y + parentRect.height - self:getHeight() - 5)

    local relX = newX - parentRect.x
    local relY = newY - parentRect.y

    self:setMarginLeft(relX)
    self:setMarginTop(relY)
    cbConfig.pos = { x = relX, y = relY }
    return true
  end

  updateCaveBotVisuals()
end

createOrUpdateCaveBotIcon()
if not caveBotIconWidget then
  schedule(400, function()
    createOrUpdateCaveBotIcon()
  end)
end

-- Monitoreo continuo del estado de CaveBot (sincroniza en 100ms si se prende o apaga desde la ventana del bot)
macro(100, function()
  if not caveBotIconWidget or not cbConfig.enabled then return end
  local current = isCaveBotActive()
  if current ~= lastKnownCbState then
    lastKnownCbState = current
    updateCaveBotVisuals()
  end
end)

-- Controles en la pestaña "Iconos"
UI.Separator()
UI.Label("--- Icono de CaveBot en Pantalla ---")

local cbSwitch = addSwitch("caveBotFloatingIconSwitch", "Icono de CaveBot Visible", function(widget)
  widget:setOn(not widget:isOn())
  cbConfig.enabled = widget:isOn()
  updateCaveBotVisuals()
end)
cbSwitch:setOn(cbConfig.enabled)

UI.Button("Reiniciar Posicion CaveBot (Top-Left)", function()
  cbConfig.pos = { x = 75, y = 30 }
  if caveBotIconWidget then
    caveBotIconWidget:setMarginLeft(75)
    caveBotIconWidget:setMarginTop(30)
  end
end)

UI.Label("Clic en el icono: Prende/Apaga CaveBot.\nSubleyenda: ON (verde) | OFF (rojo).")

-- =========================================================================
-- ICONO FLOTANTE DE TARGETS / ATAQUES (ON / OFF)
-- Colocado al lado del icono de CaveBot (BoH)
-- =========================================================================

local targetPanelName = "targetIcon"
if not storage[targetPanelName] then
  storage[targetPanelName] = {
    enabled = true,
    itemId = 3288, -- Magic Sword (ícono clásico de target/ataque)
    lockPosition = true,
    pos = { x = 125, y = 30 }
  }
end
local targetConfig = storage[targetPanelName]
if not targetConfig.pos then targetConfig.pos = { x = 125, y = 30 } end
if targetConfig.enabled == nil then targetConfig.enabled = true end
if not targetConfig.itemId then targetConfig.itemId = 3288 end
if targetConfig.lockPosition == nil then targetConfig.lockPosition = true end

local targetIconWidget = nil
local lastKnownTargetState = nil

local function isTargetsActive()
  local tbOn = (TargetBot and TargetBot.isOn and TargetBot.isOn()) or false
  local trOn = (storage["tirar_runa"] and storage["tirar_runa"].enabled) or false
  local abOn = (storage.AttackBot and storage.AttackBot.enabled) or false
  local sdOn = (storage["sd_only"] and storage["sd_only"].enabled) or false
  return (tbOn or trOn or abOn or sdOn)
end

local function updateTargetIconVisuals()
  if not targetIconWidget then return end

  if not targetConfig.enabled then
    targetIconWidget:hide()
    return
  end
  targetIconWidget:show()

  local isTgOn = isTargetsActive()
  targetIconWidget:setOn(isTgOn)

  if targetIconWidget.item then
    targetIconWidget.item:setItemId(targetConfig.itemId or 3288)
  end

  if targetIconWidget.status then
    targetIconWidget.status:setBackgroundColor(isTgOn and "#22c55e" or "#ef4444")
  end

  if targetIconWidget.text then
    targetIconWidget.text:setText(isTgOn and "ON" or "OFF")
    targetIconWidget.text:setColor(isTgOn and "#22c55e" or "#ef4444")
  end

  targetIconWidget:setTooltip("Target & Ataques: " .. (isTgOn and "PRENDIDO (ON)" or "APAGADO (OFF)") .. "\nClic para alternar todos los targets\nCtrl+Arrastrar para mover")
end

local function toggleTargets()
  local isCurrentlyOn = isTargetsActive()
  if isCurrentlyOn then
    -- APAGAR TODOS LOS TARGETS
    if TargetBot and TargetBot.setOff then
      TargetBot.setOff()
    end
    if storage["tirar_runa"] then
      storage["tirar_runa"].enabled = false
    end
    if storage["sd_only"] then
      storage["sd_only"].enabled = false
    end
    if storage.AttackBot then
      storage.AttackBot.enabled = false
    end
    g_game.cancelAttackAndFollow()
  else
    -- PRENDER TARGETS
    if TargetBot and TargetBot.setOn then
      TargetBot.setOn()
    end
    if storage["tirar_runa"] then
      storage["tirar_runa"].enabled = true
    end
  end
  updateTargetIconVisuals()
end

local function createOrUpdateTargetIcon()
  local gameMapPanel = modules.game_interface and modules.game_interface.getMapPanel()
  if not gameMapPanel then return end

  if not targetIconWidget then
    local oldWidget = gameMapPanel:getChildById("targetFloatingIcon")
    if oldWidget then
      oldWidget:destroy()
    end
    targetIconWidget = g_ui.createWidget("TargetIconWidget", gameMapPanel)
    targetIconWidget:setId("targetFloatingIcon")
    targetIconWidget.botWidget = true

    targetIconWidget:setMarginLeft(targetConfig.pos and targetConfig.pos.x or 125)
    targetIconWidget:setMarginTop(targetConfig.pos and targetConfig.pos.y or 30)
  end

  targetIconWidget.onClick = function(self)
    toggleTargets()
  end

  targetIconWidget.onMouseRelease = function(self, mousePos, mouseButton)
    if self.isBeingDragged then
      self.isBeingDragged = false
      return true
    end
    if mouseButton == MouseLeftButton or mouseButton == 1 or not mouseButton then
      toggleTargets()
      return true
    end
  end

  targetIconWidget.onDragEnter = function(self, mousePos)
    if targetConfig.lockPosition and not g_keyboard.isCtrlPressed() then
      return false
    end
    self.movingReference = { x = mousePos.x - self:getX(), y = mousePos.y - self:getY() }
    self.isBeingDragged = true
    return true
  end

  targetIconWidget.onDragLeave = function(self)
    self.isBeingDragged = false
    return true
  end

  targetIconWidget.onDragMove = function(self, mousePos, moved)
    local parent = self:getParent()
    if not parent then return false end
    local parentRect = parent:getRect()
    local newX = math.min(math.max(parentRect.x + 5, mousePos.x - self.movingReference.x), parentRect.x + parentRect.width - self:getWidth() - 5)
    local newY = math.min(math.max(parentRect.y + 5, mousePos.y - self.movingReference.y), parentRect.y + parentRect.height - self:getHeight() - 5)

    local relX = newX - parentRect.x
    local relY = newY - parentRect.y

    self:setMarginLeft(relX)
    self:setMarginTop(relY)
    targetConfig.pos = { x = relX, y = relY }
    return true
  end

  updateTargetIconVisuals()
end

createOrUpdateTargetIcon()
if not targetIconWidget then
  schedule(400, function()
    createOrUpdateTargetIcon()
  end)
end

-- Monitoreo continuo del estado de Targets (sincroniza en 100ms)
macro(100, function()
  if targetIconWidget and targetConfig.enabled then
    local currentTg = isTargetsActive()
    if currentTg ~= lastKnownTargetState then
      lastKnownTargetState = currentTg
      updateTargetIconVisuals()
    end
  end
end)

-- Controles en la pestaña "Iconos" para el icono de Targets
UI.Separator()
UI.Label("--- Icono de Targets en Pantalla ---")

local tgSwitch = addSwitch("targetFloatingIconSwitch", "Icono de Targets Visible", function(widget)
  widget:setOn(not widget:isOn())
  targetConfig.enabled = widget:isOn()
  updateTargetIconVisuals()
end)
tgSwitch:setOn(targetConfig.enabled)

UI.Button("Reiniciar Posicion Targets (Al lado de BoH)", function()
  targetConfig.pos = { x = 125, y = 30 }
  if targetIconWidget then
    targetIconWidget:setMarginLeft(125)
    targetIconWidget:setMarginTop(30)
  end
end)

UI.Label("Clic en el icono: Prende o Apaga todos los targets\n(TargetBot, Tirar Runa, AttackBot y cancela target)")

