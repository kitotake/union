-- server/components/logger.lua
Logger = {}
Logger.levels = {
    DEBUG = 0,
    INFO  = 1,
    WARN  = 2,
    ERROR = 3,
}
Logger.levelNames = {
    [0] = "DEBUG",
    [1] = "INFO",
    [2] = "WARN",
    [3] = "ERROR",
}
Logger.colors = {
    [0] = "^5",
    [1] = "^2",
    [2] = "^3",
    [3] = "^1",
}
Logger.metatable = { __index = Logger }

function Logger.new(tag)
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
    local levelName = Logger.levelNames[level] or "LOG"
    print(color .. "[" .. levelName .. "|" .. self.tag .. "] " .. tostring(msg) .. "^7")
end

function Logger:child(tag)
    return Logger.new(tag)
end

local _rootLogger = Logger.new("UNION")
local _classMeta = {
    __index = function(t, k)
        local classVal = rawget(Logger, k)
        if classVal ~= nil then return classVal end
        return _rootLogger[k]
    end,
    __newindex = function(t, k, v)
        rawset(Logger, k, v)
    end,
    __call = function(t, ...) return Logger.new(...) end,
}
setmetatable(Logger, _classMeta)
