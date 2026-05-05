-- server/components/logger.lua
-- FIX : Config peut ne pas être encore chargé quand Logger.new() est appelé
--       (Logger est le 1er script serveur). Fallback sur INFO si Config est nil.

Logger = {}
Logger.levels = {
    DEBUG = 0,
    INFO  = 1,
    WARN  = 2,
    ERROR = 3,
}

Logger.colors = {
    [Logger.levels.DEBUG] = "^5",
    [Logger.levels.INFO]  = "^2",
    [Logger.levels.WARN]  = "^3",
    [Logger.levels.ERROR] = "^1",
}

Logger.metatable = { __index = Logger }

function Logger.new(tag)
    -- FIX : accès défensif à Config pour éviter un crash au 1er chargement
    local level = (Config and Config.logLevel) or Logger.levels.INFO
    local self = setmetatable({
        tag      = tag or "LOGGER",
        minLevel = level,
    }, Logger.metatable)
    return self
end

function Logger:debug(msg) self:_log(Logger.levels.DEBUG, msg) end
function Logger:info(msg)  self:_log(Logger.levels.INFO,  msg) end
function Logger:warn(msg)  self:_log(Logger.levels.WARN,  msg) end
function Logger:error(msg) self:_log(Logger.levels.ERROR, msg) end

function Logger:_log(level, msg)
    if level < self.minLevel then return end
    local color = Logger.colors[level] or "^7"
    local levelName = ""
    for name, lvl in pairs(Logger.levels) do
        if lvl == level then levelName = name; break end
    end
    print(color .. "[" .. levelName .. "|" .. self.tag .. "] " .. tostring(msg) .. "^7")
end

function Logger:child(tag)
    return Logger.new(tag)
end

-- Instance globale — NE PAS écraser Logger (la classe) avec une instance.
-- On utilise un nom différent pour le logger global de la ressource.
Logger = Logger.new("UNION")
