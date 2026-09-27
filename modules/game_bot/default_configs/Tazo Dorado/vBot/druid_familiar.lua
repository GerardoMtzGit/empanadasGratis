local targetingTab = storage.extras and storage.extras.joinBot and "Cave" or "Target"
setDefaultTab(targetingTab)

local panelName = "druid_familiar"
if not storage[panelName] then
  storage[panelName] = {
    enabled = false,
    iconId = 172,
    cdDuration = 0,
    expireAt = 0,
    minMana = 1000
  }
end

local config = storage[panelName]
if config.enabled == nil then config.enabled = false end
if config.minMana == nil then config.minMana = 1000 end
if not config.iconId or config.iconId <= 0 then config.iconId = 172 end

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
    anchors.right: summonBtn.left
    margin-right: 4
    height: 20
    text-align: center
    text: Auto Druid Familiar

  Button
    id: summonBtn
    anchors.top: parent.top
    anchors.right: parent.right
    width: 55
    height: 20
    text: Invocar
    font: cipsoftFont
    tooltip: Forzar lanzamiento de utevo gran res dru ahora

  Label
    id: status
    anchors.top: prev.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    margin-top: 3
    font: cipsoftFont
    text-align: center
    color: #a0a0a0
    text: [OFF] Inactivo

  HorizontalSeparator
    anchors.top: prev.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    margin-top: 4
]])

ui.title:setOn(config.enabled)
ui.title.onClick = function(widget)
  config.enabled = not config.enabled
  widget:setOn(config.enabled)
end

local lastSpokenSpellTime = 0
local familiarCdEndMs = 0
local lastCastAttempt = 0

local function doCastSpell()
  local nowMs = now or g_clock.millis()
  lastCastAttempt = nowMs
  lastSpokenSpellTime = nowMs
  say("utevo gran res dru")
end

ui.summonBtn.onClick = function(widget)
  doCastSpell()
end

-- Detect when player casts utevo gran res dru
onTalk(function(name, level, mode, text, channelId, pos)
  if name == player:getName() then
    local t = tostring(text):lower():trim()
    if t == "utevo gran res dru" or t:find("utevo gran res dru") then
      lastSpokenSpellTime = now or g_clock.millis()
    end
  end
end)

-- Hook server spell cooldown packet
if onSpellCooldown then
  onSpellCooldown(function(iconId, duration)
    local nowMs = now or g_clock.millis()
    if lastSpokenSpellTime and (nowMs - lastSpokenSpellTime < 1200) then
      config.iconId = iconId
      config.cdDuration = duration
      config.expireAt = os.time() + math.ceil(duration / 1000)
      familiarCdEndMs = nowMs + duration
      if vBot and vBot.customCooldowns then
        vBot.customCooldowns["utevo gran res dru"] = { id = iconId, duration = duration }
      end
    elseif config.iconId and iconId == config.iconId then
      config.cdDuration = duration
      config.expireAt = os.time() + math.ceil(duration / 1000)
      familiarCdEndMs = nowMs + duration
    end
  end)
end

-- Check if druid familiar creature is present near player
local function isFamiliarPresent()
  local pPos = player:getPosition()
  if not pPos then return false end
  local specs = getSpectators(pPos.z)
  for _, spec in ipairs(specs) do
    local sName = ""
    pcall(function()
      if spec.getName then
        sName = tostring(spec:getName()):lower():trim()
      end
    end)

    local matchesName = (sName == "druid familiar" or sName:find("druid familiar") or sName == "grovebeast")
    if not matchesName and sName:find("familiar") then
      if spec.getMaster and spec:getMaster() and spec:getMaster():getId() == player:getId() then
        matchesName = true
      end
    end

    if matchesName then
      local isMine = false
      if spec.getMaster and spec:getMaster() then
        if spec:getMaster():getId() == player:getId() then
          isMine = true
        end
      else
        if getDistanceBetween(pPos, spec:getPosition()) <= 7 then
          isMine = true
        end
      end
      if isMine then
        return true
      end
    end
  end
  return false
end

-- Check remaining cooldown in seconds
local function getCooldownRemaining()
  local nowMs = now or g_clock.millis()
  local curTime = os.time()

  -- Check OTClient icon first if known
  if config.iconId and modules.game_cooldown and modules.game_cooldown.isCooldownIconActive then
    local active = modules.game_cooldown.isCooldownIconActive(config.iconId)
    if active == false and familiarCdEndMs > 0 and (nowMs - (familiarCdEndMs - (config.cdDuration or 0)) > 1500) then
      familiarCdEndMs = 0
      config.expireAt = 0
      return 0
    end
  end

  -- Check monotonic ms timer
  if familiarCdEndMs > nowMs then
    return math.ceil((familiarCdEndMs - nowMs) / 1000)
  end

  -- Check persistent wall-clock timestamp
  if config.expireAt and config.expireAt > curTime then
    return config.expireAt - curTime
  end

  -- Check getSpellCoolDown
  if getSpellCoolDown and getSpellCoolDown("utevo gran res dru") then
    return 1
  end

  return 0
end

-- Handle server messages regarding cooldown / exhaust
onTextMessage(function(mode, text)
  local low = tostring(text):lower()
  if low:find("familiar") or low:find("spell") or low:find("summon") then
    if low:find("wait") or low:find("exhaust") or low:find("cooldown") then
      local nowMs = now or g_clock.millis()
      lastCastAttempt = nowMs + 3000
      if getCooldownRemaining() <= 0 then
        local dur = (config.cdDuration and config.cdDuration > 0) and config.cdDuration or 900000
        familiarCdEndMs = nowMs + dur
        config.expireAt = os.time() + math.ceil(dur / 1000)
      end
    end
  end
end)

-- Main logic macro
macro(300, function()
  if ui.title:isOn() ~= config.enabled then
    ui.title:setOn(config.enabled)
  end

  if not config.enabled then
    ui.status:setText("[OFF] Inactivo")
    ui.status:setColor("#a0a0a0")
    return
  end

  local famPresent = isFamiliarPresent()
  local cdRemaining = getCooldownRemaining()

  if famPresent then
    if cdRemaining > 0 then
      local m = math.floor(cdRemaining / 60)
      local s = cdRemaining % 60
      ui.status:setText(string.format("[ON] Presente | CD: %02d:%02d", m, s))
      ui.status:setColor("#2ecc71")
    else
      ui.status:setText("[ON] Druida Familiar Presente")
      ui.status:setColor("#2ecc71")
    end
    return
  end

  if cdRemaining > 0 then
    local m = math.floor(cdRemaining / 60)
    local s = cdRemaining % 60
    ui.status:setText(string.format("[ON] Cooldown: %02d:%02d", m, s))
    ui.status:setColor("#e67e22")
    return
  end

  -- Cooldown completed and familiar not present
  if isInPz() then
    ui.status:setText("[ON] En PZ (Pausa)")
    ui.status:setColor("#f1c40f")
    return
  end

  local curMana = mana()
  local maxM = maxmana()
  local minM = config.minMana or 1000
  if curMana < minM and manapercent() < 25 and curMana < maxM then
    ui.status:setText(string.format("[ON] Esperando Mana (%d/%d)", curMana, minM))
    ui.status:setColor("#e74c3c")
    return
  end

  local nowMs = now or g_clock.millis()
  if nowMs - lastCastAttempt < 4000 then
    ui.status:setText("[ON] Invocando...")
    ui.status:setColor("#3498db")
    return
  end

  ui.status:setText("[ON] Invocando Familiar...")
  ui.status:setColor("#3498db")
  doCastSpell()
end)
