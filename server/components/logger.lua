-- server/components/logger.lua
-- FIX L1 : Logger (classe) n'est plus écrasé par l'instance globale.
--           L'instance globale est stockée dans _G directement SANS écraser la classe.
-- FIX L2 : Table inverse Logger.levelNames pour éviter l'itération O(n) à chaque log.

Logger = {}
Logger.levels = {
    DEBUG = 0,
    INFO  = 1,
    WARN  = 2,
    ERROR = 3,
}

-- FIX L2 : table inverse précalculée
Logger.levelNames = {
    [0] = "DEBUG",
    [1] = "INFO",
    [2] = "WARN",
    [3] = "ERROR",
}

Logger.colors = {
    [0] = "^5",  -- DEBUG : cyan
    [1] = "^2",  -- INFO  : vert
    [2] = "^3",  -- WARN  : jaune
    [3] = "^1",  -- ERROR : rouge
}

Logger.metatable = { __index = Logger }

function Logger.new(tag)
    -- Accès défensif à Config (Logger chargé avant Config au démarrage)
    local level = (Config and Config.logLevel) or Logger.levels.INFO
    return setmetatable({
        tag      = tag or "LOGGER",
        minLevel = level,
    }, Logger.metatable)
end

function Logger:debug(msg) self:_log(Logger.levels.DEBUG, msg) end
function Logger:info(msg)  self:_log(Logger.levels.INFO,  msg) end
function Logger:warn(msg)  self:_log(Logger.levels.WARN,  msg) end
function Logger:error(msg) self:_log(Logger.levels.ERROR, msg) end

function Logger:_log(level, msg)
    if level < self.minLevel then return end
    local color     = Logger.colors[level]     or "^7"
    -- FIX L2 : O(1) au lieu de O(n)
    local levelName = Logger.levelNames[level] or "LOG"
    print(color .. "[" .. levelName .. "|" .. self.tag .. "] " .. tostring(msg) .. "^7")
end

function Logger:child(tag)
    return Logger.new(tag)
end

-- FIX L1 : on stocke l'instance dans une variable SÉPARÉE.
--           Logger (la classe) reste intacte.
--           Les modules qui font Logger:child() ou Logger.new() continuent de fonctionner.
local _rootLogger = Logger.new("UNION")

-- On expose les méthodes de l'instance sur la globale Logger
-- via un proxy transparent, SANS détruire la classe.
local _classMeta = {
    __index = function(t, k)
        -- Priorité 1 : méthodes de la classe
        local classVal = rawget(Logger, k)
        if classVal ~= nil then return classVal end
        -- Priorité 2 : délégation à l'instance racine (info, warn, error, debug)
        return _rootLogger[k]
    end,
    __newindex = function(t, k, v)
        rawset(Logger, k, v)
    end,
    __call = function(t, ...) return Logger.new(...) end,
}

-- On NE remplace PAS Logger — on lui ajoute juste les méthodes de l'instance via __index
-- Cela permet : Logger:info("msg"), Logger:child("TAG"), Logger.new("TAG")
setmetatable(Logger, _classMeta)