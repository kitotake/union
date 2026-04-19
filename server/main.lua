-- server/main.lua
Logger = GetLogger("SERVER")

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
    return Server.players[id]
end)

exports("GetAllPlayers", function()
    return Server.players
end)

exports("GetConfig", function()
    return Config
end)

exports("GetLogger", function(tag)
    return Logger:child(tag)
end)

Logger:info("Union Framework server initialized")