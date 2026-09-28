-- ============================================================
-- HegalOT Bot Logger - Sistema persistente de registro de acciones
-- ============================================================

botLogger = {}
botLogger.version = "1.0"

local logBuffer = {}
local MAX_BUFFER_LINES = 2500
local VIRTUAL_LOG_FILE = "/bot_actions.log"

local ABS_LOG_PATHS = {
  "C:/Users/Gera/AppData/Roaming/hegalot/hegalot/hegalot/bot_actions.log",
  "C:/Users/Gera/AppData/Local/HegalOTLauncher/clients/hegalot/bot_actions.log"
}

-- Cargar historial existente si existe
pcall(function()
  if g_resources and g_resources.fileExists(VIRTUAL_LOG_FILE) then
    local content = g_resources.readFileContents(VIRTUAL_LOG_FILE)
    if content and #content > 0 then
      for line in content:gmatch("[^\r\n]+") do
        table.insert(logBuffer, line)
        if #logBuffer > MAX_BUFFER_LINES then
          table.remove(logBuffer, 1)
        end
      end
    end
  end
end)

function botLogger.formatTime()
  if os and os.date then
    return os.date("%Y-%m-%d %H:%M:%S")
  end
  return tostring(os.time())
end

function botLogger.write(category, message, details)
  local ts = botLogger.formatTime()
  local cat = tostring(category or "BOT"):upper()
  local msg = tostring(message or "")
  local line = string.format("[%s] [%s] %s", ts, cat, msg)

  if details ~= nil then
    if type(details) == "table" then
      local ok, encoded = pcall(json.encode, details)
      if ok and encoded then
        line = line .. " | " .. encoded
      else
        line = line .. " | [Table]"
      end
    else
      line = line .. " | " .. tostring(details)
    end
  end
  -- 1. Almacenar en buffer y persistir mediante g_resources
  table.insert(logBuffer, line)
  if #logBuffer > MAX_BUFFER_LINES then
    table.remove(logBuffer, 1)
  end

  if not botLogger.pendingDiskLines then
    botLogger.pendingDiskLines = {}
  end
  table.insert(botLogger.pendingDiskLines, line)

  local function flushDiskLogs()
    botLogger.isFlushScheduled = false
    if #botLogger.pendingDiskLines == 0 then return end
    local text = table.concat(botLogger.pendingDiskLines, "\n") .. "\n"
    botLogger.pendingDiskLines = {}
    if io and io.open then
      for _, path in ipairs(ABS_LOG_PATHS) do
        pcall(function()
          local f = io.open(path, "a+")
          if f then
            f:write(text)
            f:close()
          end
        end)
      end
    end
  end

  local isUrgent = line:find("ERROR") or line:find("EXCEPCI") or line:find("SELL:START") or line:find("SELL:COMPLETE") or line:find("CAVEBOT") or line:find("Venta detectada")
  if isUrgent or #botLogger.pendingDiskLines >= 10 then
    flushDiskLogs()
  elseif not botLogger.isFlushScheduled then
    botLogger.isFlushScheduled = true
    if schedule then
      schedule(1000, flushDiskLogs)
    else
      flushDiskLogs()
    end
  end

  -- 3. Enviar a consola de OTClient / terminal (Ctrl + T)
  pcall(function()
    print("[BOT_LOG] " .. line)
  end)

  return line
end

function botLogger.clear()
  logBuffer = {}
  pcall(function()
    if g_resources and g_resources.writeFileContents then
      g_resources.writeFileContents(VIRTUAL_LOG_FILE, "")
    end
    if io and io.open then
      for _, path in ipairs(ABS_LOG_PATHS) do
        local f = io.open(path, "w")
        if f then f:write(""); f:close() end
      end
    end
  end)
  botLogger.write("SYSTEM", "Archivo de log reiniciado.")
end

-- Funciones globales de acceso directo
function logBotAction(category, message, details)
  return botLogger.write(category, message, details)
end

function logCaveBot(action, message, details)
  return botLogger.write("CAVEBOT:" .. tostring(action):upper(), message, details)
end

function logSell(step, message, details)
  return botLogger.write("SELL:" .. tostring(step):upper(), message, details)
end

function clearBotLog()
  return botLogger.clear()
end

-- Registro de inicio
botLogger.write("SYSTEM", "Iniciando sistema de logs del bot HegalOT (v1.0)")
