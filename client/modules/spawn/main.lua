-- client/modules/spawn/main.lua
-- FIX CRITIQUE: suppression du RegisterNetEvent("union:spawn:apply") qui était en doublon
-- avec client/modules/spawn/handler.lua. Le handler unique est dans handler.lua.

Spawn = {}
local logger = Logger:child("SPAWN")

function Spawn.initialize()
    logger:info("Initialisation du système de spawn")
    TriggerServerEvent("union:spawn:requestInitial")
end

function Spawn.respawn(model)
    logger:info("Demande de respawn avec modèle : " .. (model or "default"))
    TriggerServerEvent("union:spawn:requestRespawn", model)
end

RegisterNetEvent("union:spawn:error", function(errorType)
    logger:error("Erreur spawn : " .. tostring(errorType))
    Spawn.respawn(Config.spawn.defaultModel)
end)
