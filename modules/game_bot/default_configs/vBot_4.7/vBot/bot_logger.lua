-- ============================================================
-- HegalOT Bot Logger - Sistema persistente de registro de acciones
-- Con rotación automática si el archivo supera los 100 MB
-- ============================================================

botLogger = {}
botLogger.version = "1.1"

local logBuffer = {}
local MAX_BUFFER_LINES = 2500
local VIRTUAL_LOG_FILE = "/bot_actions.log"
local MAX_LOG_FILE_BYTES = 100 * 1024 * 1024 -- 100 MB

local ABS_LOG_PATHS = {
  "C:/Users/Gera/AppData/Roaming/hegalot/hegalot/hegalot/bot_actions.log",
  "C:/Users/Gera/AppData/Local/HegalOTLauncher/clients/hegalot/bot_actions.log"
}

local ALL_MONITORED_LOGS = {
  "C:/Users/Gera/AppData/Roaming/hegalot/hegalot/hegalot/bot_actions.log",
  "C:/Users/Gera/AppData/Roaming/hegalot/hegalot/hegalot/hegalot.log",
  "C:/Users/Gera/AppData/Roaming/hegalot/hegalot/hegalot/hegalot.2.log",
  "C:/Users/Gera/AppData/Local/HegalOTLauncher/clients/hegalot/bot_actions.log",
  "C:/Users/Gera/AppData/Local/HegalOTLauncher/clients/hegalot/hegalot.log"
}

function botLogger.formatTime()
  if os and os.date then
    return os.date("%Y-%m-%d %H:%M:%S")
  end
  return tostring(os.time())
end

-- Comprobar y truncar logs que superen los 100 MB
function botLogger.checkAndRotateLogs()
  if not io or not io.open then return end
  for _, path in ipairs(ALL_MONITORED_LOGS) do
    pcall(function()
      local f = io.open(path, "r")
      if f then
        local size = f:seek("end")
        f:close()
        if size and size >= MAX_LOG_FILE_BYTES then
          local wf = io.open(path, "w")
          if wf then
            wf:write(string.format("[%s] [SYSTEM] Log reseteado automaticamente por superar 100MB (%d bytes)\n", 
              botLogger.formatTime(), size))
            wf:close()
          end
        end
      end
    end)
  end
end

-- Ejecutar rotacion al cargar
botLogger.checkAndRotateLogs()

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

function botLogger.write(category, message, details)
  -- SOLO capturar logs si el usuario activo el boton en la pestaña de Tools
  if not storage or not storage.bot_logger or not storage.bot_logger.enabled then
    return
  end

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

  local isUrgent = line:find("ERROR") or line:find("EXCEPCI")
  if isUrgent or #botLogger.pendingDiskLines >= 25 then
    flushDiskLogs()
  elseif not botLogger.isFlushScheduled then
    botLogger.isFlushScheduled = true
    if schedule then
      schedule(3000, flushDiskLogs)
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
  end)
  if io and io.open then
    for _, path in ipairs(ABS_LOG_PATHS) do
      pcall(function()
        local f = io.open(path, "w")
        if f then f:close() end
      end)
    end
  end
end

function botLogger.getRecentLines(count)
  count = count or 50
  local total = #logBuffer
  local startIdx = math.max(1, total - count + 1)
  local result = {}
  for i = startIdx, total do
    table.insert(result, logBuffer[i])
  end
  return result
end

-- Revision periodica de tamaño de logs cada 60 segundos
if macro then
  macro(60000, function()
    botLogger.checkAndRotateLogs()
  end)
end

function isBotLoggerEnabled()
  return storage and storage.bot_logger and storage.bot_logger.enabled == true
end

-- Funcion global de log para cavebot
function logCaveBot(action, msg, details)
  if not isBotLoggerEnabled() then return end
  if botLogger and botLogger.write then
    botLogger.write("CAVEBOT:" .. tostring(action):upper(), msg, details)
  end
end

if isBotLoggerEnabled() then
  botLogger.write("SYSTEM", "Iniciando sistema de logs del bot HegalOT (v1.1) con limite maximo de 100MB")
end
