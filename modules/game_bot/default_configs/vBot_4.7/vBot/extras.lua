-- Permanent NumPad movement protection and walk polyfill
local function polyfillWalking(m)
  if not m then return end
  local dummy = function(...) return true end
  if not m.unbindTurnKeys then m.unbindTurnKeys = dummy end
  if not m.bindTurnKeys then m.bindTurnKeys = dummy end
  if not m.unbindTurnKey then m.unbindTurnKey = dummy end
  if not m.bindTurnKey then m.bindTurnKey = dummy end
  if not m.unbindWalkKeys then m.unbindWalkKeys = dummy end
  if not m.bindWalkKeys then m.bindWalkKeys = dummy end
  if not m.unbindWalkKey then m.unbindWalkKey = dummy end
  if not m.bindWalkKey then m.bindWalkKey = dummy end
  if not m.bindKeys then m.bindKeys = dummy end
  if not m.unbindKeys then m.unbindKeys = dummy end
  if not m.enableWSAD then m.enableWSAD = dummy end
  if not m.disableWSAD then m.disableWSAD = dummy end
end

local numpadKeysList = {
  "Numpad0", "Numpad1", "Numpad2", "Numpad3", "Numpad4",
  "Numpad5", "Numpad6", "Numpad7", "Numpad8", "Numpad9",
  "NumLock", "Numpad.", "Numpad+", "Numpad-", "Numpad*", "Numpad/"
}

local function isNumpadKeyString(key)
  if not key or type(key) ~= "string" then return false end
  local lk = key:lower()
  return lk:find("numpad") ~= nil or lk:find("num") ~= nil
end

local function cleanNumpadWalking(m)
  if not m then return end
  if not m.__origBindWalkKey then
    m.__origBindWalkKey = m.bindWalkKey or function() end
  end
  m.bindWalkKey = function(key, dir, ...)
    if isNumpadKeyString(key) then return end
    return m.__origBindWalkKey(key, dir, ...)
  end
  if not m.__origBindTurnKey then
    m.__origBindTurnKey = m.bindTurnKey or function() end
  end
  m.bindTurnKey = function(key, dir, ...)
    if isNumpadKeyString(key) then return end
    return m.__origBindTurnKey(key, dir, ...)
  end
  m.bindKeys = function()
    if m.bindWalkKey then
      m.bindWalkKey('Up', North)
      m.bindWalkKey('Right', East)
      m.bindWalkKey('Down', South)
      m.bindWalkKey('Left', West)
    end
    if m.bindTurnKey then
      m.bindTurnKey('Ctrl+Up', North)
      m.bindTurnKey('Ctrl+Right', East)
      m.bindTurnKey('Ctrl+Down', South)
      m.bindTurnKey('Ctrl+Left', West)
    end
  end
  if m.walkKeys and type(m.walkKeys) == "table" then
    for k, _ in pairs(m.walkKeys) do
      if isNumpadKeyString(k) then m.walkKeys[k] = nil end
    end
  end
  for _, key in ipairs(numpadKeysList) do
    if m.unbindWalkKey then pcall(m.unbindWalkKey, key) end
    if m.unbindTurnKey then
      pcall(m.unbindTurnKey, key)
      pcall(m.unbindTurnKey, "Ctrl+" .. key)
      pcall(m.unbindTurnKey, "Shift+" .. key)
      pcall(m.unbindTurnKey, "Alt+" .. key)
    end
  end
end

if modules.game_walk then
  polyfillWalking(modules.game_walk)
  cleanNumpadWalking(modules.game_walk)
end
if not modules.game_walking then
  modules.game_walking = modules.game_walk or {}
end
polyfillWalking(modules.game_walking)
cleanNumpadWalking(modules.game_walking)
local walkingMod = modules.game_walking or modules.game_walk

setDefaultTab("Main")

-- securing storage namespace
local panelName = "extras"
if not storage[panelName] then
  storage[panelName] = {}
end
local settings = storage[panelName]

-- basic elements
extrasWindow = UI.createWindow('ExtrasWindow', rootWidget)
extrasWindow:hide()
extrasWindow.closeButton.onClick = function(widget)
  extrasWindow:hide()
end

extrasWindow.onGeometryChange = function(widget, old, new)
  if old.height == 0 then return end
  
  settings.height = new.height
end

extrasWindow:setHeight(settings.height or 360)

-- available options for dest param
local rightPanel = extrasWindow.content.right
local leftPanel = extrasWindow.content.left

-- objects made by Kondrah - taken from creature editor, minor changes to adapt
local addCheckBox = function(id, title, defaultValue, dest, tooltip)
  local widget = UI.createWidget('ExtrasCheckBox', dest)
  widget.onClick = function()
    widget:setOn(not widget:isOn())
    settings[id] = widget:isOn()
    if id == "checkPlayer" then
      local label = rootWidget.newHealer.targetSettings.vocations.title
      if not widget:isOn() then
        label:setColor("#d9321f")
        label:setTooltip("! WARNING ! \nTurn on check players in extras to use this feature!")
      else
          label:setColor("#dfdfdf")
          label:setTooltip("")
      end
    end
  end
  widget:setText(title)
  widget:setTooltip(tooltip)
  if settings[id] == nil then
    widget:setOn(defaultValue)
  else
    widget:setOn(settings[id])
  end
  settings[id] = widget:isOn()
end

local addItem = function(id, title, defaultItem, dest, tooltip)
  local widget = UI.createWidget('ExtrasItem', dest)
  widget.text:setText(title)
  widget.text:setTooltip(tooltip)
  widget.item:setTooltip(tooltip)
  widget.item:setItemId(settings[id] or defaultItem)
  widget.item.onItemChange = function(widget)
    settings[id] = widget:getItemId()
  end
  settings[id] = settings[id] or defaultItem
end

local addTextEdit = function(id, title, defaultValue, dest, tooltip)
  local widget = UI.createWidget('ExtrasTextEdit', dest)
  widget.text:setText(title)
  widget.textEdit:setText(settings[id] or defaultValue or "")
  widget.text:setTooltip(tooltip)
  widget.textEdit.onTextChange = function(widget,text)
    settings[id] = text
  end
  settings[id] = settings[id] or defaultValue or ""
end

local addScrollBar = function(id, title, min, max, defaultValue, dest, tooltip)
  local widget = UI.createWidget('ExtrasScrollBar', dest)
  widget.text:setTooltip(tooltip)
  widget.scroll.onValueChange = function(scroll, value)
    widget.text:setText(title .. ": " .. value)
    if value == 0 then
      value = 1
    end
    settings[id] = value
  end
  widget.scroll:setRange(min, max)
  widget.scroll:setTooltip(tooltip)
  if max-min > 1000 then
    widget.scroll:setStep(100)
  elseif max-min > 100 then
    widget.scroll:setStep(10)
  end
  widget.scroll:setValue(settings[id] or defaultValue)
  widget.scroll.onValueChange(widget.scroll, widget.scroll:getValue())
end

UI.Button("vBot Settings and Scripts", function()
  extrasWindow:show()
  extrasWindow:raise()
  extrasWindow:focus()
end)
UI.Separator()

---- to maintain order, add options right after another:
--- add object
--- add variables for function (optional)
--- add callback (optional)
--- optionals should be addionaly sandboxed (if true then end)

addItem("rope", "Rope Item", 9596, leftPanel, "This item will be used in various bot related scripts as default rope item.")
addItem("shovel", "Shovel Item", 9596, leftPanel, "This item will be used in various bot related scripts as default shovel item.")
addItem("machete", "Machete Item", 9596, leftPanel, "This item will be used in various bot related scripts as default machete item.")
addItem("scythe", "Scythe Item", 9596, leftPanel, "This item will be used in various bot related scripts as default scythe item.")
addCheckBox("pathfinding", "CaveBot Pathfinding", true, leftPanel, "Cavebot will automatically search for first reachable waypoint after missing 10 goto's.")
addScrollBar("talkDelay", "Global NPC Talk Delay", 0, 2000, 1000, leftPanel, "Breaks between each talk action in cavebot (time in miliseconds).")
addScrollBar("looting", "Max Loot Distance", 0, 50, 40, leftPanel, "Every loot corpse futher than set distance (in sqm) will be ignored and forgotten.")
addScrollBar("lootDelay", "Loot Delay", 0, 1000, 200, leftPanel, "Wait time for loot container to open. Lower value means faster looting. \n WARNING if you are having looting issues(e.g. container is locked in closing/opnening), increase this value.")
addScrollBar("huntRoutes", "Hunting Rounds Limit", 0, 300, 50, leftPanel, "Round limit for supply check, if character already made more rounds than set, on next supply check will return to city.")
addScrollBar("killUnder", "Kill monsters below", 0, 100, 1, leftPanel, "Force TargetBot to kill added creatures when they are below set percentage of health - will ignore all other TargetBot settings.")
addScrollBar("gotoMaxDistance", "Max GoTo Distance", 0, 127, 30, leftPanel, "Maximum distance to next goto waypoint for the bot to try to reach.")
addCheckBox("lootLast", "Start loot from last corpse", true, leftPanel, "Looting sequence will be reverted and bot will start looting newest bodies.")
addCheckBox("joinBot", "Join TargetBot and CaveBot", false, leftPanel, "Cave and Target tabs will be joined into one.")
addCheckBox("reachable", "Target only pathable mobs", false, leftPanel, "Ignore monsters that can't be reached.")

addCheckBox("title", "Custom Window Title", true, rightPanel, "Personalize OTCv8 window name according to character specific.")
if true then
  local vocText = ""

  if voc() == 1 or voc() == 11 then
      vocText = "- EK"
  elseif voc() == 2 or voc() == 12 then
      vocText = "- RP"
  elseif voc() == 3 or voc() == 13 then
      vocText = "- MS"
  elseif voc() == 4 or voc() == 14 then
      vocText = "- ED"
  end

  macro(5000, function()
    if settings.title then
      if hppercent() > 0 then
          g_window.setTitle("Tibia - " .. name() .. " - " .. lvl() .. "lvl " .. vocText)
      else
          g_window.setTitle("Tibia - " .. name() .. " - DEAD")
      end
    else
      g_window.setTitle("Tibia - " .. name())
    end
  end)
end

addCheckBox("separatePm", "Open PM's in new Window", false, rightPanel, "PM's will be automatically opened in new tab after receiving one.")
if true then
  onTalk(function(name, level, mode, text, channelId, pos)
    if mode == 4 and settings.separatePm then
        local g_console = modules.game_console
        local privateTab = g_console.getTab(name)
        if privateTab == nil then
            privateTab = g_console.addTab(name, true)
            g_console.addPrivateText(g_console.applyMessagePrefixies(name, level, text), g_console.SpeakTypesSettings['private'], name, false, name)
        end
        return
    end
  end)
end

addTextEdit("useAll", "Use All Hotkey", "space", rightPanel, "Set hotkey for universal actions - rope, shovel, scythe, use, open doors")
if true then
  local useId = { 34847, 1764, 21051, 30823, 6264, 5282, 20453, 20454, 20474, 11708, 11705, 
                  6257, 6256, 2772, 27260, 2773, 1632, 1633, 1948, 435, 6252, 6253, 5007, 4911, 
                  1629, 1630, 5108, 5107, 5281, 1968, 435, 1948, 5542, 31116, 31120, 30742, 31115, 
                  31118, 20474, 5737, 5736, 5734, 5733, 31202, 31228, 31199, 31200, 33262, 30824, 
                  5125, 5126, 5116, 5117, 8257, 8258, 8255, 8256, 5120, 30777, 30776, 23873, 23877,
                  5736, 6264, 31262, 31130, 31129, 6250, 6249, 5122, 30049, 7131, 7132, 7727 }
  local shovelId = { 606, 593, 867, 608 }
  local ropeId = { 17238, 12202, 12935, 386, 421, 21966, 14238 }
  local macheteId = { 2130, 3696 }
  local scytheId = { 3653 }

  setDefaultTab("Tools")
  -- script
  if settings.useAll and settings.useAll:len() > 0 then
    hotkey(settings.useAll, function()
        local _w = modules.game_walking or modules.game_walk; if not _w or not _w.wsadWalking then return end
        for _, tile in pairs(g_map.getTiles(posz())) do
            if distanceFromPlayer(tile:getPosition()) < 2 then
                for _, item in pairs(tile:getItems()) do
                    -- use
                    if table.find(useId, item:getId()) then
                        use(item)
                        return
                    elseif table.find(shovelId, item:getId()) then
                        useWith(settings.shovel, item)
                        return
                    elseif table.find(ropeId, item:getId()) then
                        useWith(settings.rope, item) 
                        return
                    elseif table.find(macheteId, item:getId()) then
                        useWith(settings.machete, item)
                        return
                    elseif table.find(scytheId, item:getId()) then
                        useWith(settings.scythe, item)
                        return
                    end
                end
            end
        end
    end)
  end
end


addCheckBox("timers", "MW & WG Timers", true, rightPanel, "Show times for Magic Walls and Wild Growths.")
if true then
  local activeTimers = {}
  local mwTimers = {
    [2128] = 20000,
    [2129] = 20000,
    [1497] = 20000,
    [1498] = 20000
  }
  local wgTimers = {
    [2130] = 40000,
    [2982] = 40000,
    [1499] = 40000,
    [2131] = 40000
  }

  onAddThing(function(tile, thing)
    if settings.timers == false then return end
    if not thing:isItem() then
      return
    end
    local itemId = thing:getId()
    local timer = mwTimers[itemId] or wgTimers[itemId]
    if not timer then
      return
    end

    local pos = tile:getPosition().x .. "," .. tile:getPosition().y .. "," .. tile:getPosition().z
    if not activeTimers[pos] or activeTimers[pos] < now then    
      activeTimers[pos] = now + timer
    end
    tile:setTimer(activeTimers[pos] - now)
  end)

  onRemoveThing(function(tile, thing)
    if settings.timers == false then return end
    if not thing:isItem() then
      return
    end
    local itemId = thing:getId()
    if (mwTimers[itemId] or wgTimers[itemId]) and tile:getGround() then
      local pos = tile:getPosition().x .. "," .. tile:getPosition().y .. "," .. tile:getPosition().z
      activeTimers[pos] = nil
      tile:setTimer(0)
    end  
  end)
end


addCheckBox("antiKick", "Anti - Kick", true, rightPanel, "Turn every 10 minutes to prevent kick.")
if true then
  macro(600*1000, function()
    if not settings.antiKick then return end
    local dir = player:getDirection()
    turn((dir + 1) % 4)
    schedule(50, function() turn(dir) end)
  end)
end


addCheckBox("stake", "Skin Monsters", false, leftPanel, "Automatically skin & stake corpses when cavebot is enabled")
if true then
  local knifeBodies = {4286, 4272, 4173, 4011, 4025, 4047, 4052, 4057, 4062, 4112, 4212, 4321, 4324, 4327, 10352, 10356, 10360, 10364} 
  local stakeBodies = {4097, 4137, 8738, 18958}
  local fishingBodies = {9582}
  macro(500, function()
      if not CaveBot.isOn() or not settings.stake then return end
      for i, tile in ipairs(g_map.getTiles(posz())) do
        local item = tile:getTopThing()
        if item and item:isContainer() then
          if table.find(knifeBodies, item:getId()) and findItem(5908) then
              CaveBot.delay(550)
              useWith(5908, item)
              return
          end
          if table.find(stakeBodies, item:getId()) and findItem(5942) then
              CaveBot.delay(550)
              useWith(5942, item)
              return
          end
          if table.find(fishingBodies, item:getId()) and findItem(3483) then
              CaveBot.delay(550)
              useWith(3483, item)
              return
          end
        end
      end
  end)
end


addCheckBox("oberon", "Auto Reply Oberon", true, rightPanel, "Auto reply to Grand Master Oberon talk minigame.")
if true then
  onTalk(function(name, level, mode, text, channelId, pos)
    if not settings.oberon then return end
    if mode == 34 then
        if string.find(text, "world will suffer for") then
            say("Are you ever going to fight or do you prefer talking?")
        elseif string.find(text, "feet when they see me") then
            say("Even before they smell your breath?")
        elseif string.find(text, "from this plane") then
            say("Too bad you barely exist at all!") 
        elseif string.find(text, "ESDO LO") then
            say("SEHWO ASIMO, TOLIDO ESD") 
        elseif string.find(text, "will soon rule this world") then
            say("Excuse me but I still do not get the message!") 
        elseif string.find(text, "honourable and formidable") then
            say("Then why are we fighting alone right now?") 
        elseif string.find(text, "appear like a worm") then
            say("How appropriate, you look like something worms already got the better of!") 
        elseif string.find(text, "will be the end of mortal") then
            say("Then let me show you the concept of mortality before it!") 
        elseif string.find(text, "virtues of chivalry") then
            say("Dare strike up a Minnesang and you will receive your last accolade!") 
        end
    end
  end)
end


addCheckBox("autoOpenDoors", "Auto Open Doors", true, rightPanel, "Open doors when trying to step on them.")
if true then
  local doorsIds = { 5007, 8265, 1629, 1632, 5129, 6252, 6249, 7715, 7712, 7714, 
                     7719, 6256, 1669, 1672, 5125, 5115, 5124, 17701, 17710, 1642, 
                     6260, 5107, 4912, 6251, 5291, 1683, 1696, 1692, 5006, 2179, 5116, 
                     1632, 11705, 30772, 30774, 6248, 5735, 5732, 5120, 23873, 5736,
                     6264, 5122, 30049, 30042, 7727 }

  function checkForDoors(pos)
    local tile = g_map.getTile(pos)
    if tile then
      local useThing = tile:getTopUseThing()
      if useThing and table.find(doorsIds, useThing:getId()) then
        g_game.use(useThing)
      end
    end
  end

  onKeyPress(function(keys)
    local _w = modules.game_walking or modules.game_walk; local wsadWalking = _w and _w.wsadWalking
    if not settings.autoOpenDoors then return end
    local pos = player:getPosition()
    if keys == 'Up' or (wsadWalking and keys == 'W') then
      pos.y = pos.y - 1
    elseif keys == 'Down' or (wsadWalking and keys == 'S') then
      pos.y = pos.y + 1
    elseif keys == 'Left' or (wsadWalking and keys == 'A') then
      pos.x = pos.x - 1
    elseif keys == 'Right' or (wsadWalking and keys == 'D') then
      pos.x = pos.x + 1
    elseif wsadWalking and keys == "Q" then
      pos.y = pos.y - 1
      pos.x = pos.x - 1
    elseif wsadWalking and keys == "E" then
      pos.y = pos.y - 1
      pos.x = pos.x + 1
    elseif wsadWalking and keys == "Z" then
      pos.y = pos.y + 1
      pos.x = pos.x - 1
    elseif wsadWalking and keys == "C" then
      pos.y = pos.y + 1
      pos.x = pos.x + 1
    end
    checkForDoors(pos)
  end)
end


addCheckBox("bless", "Buy bless at login", true, rightPanel, "Say !bless at login.")
if true then
  local blessed = false
  onTextMessage(function(mode,text) 
    if not settings.bless then return end
    
    text = text:lower()

    if text == "you already have all blessings." then
      blessed = true
    end
  end)
  if settings.bless then
    if player:getBlessings() == 0 then
      say("!bless")
      schedule(2000, function() 
          if g_game.getClientVersion() > 1000 then
            if not blessed and player:getBlessings() == 0 then
                warn("!! Blessings not bought !!")
            end
          end
      end)
    end
  end
end


addCheckBox("reUse", "Keep Crosshair", false, rightPanel, "Keep crosshair after using with item")
if true then
  local excluded = {268, 237, 238, 23373, 266, 236, 239, 7643, 23375, 7642, 23374, 5908, 5942} 

  onUseWith(function(pos, itemId, target, subType)
    if settings.reUse and not table.find(excluded, itemId) then
      schedule(50, function()
        item = findItem(itemId)
        if item then
          modules.game_interface.startUseWith(item)
        end
      end)
    end
  end)
end


addCheckBox("suppliesControl", "TargetBot off if low supply", false, leftPanel, "Turn off TargetBot if either one of supply amount is below 50% of minimum.")
if true then
  macro(500, function()
    if not settings.suppliesControl then return end
    if TargetBot.isOff() then return end
    if CaveBot.isOff() then return end
    if type(hasSupplies()) == 'table' then
        TargetBot.setOff()
    end
  end)
end

addCheckBox("holdMwall", "Hold MW/WG", true, rightPanel, "Mark tiles with below hotkeys to automatically use Magic Wall or Wild Growth")
addTextEdit("holdMwHot", "Magic Wall Hotkey: ", "F5", rightPanel)
addTextEdit("holdWgHot", "Wild Growth Hotkey: ", "F6", rightPanel)
if true then

  local hold = 0
  local mwHot
  local wgHot

  local candidates = {}
  local m = macro(20, function()
    mwHot = settings.holdMwHot
    wgHot = settings.holdWgHot
    
    if not settings.holdMwall then return end
      if #candidates == 0 then return end

      for i, pos in pairs(candidates) do
        local tile = g_map.getTile(pos)
        if tile then
          if tile:getText():len() == 0 then 
            table.remove(candidates, i)
          end
          local rune = tile:getText() == "HOLD MW" and 3180 or tile:getText() == "HOLD WG" and 3156
          if tile:canShoot() and not isInPz() and tile:isWalkable() and tile:getTopUseThing():getId() ~= 2130 then
            if math.abs(player:getPosition().x-tile:getPosition().x) < 8 and math.abs(player:getPosition().y-tile:getPosition().y) < 6 then
              return useWith(rune, tile:getTopUseThing())
            end
          end
        end
      end
  end)

  onRemoveThing(function(tile, thing)
    if not settings.holdMwall then return end
      if thing:getId() ~= 2129 then return end
      if tile:getText():find("HOLD") then
          table.insert(candidates, tile:getPosition())
          local rune = tile:getText() == "HOLD MW" and 3180 or tile:getText() == "HOLD WG" and 3156
          if math.abs(player:getPosition().x-tile:getPosition().x) < 8 and math.abs(player:getPosition().y-tile:getPosition().y) < 6 then
            return useWith(rune, tile:getTopUseThing())
          end
      end
  end)

  onAddThing(function(tile, thing)
    if not settings.holdMwall then return end
      if m.isOff() then return end
      if thing:getId() ~= 2129 then return end
      if tile:getText():len() > 0 then
          table.remove(candidates, table.find(candidates,tile))
      end
  end)

  onKeyDown(function(keys)
    local _w = modules.game_walking or modules.game_walk; local wsadWalking = _w and _w.wsadWalking
    if not wsadWalking then return end
    if not settings.holdMwall then return end
    if m.isOff() then return end
    if keys ~= mwHot and keys ~= wgHot then return end
    hold = now

    local tile = getTileUnderCursor()
    if not tile then return end

    if tile:getText():len() > 0 then
        tile:setText("")
    else
        if keys == mwHot then
            tile:setText("HOLD MW")
        else
            tile:setText("HOLD WG")
        end
        table.insert(candidates, tile:getPosition())
    end
  end)

  onKeyPress(function(keys)
    local _w = modules.game_walking or modules.game_walk; local wsadWalking = _w and _w.wsadWalking
    if not wsadWalking then return end
    if not settings.holdMwall then return end
    if m.isOff() then return end
    if keys ~= mwHot and keys ~= wgHot then return end

    if (hold - now) < -1000 then
      candidates = {}
      for i, tile in ipairs(g_map.getTiles(posz())) do
        local text = tile:getText()
        if text:find("HOLD") then
          tile:setText("")
        end
      end
    end
  end)
end

addCheckBox("checkPlayer", "Check Players", true, rightPanel, "Auto look on players and mark level and vocation on character model")
if true then
  local found
  local function checkPlayers()
    for i, spec in ipairs(getSpectators()) do
      if spec:isPlayer() and spec:getText() == "" and spec:getPosition().z == posz() and spec ~= player then
          g_game.look(spec)
          found = now
      end
    end
  end
  if settings.checkPlayer then 
    schedule(500, function()
      checkPlayers()
    end)
  end

  onPlayerPositionChange(function(x,y)
    if not settings.checkPlayer then return end
    if x.z ~= y.z then
      schedule(20, function() checkPlayers() end)
    end
  end)

  onCreatureAppear(function(creature)
    if not settings.checkPlayer then return end
    if creature:isPlayer() and creature:getText() == "" and creature:getPosition().z == posz() and creature ~= player then
        g_game.look(creature)
        found = now
    end
  end)

  local regex = [[You see ([^\(]*) \(Level ([0-9]*)\)((?:.)* of the ([\w ]*),|)]]
  onTextMessage(function(mode, text)
    if not settings.checkPlayer then return end

    local re = regexMatch(text, regex)
    if #re ~= 0 then
        local name = re[1][2]
        local level = re[1][3]
        local guild = re[1][5] or ""

        if guild:len() > 10 then
          guild = guild:sub(1,10) -- change to proper (last) values
          guild = guild.."..."
        end
        local voc
        if text:lower():find("sorcerer") then
            voc = "MS"
        elseif text:lower():find("druid") then
            voc = "ED"
        elseif text:lower():find("knight") then
            voc = "EK"
        elseif text:lower():find("paladin") then
            voc = "RP"
        end
        local creature = getCreatureByName(name)
        if creature then
            creature:setText("\n"..level..voc.."\n"..guild)
        end
        if found and now - found < 500 then
          modules.game_textmessage.clearMessages()
        end
    end
  end)
end

addCheckBox("nextBackpack", "Open Next Loot Container", true, leftPanel, "Auto open next loot container if full - has to have the same ID.")
  local function openNextLootContainer()
    if not settings.nextBackpack then return end
    local containers = getContainers()
    local lootCotaniersIds = CaveBot.GetLootContainers()

    for i, container in ipairs(containers) do
      local cId = container:getContainerItem():getId()
      if containerIsFull(container) then
        if table.find(lootCotaniersIds, cId) then
          for _, item in ipairs(container:getItems()) do
            if item:getId() == cId then
              return g_game.open(item)
            end
          end
        end
      end
    end
  end
if true then
  onContainerOpen(function(container, previousContainer)
    schedule(100, function()
      openNextLootContainer()
    end)
  end)

  onAddItem(function(container, slot, item, oldItem)
    schedule(100, function()
      openNextLootContainer()
    end)
  end)
end

addCheckBox("highlightTarget", "Highlight Current Target", true, rightPanel, "Additionaly hightlight current target with red glow")
if true then
  local function forceMarked(creature)
    if target() == creature then
        creature:setMarked("red")
        return schedule(333, function() forceMarked(creature) end)
    end
  end

  onAttackingCreatureChange(function(newCreature, oldCreature)
    if not settings.highlightTarget then return end
      if oldCreature then
          oldCreature:setMarked('')
      end
      if newCreature then
          forceMarked(newCreature)
      end
  end)
end

-- =========================================================================
-- Ver ID de objetos al darles Look (Show Item IDs on Look)
-- =========================================================================
addCheckBox("showLookId", "Show Item IDs on Look", true, rightPanel, "Show item ID in description and console when looking at objects (Ctrl + Right Click)")
if true then
  local lastLooked = nil

  local function resolveItemId(thing)
    if not thing then return nil end

    -- 0. Si es un widget que contiene un Item (UIItem en inventario, contenedor, equipo, etc.)
    if thing.getItem and thing:getItem() then
      thing = thing:getItem()
    elseif thing.item and type(thing.item) == "userdata" then
      thing = thing.item
    end

    -- 1. Si es directamente un Item
    if thing.isItem and thing:isItem() then
      local count = 1
      if thing.getCount then
        local c = thing:getCount()
        if type(c) == "number" and c > 1 then count = c end
      end
      return thing:getId(), count
    end

    -- 2. Si es un Tile (click en el mapa)
    if thing.getTopLookThing then
      local lookThing = thing:getTopLookThing()
      if lookThing then
        if lookThing.isItem and lookThing:isItem() then
          local count = 1
          if lookThing.getCount then
            local c = lookThing:getCount()
            if type(c) == "number" and c > 1 then count = c end
          end
          return lookThing:getId(), count
        elseif lookThing.getId and (not lookThing.isCreature or not lookThing:isCreature()) then
          return lookThing:getId(), 1
        end
      end
    end

    -- 3. Top use thing o top thing del tile
    if thing.getTopUseThing then
      local useThing = thing:getTopUseThing()
      if useThing and useThing.getId and (not useThing.isCreature or not useThing:isCreature()) then
        return useThing:getId(), 1
      end
    end

    if thing.getTopThing then
      local topThing = thing:getTopThing()
      if topThing and topThing.getId and (not topThing.isCreature or not topThing:isCreature()) then
        return topThing:getId(), 1
      end
    end

    -- 4. Si el Tile tiene items
    if thing.getItems then
      local items = thing:getItems()
      if type(items) == "table" and #items > 0 then
        local topItem = items[#items] or items[1]
        if topItem and topItem.getId then
          return topItem:getId(), 1
        end
      end
    end

    -- 5. Si el Tile tiene suelo (ground)
    if thing.getGround then
      local ground = thing:getGround()
      if ground and ground.getId then
        return ground:getId(), 1
      end
    end

    -- 6. Respaldo generico si tiene getId() y no es criatura
    if thing.getId and (not thing.isCreature or not thing:isCreature()) then
      local id = thing:getId()
      if type(id) == "number" and id > 0 then
        return id, 1
      end
    end

    return nil
  end

  local function isLookText(t)
    if not t or type(t) ~= "string" then return false end
    local lower = t:lower()
    return lower:find("you see") ~= nil
        or lower:find("ves ") ~= nil
        or lower:find("tu ves") ~= nil
        or lower:find("voce ve") ~= nil
        or lower:find("voc. ve") ~= nil
        or lower:find("miras ") ~= nil
        or lower:find("observas ") ~= nil
        or lower:find("te ves ") ~= nil
  end

  local function formatIdTag(id, count)
    if count and count > 1 then
      return string.format("[ID: %d | Count: %d]", id, count)
    else
      return string.format("[ID: %d]", id)
    end
  end

  -- Hook a g_game.look para capturar el item inspeccionado
  if not g_game._origLookForId then
    g_game._origLookForId = g_game.look
  end

  g_game.look = function(thing, isHotkeyed)
    if settings.showLookId and thing then
      local id, count = resolveItemId(thing)
      if id and id > 0 then
        lastLooked = {
          id = id,
          count = count,
          time = g_clock.millis(),
          pos = thing.getPosition and thing:getPosition() or nil
        }
      end
    end
    return g_game._origLookForId(thing, isHotkeyed)
  end

  -- Funcion para manejar Ctrl + Click Derecho (Look + ID)
  local function handleCtrlRightClick(mousePos)
    if not g_keyboard.isCtrlPressed() then return false end

    local child = rootWidget:recursiveGetChildByPos(mousePos)
    local targetThing = nil

    -- 1. Si el widget es o contiene un Item (contenedores, inventario, equipo, etc.)
    if child then
      if child.getItem and child:getItem() then
        targetThing = child:getItem()
      elseif child.item and type(child.item) == "userdata" then
        targetThing = child.item
      elseif child.getItemId and child:getItemId() > 0 then
        local itemObj = Item.create(child:getItemId())
        if itemObj then targetThing = itemObj end
      end
    end

    -- 2. Si no es un item widget, checar si el click fue en el Game Map
    if not targetThing then
      local mapPanel = modules.game_interface and modules.game_interface.getMapPanel()
      if mapPanel then
        local tile = mapPanel:getTile(mousePos)
        if tile then
          targetThing = tile:getTopLookThing() or tile:getTopCreature() or tile:getTopUseThing() or tile:getTopThing() or tile:getGround()
        end
      end
    end

    -- 3. Si aun no encontramos thing, buscar si child es o tiene getThing
    if not targetThing and child then
      if child.getThing and child:getThing() then
        targetThing = child:getThing()
      end
    end

    if targetThing then
      local id, count = resolveItemId(targetThing)
      local name = nil
      if targetThing.getName then
        pcall(function() name = targetThing:getName() end)
      end
      if not name and targetThing.getMarketData then
        pcall(function() name = targetThing:getMarketData().name end)
      end

      -- Registrar para el lookText del servidor
      if id and id > 0 then
        lastLooked = {
          id = id,
          count = count or 1,
          time = g_clock.millis(),
          pos = targetThing.getPosition and targetThing:getPosition() or nil
        }
      end

      -- Enviar accion Look al servidor
      pcall(function() g_game.look(targetThing) end)

      -- Mostrar ID inmediatamente en pantalla y consola
      if id and id > 0 then
        local tag = formatIdTag(id, count)
        local displayMsg = string.format("Look: %s %s", name or "Objeto", tag)

        if modules.game_textmessage and modules.game_textmessage.displayStatusMessage then
          modules.game_textmessage.displayStatusMessage(displayMsg)
        end

        if modules.game_console and modules.game_console.addText then
          pcall(function()
            modules.game_console.addText(displayMsg, MessageModes.Status or 20, "Server Log")
          end)
        end
      elseif targetThing.isCreature and targetThing:isCreature() then
        local cName = targetThing:getName()
        if modules.game_textmessage and modules.game_textmessage.displayStatusMessage then
          modules.game_textmessage.displayStatusMessage(string.format("Look: %s", cName or "Criatura"))
        end
      end

      return true
    end

    return false
  end

  -- Interceptar eventos globales de mouse para Ctrl + Click Derecho
  local rootWidget = g_ui and g_ui.getRootWidget and g_ui.getRootWidget()
  if rootWidget then
    if not rootWidget._origMousePressLookId then
      rootWidget._origMousePressLookId = rootWidget.onMousePress
    end
    rootWidget.onMousePress = function(widget, mousePos, mouseButton)
      if (mouseButton == MouseRightButton or mouseButton == 2) and g_keyboard.isCtrlPressed() then
        if handleCtrlRightClick(mousePos) then
          return true
        end
      end
      if rootWidget._origMousePressLookId then
        return rootWidget._origMousePressLookId(widget, mousePos, mouseButton)
      end
    end

    if not rootWidget._origMouseReleaseLookId then
      rootWidget._origMouseReleaseLookId = rootWidget.onMouseRelease
    end
    rootWidget.onMouseRelease = function(widget, mousePos, mouseButton)
      if (mouseButton == MouseRightButton or mouseButton == 2) and g_keyboard.isCtrlPressed() then
        return true
      end
      if rootWidget._origMouseReleaseLookId then
        return rootWidget._origMouseReleaseLookId(widget, mousePos, mouseButton)
      end
    end
  end

  -- Interceptar tambien en gameMapPanel por si captura el evento directamente
  local mapPanel = modules.game_interface and modules.game_interface.getMapPanel()
  if mapPanel then
    if not mapPanel._origMousePressLookId then
      mapPanel._origMousePressLookId = mapPanel.onMousePress
    end
    mapPanel.onMousePress = function(widget, mousePos, mouseButton)
      if (mouseButton == MouseRightButton or mouseButton == 2) and g_keyboard.isCtrlPressed() then
        if handleCtrlRightClick(mousePos) then
          return true
        end
      end
      if mapPanel._origMousePressLookId then
        return mapPanel._origMousePressLookId(widget, mousePos, mouseButton)
      end
    end

    if not mapPanel._origMouseReleaseLookId then
      mapPanel._origMouseReleaseLookId = mapPanel.onMouseRelease
    end
    mapPanel.onMouseRelease = function(widget, mousePos, mouseButton)
      if (mouseButton == MouseRightButton or mouseButton == 2) and g_keyboard.isCtrlPressed() then
        return true
      end
      if mapPanel._origMouseReleaseLookId then
        return mapPanel._origMouseReleaseLookId(widget, mousePos, mouseButton)
      end
    end
  end

  -- Hook a displayMessage de modules.game_textmessage si esta disponible
  if modules.game_textmessage and modules.game_textmessage.displayMessage then
    if not modules.game_textmessage._origDisplayMessageForId then
      modules.game_textmessage._origDisplayMessageForId = modules.game_textmessage.displayMessage
      modules.game_textmessage.displayMessage = function(mode, text)
        if settings.showLookId and lastLooked and (g_clock.millis() - lastLooked.time < 5000) then
          if isLookText(text) and not text:find("%[ID:") then
            local tag = formatIdTag(lastLooked.id, lastLooked.count)
            text = text .. " " .. tag
          end
        end
        return modules.game_textmessage._origDisplayMessageForId(mode, text)
      end
    end
  end

  -- Listener a onTextMessage para asegurar actualizacion en pantalla y consola
  onTextMessage(function(mode, text)
    if not settings.showLookId then return end
    if not lastLooked or (g_clock.millis() - lastLooked.time >= 5000) then return end
    if not isLookText(text) then return end

    local id = lastLooked.id
    local count = lastLooked.count
    local tag = formatIdTag(id, count)

    schedule(500, function()
      lastLooked = nil
    end)

    -- 1. Actualizar labels en la pantalla central y barra de estado
    local function patchScreenLabels()
      if not modules.game_textmessage or not modules.game_textmessage.messagesPanel then return end
      local mp = modules.game_textmessage.messagesPanel
      local labels = {}
      if mp.centerTextMessagePanel then
        table.insert(labels, mp.centerTextMessagePanel.highCenterLabel)
        table.insert(labels, mp.centerTextMessagePanel.lowCenterLabel)
      end
      table.insert(labels, mp.statusLabel)
      table.insert(labels, mp.bottomCenterLabel)

      for _, lbl in ipairs(labels) do
        if lbl and lbl:isVisible() then
          local t = lbl:getText()
          if t and isLookText(t) and not t:find("%[ID:") then
            lbl:setText(t .. " " .. tag)
          end
        end
      end
    end

    patchScreenLabels()
    schedule(15, patchScreenLabels)
    schedule(50, patchScreenLabels)

    -- 2. Actualizar buffer de la consola (Server Log / Default)
    local function patchConsole()
      local g_console = modules.game_console
      if not g_console or not g_console.consoleTabBar then return end
      local tabs = { "Server Log", "Default" }
      if g_console.getCurrentTab and g_console.getCurrentTab() then
        local curTab = g_console.getCurrentTab():getText()
        if curTab and not table.find(tabs, curTab) then
          table.insert(tabs, curTab)
        end
      end
      for _, tabName in ipairs(tabs) do
        local tab = g_console.getTab(tabName)
        if tab then
          local panel = g_console.consoleTabBar:getTabPanel(tab)
          if panel then
            local consoleBuffer = panel:getChildById('consoleBuffer')
            if consoleBuffer then
              local lastMsg = consoleBuffer:getLastChild()
              if lastMsg and lastMsg.getText then
                local msgText = lastMsg:getText()
                if msgText and isLookText(msgText) and not msgText:find("%[ID:") then
                  lastMsg:setText(msgText .. " " .. tag)
                end
              end
            end
          end
        end
      end
    end

    patchConsole()
    schedule(15, patchConsole)
    schedule(50, patchConsole)
  end)
end