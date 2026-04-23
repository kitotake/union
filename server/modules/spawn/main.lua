Spawn        = {}
Spawn.logger = Logger:child("SPAWN")

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- CORE
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
function Spawn.applyToPlayer(player, characterData)
    if not player or not characterData then
        Spawn.logger:error("applyToPlayer: paramètres invalides")
        return false
    end

    return SpawnHandler.applyCharacter(player, characterData)
end

function Spawn.removeState(player)
    if player then
        SpawnHandler.removeCharacterState(player)
    end
end

function Spawn.getModel(player)
    if not player then return nil end
    return SpawnHandler.getCharacterModel(player)
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- EVENTS
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- Initial spawn
RegisterNetEvent("union:spawn:requestInitial", function()
    local src = source
    local player = PlayerManager.get(src)

    if not player then
        Spawn.logger:error("requestInitial: player nil")
        return
    end

    local character = player.currentCharacter
    if not character then
        Spawn.logger:error("requestInitial: character nil")
        return
    end

    TriggerClientEvent("union:spawn:apply", src, character)
end)

-- Respawn
RegisterNetEvent("union:spawn:requestRespawn", function(model)
    local src = source
    local player = PlayerManager.get(src)

    if not player then return end

    local character = player.currentCharacter
    if not character then return end

    character.model = model or character.model

    TriggerClientEvent("union:spawn:apply", src, character)
end)

-- Confirm spawn (plus de timing hack)
RegisterNetEvent("union:spawn:confirm", function(unique_id)
    local src = source
    local player = PlayerManager.get(src)

    if not player then return end

    Spawn.logger:info(("Spawn confirmé: %s (%s)"):format(src, unique_id or "no_id"))

    -- Ton hook (inventory etc.)
    TriggerEvent("union:player:spawned", src, player.currentCharacter)
end)

-- Error client
RegisterNetEvent("union:spawn:error", function(err)
    local src = source
    Spawn.logger:error(("Erreur spawn client [%s]: %s"):format(src, tostring(err)))
end)

return Spawn