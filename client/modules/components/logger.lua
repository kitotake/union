-- client/components/logger.lua
Logger = {}
Logger.levels = {
    DEBUG = 0,
    INFO = 1,
    WARN = 2,
    ERROR = 3,
}

Logger.colors = {
    [Logger.levels.DEBUG] = "^5",
    [Logger.levels.INFO] = "^2",
    [Logger.levels.WARN] = "^3",
    [Logger.levels.ERROR] = "^1",
}

Logger.metatable = {
    __index = Logger,
}

function Logger.new(tag)
    local self = setmetatable({
        tag = tag or "LOGGER",
        minLevel = Logger.levels.INFO,
    }, Logger.metatable)
    return self
end

function Logger:debug(msg)
    self:_log(Logger.levels.DEBUG, msg)
end

function Logger:info(msg)
    self:_log(Logger.levels.INFO, msg)
end

function Logger:warn(msg)
    self:_log(Logger.levels.WARN, msg)
end

function Logger:error(msg)
    self:_log(Logger.levels.ERROR, msg)
end

function Logger:_log(level, msg)
    if level < self.minLevel then return end
    
    local color = Logger.colors[level] or "^7"
    local levelName = ""
    for name, lvl in pairs(Logger.levels) do
        if lvl == level then levelName = name break end
    end
    
    print(color .. "[" .. levelName .. "|" .. self.tag .. "] " .. msg .. "^7")
end

function Logger:child(tag)
    return Logger.new(tag)
end

-- Create global logger instance
Logger = Logger.new("UNION")