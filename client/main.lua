-- client/main.lua
Logger = GetLogger("CLIENT")

Logger:info("Initializing Union Framework client...")

-- Global tables
Client = {
    isReady = false,
    currentCharacter = nil,
    playerState = nil,
}

-- Wait for all modules to be loaded
CreateThread(function()
    Wait(500)
    Logger:info("Client-side modules loaded successfully")
    Client.isReady = true
    TriggerEvent("union:client:ready")
end)

-- Export Logger
exports("GetLogger", function(tag) 
    return Logger:child(tag)
end)

Logger:info("Union Framework client initialized")