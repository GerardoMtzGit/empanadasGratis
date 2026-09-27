-- config for bot
CaveBot.Config = {}
CaveBot.Config.values = {}
CaveBot.Config.default_values = {}
CaveBot.Config.value_setters = {}

CaveBot.Config.setup = function()
  CaveBot.Config.ui = UI.createWidget("CaveBotConfigPanel")
  local ui = CaveBot.Config.ui
  local add = CaveBot.Config.add
  
  add("ping", "Server ping", 10)
  add("walkDelay", "Walk delay", 0)
  add("mapClick", "Use map click", false)
  add("mapClickDelay", "Map click delay", 0)
  add("ignoreFields", "Ignore fields", false)  
  add("skipBlocked", "Skip blocked path", false)  
  add("useDelay", "Delay after use", 300)
end

CaveBot.Config.show = function()
  CaveBot.Config.ui:show()
end

CaveBot.Config.hide = function()
  CaveBot.Config.ui:hide()
end

CaveBot.Config.onConfigChange = function(configName, isEnabled, configData)
  for k, v in pairs(CaveBot.Config.default_values) do
    CaveBot.Config.value_setters[k](v)
  end
  if not configData then return end
  for k, v in pairs(configData) do
    if CaveBot.Config.value_setters[k] then
      -- Auto-migrate old default delays to 0 as requested by user
      if k == "walkDelay" and v == 10 then
        v = 0
      elseif k == "mapClickDelay" and v == 100 then
        v = 0
      elseif k == "ping" and v == 100 then
        v = 10
      end
      CaveBot.Config.value_setters[k](v)
    end
  end
end

CaveBot.Config.save = function()
  return CaveBot.Config.values
end

CaveBot.Config.add = function(id, title, defaultValue)
  if CaveBot.Config.values[id] then
    return warn("Duplicated config key: " .. id)
  end
    
  local panel
  local setter -- sets value
  if type(defaultValue) == "number" then
    panel = UI.createWidget("CaveBotConfigNumberValuePanel", CaveBot.Config.ui)
    panel:setId(id)
    setter = function(value)
      CaveBot.Config.values[id] = value
      panel.value:setText(value, true)
    end
    setter(defaultValue)
    panel.value.onTextChange = function(widget, newValue)
      newValue = tonumber(newValue)
      if newValue then
        CaveBot.Config.values[id] = newValue
        CaveBot.save()
      end
    end
  elseif type(defaultValue) == "boolean" then
    panel = UI.createWidget("CaveBotConfigBooleanValuePanel", CaveBot.Config.ui)
    panel:setId(id)
    setter = function(value)
      CaveBot.Config.values[id] = value
      panel.value:setOn(value, true)
    end
    setter(defaultValue)
    panel.value.onClick = function(widget)
      widget:setOn(not widget:isOn())
      CaveBot.Config.values[id] = widget:isOn()
      CaveBot.save()
    end
  else
    return warn("Invalid default value of config for key " .. id .. ", should be number or boolean")      
  end
  
  panel.title:setText(tr(title) .. ":")
  
  CaveBot.Config.value_setters[id] = setter
  CaveBot.Config.values[id] = defaultValue
  CaveBot.Config.default_values[id] = defaultValue
end

CaveBot.Config.get = function(id)
  if CaveBot.Config.values[id] == nil then
    return warn("Invalid CaveBot.Config.get, id: " .. id)
  end
  return CaveBot.Config.values[id]
end

CaveBot.Config.set = function(id, value, skipSave)
  local setter = CaveBot.Config.value_setters[id]
  if setter then
    setter(value)
    if not skipSave then
      CaveBot.save()
    end
  else
    local currentValue = CaveBot.Config.values[id]
    CaveBot.Config.values[id] = value
    local panel = CaveBot.Config.ui and CaveBot.Config.ui[id]
    if panel and panel.value then
      if type(currentValue) == 'boolean' and panel.value.setOn then
        panel.value:setOn(value, true)
      elseif panel.value.setText then
        panel.value:setText(value, true)
      end
    end
    if not skipSave then
      CaveBot.save()
    end
  end
end