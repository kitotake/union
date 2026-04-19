-- client/main.lua
Logger:info("Initializing Union Framework client...")

-- Global tables
Client = {
    isReady = false,
    currentCharacter = nil,
    playerState = nil,
}

-- Export functions
exports("GetLogger", function(tag) 
    return Logger:child(tag)
end)

exports("GetConfig", function()
    return Config
end)

exports("Notify", function(message, type, duration)
    Notifications.send(message, type, duration)
end)

Logger:info("Union Framework client initialized")