-- server/main.lua
Logger:info("Initializing Union Framework server...")

-- Global tables
Server = {
    isReady = false,
    players = {},
    characters = {},
}

-- Wait for database connection
CreateThread(function()
    Wait(1000)
    Logger:info("Server modules loaded successfully")
    Server.isReady = true
    TriggerEvent("union:server:ready")
end)

-- Export functions
exports("GetPlayerFromId", function(id)
    if PlayerManager then
        return PlayerManager.get(tonumber(id))
    end
    return nil
end)

exports("GetAllPlayers", function()
    if PlayerManager then
        return PlayerManager.getAll()
    end
    return {}
end)

exports("GetConfig", function()
    return Config
end)

exports("GetLogger", function(tag)
    return Logger:child(tag)
end)

Logger:info("Union Framework server initialized")