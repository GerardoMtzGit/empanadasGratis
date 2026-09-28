-- load all otui files, order doesn't matter
local configName = modules.game_bot.contentsPanel.config:getCurrentOption().text

local configFiles = g_resources.listDirectoryFiles("/bot/" .. configName .. "/vBot", true, false)
for i, file in ipairs(configFiles) do
  local ext = file:split(".")
  if ext[#ext]:lower() == "ui" or ext[#ext]:lower() == "otui" then
    g_ui.importStyle(file)
  end
end

local function loadScript(name)
  return dofile("/vBot/" .. name .. ".lua")
end

-- here you can set manually order of scripts
-- libraries should be loaded first
local luaFiles = {
  "bot_logger",
  "main",
  "items",
  "vlib",
  "new_cavebot_lib",
  "configs", -- do not change this and above
  "extras",
  "tirar_runa",
  "druid_targeting",
  "druid_familiar",
  "cavebot",
  "playerlist",
  "BotServer",
  "alarms",
  "Conditions",
  "Equipper",
  "pushmax",
  "combo",
  "HealBot",
  "icons_tab",
  "cooldown_hud",
  "sd_only",
  "new_healer",
  "AttackBot", -- last of major modules
  "ingame_editor",
  "Dropper",
  "Containers",
  "quiver_manager",
  "quiver_label",
  "tools",
  "antiRs",
  "depot_withdraw",
  "cast_food",
  "eat_food",
  "equip",
  "exeta",
  "analyzer",
  "spy_level",
  "supplies",
  "depositer_config",
  "npc_talk",
  "xeno_menu",
  "hold_target",
  "refill_hud",
  "cavebot_control_panel"
}

for i, file in ipairs(luaFiles) do
  local ok, err = pcall(loadScript, file)
  if not ok then
    warn("[Loader Error] Failed loading " .. tostring(file) .. ": " .. tostring(err))
  end
end

setDefaultTab("Main")
UI.Separator()
UI.Label("Private Scripts:")
UI.Separator()
