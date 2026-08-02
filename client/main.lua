-- client/main.lua
Logger:info("Initializing Union Framework client...")

Client = {
    isReady = false,
    currentCharacter = nil,
    playerState = nil,
}

CreateThread(function()
    Wait(500)
    Logger:info("Client-side modules loaded successfully")
    Client.isReady = true
    TriggerEvent("union:client:ready")
end)

-- NOTE: GetLogger / GetConfig / Notify sont exportés dans
-- client/modules/bridge/manager/exports.lua (source unique de vérité).
-- Ne pas les redéclarer ici pour éviter la duplication silencieuse.

Logger:info("Union Framework client initialized")