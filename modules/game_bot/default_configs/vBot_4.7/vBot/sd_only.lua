-- Script: SD Only Mode (Icono Flotante en Pantalla)
-- Al activarse, APAGA todas las funciones de ataque (TargetBot, AttackBot, Tirar Runa, etc.)
-- y SOLO dispara Sudden Death (SD) a maxima velocidad contra el objetivo.
-- Al desactivarse, reanuda automaticamente todas las funciones de ataque normales.

local panelName = "sdOnly"
if not storage[panelName] then
  storage[panelName] = {
    enabled = false,
    pos = { x = 72, y = 30 },
    delay = 200,
    autoTarget = true,
    maxRange = 7,
    lockPosition = true,
    visible = true
  }
end
local config = storage[panelName]
if not config.pos then config.pos = { x = 72, y = 30 } end
if config.delay == nil then config.delay = 200 end
if config.autoTarget == nil then config.autoTarget = true end
if config.maxRange == nil then config.maxRange = 7 end
if config.lockPosition == nil then config.lockPosition = true end
if config.visible == nil then config.visible = true end

local sdIconWidget = nil
local tabUi = nil
local lastSdCast = 0

-- Funcion confiable de disparo de SD (soporta ID cliente 3155 e ID servidor 2268)
local function shootSdRune(targetThing)
  if not targetThing then return false end
  if targetThing.isCreature and targetThing:isCreature() then
    local p = targetThing:getPosition()
    if not p or p.z ~= posz() or targetThing:getHealthPercent() <= 0 then
      return false
    end
  end

  local subType = (g_game.getClientVersion and g_game.getClientVersion() >= 860) and 0 or 1
  local itemInBp = findItem(3155) or findItem(2268)

  -- 1. Si esta en mochilas abiertas, usar directamente
  if itemInBp then
    local ok = false
    pcall(function()
      g_game.useWith(itemInBp, targetThing, subType)
      ok = true
    end)
    if ok then return true end
  end

  -- 2. Disparo por hotkey / inventario con ID de cliente (3155)
  local ok = false
  pcall(function()
    g_game.useInventoryItemWith(3155, targetThing, subType)
    ok = true
  end)

  -- 3. Disparo por hotkey / inventario con ID de servidor (2268)
  if not ok then
    pcall(function()
      g_game.useInventoryItemWith(2268, targetThing, subType)
      ok = true
    end)
  end

  return ok
end

local function updateVisuals()
  local isAct = config.enabled

  if sdIconWidget then
    sdIconWidget:setVisible(config.visible ~= false)
    sdIconWidget:setOn(isAct)
    if sdIconWidget.item then
      sdIconWidget.item:setItemId(3155)
    end

    if isAct then
      sdIconWidget:setBorderColor("#22c55e")
      sdIconWidget:setBackgroundColor("#14532dee")
      if sdIconWidget.status then sdIconWidget.status:setBackgroundColor("#22c55e") end
      if sdIconWidget.text then
        sdIconWidget.text:setColor("#86efac")
        sdIconWidget.text:setText("SD ON")
      end
      sdIconWidget:setTooltip("Modo SD ONLY [ACTIVO]\n" ..
                              "Todas las demas funciones de ataque estan APAGADAS.\n" ..
                              "Disparando SD al objetivo a maxima velocidad.\n" ..
                              "Clic: Desactivar y reanudar ataques normales.\n" ..
                              "Ctrl + Arrastrar para mover")
    else
      sdIconWidget:setBorderColor("#ef4444")
      sdIconWidget:setBackgroundColor("#0b1526ee")
      if sdIconWidget.status then sdIconWidget.status:setBackgroundColor("#ef4444") end
      if sdIconWidget.text then
        sdIconWidget.text:setColor("#fca5a5")
        sdIconWidget.text:setText("SD ONLY")
      end
      sdIconWidget:setTooltip("Modo SD ONLY [DESACTIVADO]\n" ..
                              "Ataques normales activos.\n" ..
                              "Clic: ACTIVAR (Apagar otros ataques y solo tirar SD).\n" ..
                              "Ctrl + Arrastrar para mover")
    end
  end

  if tabUi then
    tabUi.enabledSwitch:setOn(isAct)
    if isAct then
      tabUi.statusLabel:setText("Estado: ACTIVO (Solo tirando SD a maxima velocidad)")
      tabUi.statusLabel:setColor("#22c55e")
    else
      tabUi.statusLabel:setText("Estado: DESACTIVADO (Ataques normales activos)")
      tabUi.statusLabel:setColor("#f87171")
    end
  end
end

local function toggleSdOnly(forceVal)
  if forceVal ~= nil then
    config.enabled = forceVal
  else
    config.enabled = not config.enabled
  end

  updateVisuals()

  if config.enabled then
    if modules.game_textmessage and modules.game_textmessage.displayStatusMessage then
      modules.game_textmessage.displayStatusMessage("[SD ONLY] ACTIVO: Todos los demas ataques apagados, disparando solo SD.")
    end
  else
    if modules.game_textmessage and modules.game_textmessage.displayStatusMessage then
      modules.game_textmessage.displayStatusMessage("[SD ONLY] DESACTIVADO: Ataques normales reanudados.")
    end
  end
end

g_ui.loadUIFromString([[
SdIconWidget < UIButton
  size: 46 46
  focusable: false
  phantom: false
  draggable: true
  background-color: #0b1526ee
  border-width: 1
  border-color: #ef4444
  anchors.left: parent.left
  anchors.top: parent.top
  margin-left: 72
  margin-top: 30

  $on:
    border-color: #22c55e
    background-color: #14532dee

  $hover:
    border-color: #f87171
    background-color: #111e38ee

  $pressed:
    border-color: #22c55e
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
    background-color: #ef4444
    phantom: true

  Label
    id: text
    anchors.bottom: parent.bottom
    anchors.horizontalCenter: parent.horizontalCenter
    margin-bottom: 2
    font: terminus-10px
    color: #fca5a5
    phantom: true
    text: SD ONLY
]])

-- Creacion y control del icono flotante en pantalla
local function createOrUpdateIcon()
  local gameMapPanel = modules.game_interface and modules.game_interface.getMapPanel()
  if not gameMapPanel then return end

  if not sdIconWidget then
    local oldWidget = gameMapPanel:getChildById("sdOnlyFloatingIcon")
    if oldWidget then
      oldWidget:destroy()
    end
    sdIconWidget = g_ui.createWidget("SdIconWidget", gameMapPanel)
    if not sdIconWidget then return end
    sdIconWidget:setId("sdOnlyFloatingIcon")
    sdIconWidget.botWidget = true

    sdIconWidget:setMarginLeft(config.pos and config.pos.x or 72)
    sdIconWidget:setMarginTop(config.pos and config.pos.y or 30)
  end

  sdIconWidget.onMousePress = function(self, mousePos, mouseButton)
    if mouseButton == MouseLeftButton or mouseButton == 1 or not mouseButton then
      if not g_keyboard.isCtrlPressed() or not config.lockPosition then
        -- Click sin Ctrl
      end
    end
  end

  sdIconWidget.onMouseRelease = function(self, mousePos, mouseButton)
    if self.isBeingDragged then
      self.isBeingDragged = false
      return true
    end
    toggleSdOnly()
    return true
  end

  sdIconWidget.onClick = function(self)
    toggleSdOnly()
  end

  sdIconWidget.onDragEnter = function(self, mousePos)
    if config.lockPosition and not g_keyboard.isCtrlPressed() then
      return false
    end
    self.movingReference = { x = mousePos.x - self:getX(), y = mousePos.y - self:getY() }
    self.isBeingDragged = true
    return true
  end

  sdIconWidget.onDragLeave = function(self)
    self.isBeingDragged = false
    return true
  end

  sdIconWidget.onDragMove = function(self, mousePos, moved)
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
if not sdIconWidget then
  schedule(400, function()
    createOrUpdateIcon()
  end)
end

-- Interfaz en la tab "Iconos"
setDefaultTab("Iconos")
UI.Separator()
UI.Label("-- [[ Modo SD ONLY (Icono en Pantalla) ]] --")

tabUi = setupUI([[
Panel
  height: 125

  BotSwitch
    id: enabledSwitch
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    text: Activar Modo SD Only (Solo Tirar SD)
    height: 20

  Label
    id: statusLabel
    anchors.top: prev.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    margin-top: 4
    text-align: center
    text: Estado: DESACTIVADO (Ataques normales activos)
    font: verdana-11px-rounded
    color: #f87171

  HorizontalSeparator
    id: sep1
    anchors.top: prev.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    margin-top: 4

  Panel
    id: rowConfig
    anchors.top: prev.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    margin-top: 4
    height: 22

    Label
      text: Retardo (ms):
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      font: verdana-11px-rounded

    TextEdit
      id: delay
      anchors.left: prev.right
      anchors.verticalCenter: parent.verticalCenter
      margin-left: 6
      width: 45
      text: 200
      font: verdana-11px-rounded
      text-align: center

    CheckBox
      id: autoTarget
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      text: Auto-Target
      font: cipsoftFont

  Button
    id: resetPosBtn
    anchors.top: prev.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    margin-top: 6
    height: 19
    text: Reiniciar Posicion del Icono SD
    font: cipsoftFont

  Button
    id: toggleBtn
    anchors.top: prev.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    margin-top: 4
    height: 19
    text: Alternar SD Only (ON / OFF)
    font: cipsoftFont
]])

tabUi.enabledSwitch:setOn(config.enabled)
tabUi.enabledSwitch.onClick = function()
  toggleSdOnly()
end

tabUi.rowConfig.delay:setText(tostring(config.delay or 200))
tabUi.rowConfig.delay.onTextChange = function(widget, text)
  local num = tonumber(text:trim())
  if num and num >= 50 then
    config.delay = num
  end
end

tabUi.rowConfig.autoTarget:setChecked(config.autoTarget ~= false)
tabUi.rowConfig.autoTarget.onClick = function(widget)
  config.autoTarget = not config.autoTarget
  widget:setChecked(config.autoTarget)
end

tabUi.resetPosBtn.onClick = function()
  config.pos = { x = 72, y = 30 }
  if sdIconWidget then
    sdIconWidget:setMarginLeft(72)
    sdIconWidget:setMarginTop(30)
  end
end

tabUi.toggleBtn.onClick = function()
  toggleSdOnly()
end

updateVisuals()

-- Macro de disparo prioritario continuo de SD
macro(20, function()
  if not config.enabled then return end
  if isInPz() then return end

  local currentNow = now
  local delayMs = tonumber(config.delay) or 200
  if lastSdCast + delayMs > currentNow then return end

  local playerPos = pos()
  local pz = playerPos.z

  -- 1. Buscar objetivo atacado actualmente
  local targetThing = g_game.getAttackingCreature()
  if targetThing then
    if isIgnoredSummonOrFamiliar and isIgnoredSummonOrFamiliar(targetThing) then
      g_game.cancelAttackAndFollow()
      targetThing = nil
    else
      local tPos = targetThing:getPosition()
      if not tPos or tPos.z ~= pz or targetThing:getHealthPercent() <= 0 then
        targetThing = nil
      end
    end
  end

  -- 2. Si no hay objetivo atacado y autoTarget esta activo, buscar el monstruo vivo mas cercano
  if not targetThing and config.autoTarget then
    local closestDist = 999
    local closestMonster = nil
    for _, spec in ipairs(getSpectators()) do
      if spec and not spec:isLocalPlayer() and not spec:isPlayer() and not spec:isNpc() and not (isIgnoredSummonOrFamiliar and isIgnoredSummonOrFamiliar(spec)) then
        local hp = spec:getHealthPercent()
        local sp = spec:getPosition()
        if hp and hp > 0 and sp and sp.z == pz then
          local dist = getDistanceBetween(playerPos, sp)
          if dist < closestDist and dist <= (config.maxRange or 7) then
            closestDist = dist
            closestMonster = spec
          end
        end
      end
    end
    if closestMonster then
      targetThing = closestMonster
      g_game.attack(closestMonster)
    end
  end

  if not targetThing then return end

  -- Mantener el ataque activo
  if g_game.getAttackingCreature() ~= targetThing then
    g_game.attack(targetThing)
  end

  local tPos = targetThing:getPosition()
  if not tPos or tPos.z ~= pz or targetThing:getHealthPercent() <= 0 then
    return
  end

  local dist = getDistanceBetween(playerPos, tPos)
  if dist > (config.maxRange or 7) then
    return
  end

  local tile = g_map.getTile(tPos)
  if tile and not tile:canShoot() then
    return
  end

  if shootSdRune(targetThing) then
    lastSdCast = currentNow
  end
end)
