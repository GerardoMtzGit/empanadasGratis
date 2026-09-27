local context = G.botContext

context.encode = function(data, indent) return json.encode(data, indent or 2) end
context.decode = function(text) local status, result = pcall(function() return json.decode(text) end) if status then return result end return {} end

context.displayGeneralBox = function(title, message, buttons, onEnterCallback, onEscapeCallback)
  local box = displayGeneralBox(title, message, buttons, onEnterCallback, onEscapeCallback)
  box.botWidget = true
  return box
end

context.doScreenshot = function(filename)
  g_app.doScreenshot(filename)
end
context.screenshot = context.doScreenshot

context.getVersion = function()
  return g_app.getVersion()
end

context.isIgnoredSummonOrFamiliar = function(creature)
  if not creature then return false end
  if creature.isLocalPlayer and creature:isLocalPlayer() then return true end

  local name = ""
  pcall(function()
    if creature.getName then
      name = tostring(creature:getName()):lower():trim()
    end
  end)

  if name:len() > 0 then
    if name:find("familiar") or name:find("summon") or name:find("sumon") then
      return true
    end
    if name == "druid familiar" or name == "sorcerer familiar" or name == "knight familiar" or name == "paladin familiar" then
      return true
    end
    if name == "grovebeast" or name == "feuerhexe" or name == "skullfrost" or name == "phantom" then
      return true
    end
  end

  pcall(function()
    if creature.getType then
      local t = creature:getType()
      if t and (t == 3 or t == 4) then
        return true
      end
    end
  end)

  local isSumm = false
  pcall(function()
    if creature.isSummon and creature:isSummon() then isSumm = true end
    if creature.isPet and creature:isPet() then isSumm = true end
    if creature.getMaster and creature:getMaster() ~= nil then isSumm = true end
    if creature.isPartyMember and creature:isPartyMember() then isSumm = true end
  end)
  if isSumm then return true end

  return false
end
isIgnoredSummonOrFamiliar = context.isIgnoredSummonOrFamiliar

if g_game and not g_game._originalAttack then
  g_game._originalAttack = g_game.attack
  g_game.attack = function(creature)
    if creature and context.isIgnoredSummonOrFamiliar(creature) then
      return false
    end
    return g_game._originalAttack(creature)
  end
end