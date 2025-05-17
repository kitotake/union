-- shared/log.lua
Log = {}
Log.levels = {
    DEBUG = 0,
    INFO = 1,
    WARN = 2,
    ERROR = 3,
    FATAL = 4
}

Log.colors = {
    [Log.levels.DEBUG] = "^5",
    [Log.levels.INFO] = "^2",
    [Log.levels.WARN] = "^3",
    [Log.levels.ERROR] = "^1",
    [Log.levels.FATAL] = "^8"
}

function Log.print(level, tag, message)
    if level < (Config.logLevel or Log.levels.INFO) then return end
    
    local color = Log.colors[level] or "^7"
    local levelName = ""
    for name, lvl in pairs(Log.levels) do
        if lvl == level then levelName = name break end
    end
    
    print(color .. "[" .. levelName .. "|" .. tag .. "] " .. message .. "^7")
end

-- Usage examples
-- Log.print(Log.levels.INFO, "SPAWN", "Player spawned successfully")
-- Log.print(Log.levels.ERROR, "DB", "Failed to connect to database")