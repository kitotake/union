-- server/modules/spawn/main.lua
-- FIX CRITIQUE: Ce fichier est côté SERVEUR. L'ancienne version contenait du code
-- CLIENT (PlayerPedId, SetPlayerModel, etc.) qui était une copie erronée du fichier
-- client/modules/spawn/main.lua. Ce fichier serveur ne doit contenir que
-- la logique serveur de spawn (Spawn.initialize, Spawn.respawn côté serveur).

Spawn = {}
local logger = Logger:child("SPAWN:SERVER")

function Spawn.initialize(player)
    if not player then return false end
    logger:info(("Initialisation spawn pour %s"):format(player.name))
    return true
end

function Spawn.respawnPlayer(src, model)
    local player = PlayerManager.get(src)
    if not player or not player.currentCharacter then return false end
    if not GetPlayerEndpoint(src) then return false end

    local defPos = Config.spawn.defaultPosition
    local char   = player.currentCharacter

    TriggerClientEvent("union:spawn:apply", src, {
        id        = char.id,
        unique_id = char.unique_id,
        ped_model = model or char.ped_model or Config.spawn.defaultModel,
        position  = { x = defPos.x, y = defPos.y, z = defPos.z },
        heading   = Config.spawn.defaultHeading,
        health    = Config.character.defaultHealth,
        armor     = 0,
    })
    return true
end

return Spawn
