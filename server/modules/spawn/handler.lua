SpawnHandler        = {}
SpawnHandler.logger = Logger:child("SPAWN:HANDLER")

RegisterNetEvent("union:spawn:requestInitial", function()
    local src    = source
    local player = PlayerManager.get(src)

    if not player then
        SpawnHandler.logger:error("requestInitial: joueur introuvable")
        return
    end

    if not player.characters or #player.characters == 0 then
        TriggerClientEvent("union:spawn:noCharacters", src)
        return
    end

    TriggerClientEvent("union:spawn:selectCharacter", src, player.characters)
end)

RegisterNetEvent("union:spawn:requestRespawn", function(model)
    local src    = source
    local player = PlayerManager.get(src)

    if not player or not player.currentCharacter then return end

    local char = player.currentCharacter

    local charData = {
        id        = char.id,
        unique_id = char.unique_id,
        model     = model or char.model or Config.spawn.defaultModel,
        position  = Config.spawn.defaultPosition,
        heading   = Config.spawn.defaultHeading,
        health    = Config.character.defaultHealth,
        armor     = 0,
    }

    TriggerClientEvent("union:spawn:apply", src, charData)
end)

-- ✅ CONFIRM (CLEAN)
RegisterNetEvent("union:spawn:confirm", function()
    local src    = source
    local player = PlayerManager.get(src)

    if not player then return end

    player.isSpawned = true

    -- ❌ PAS D’INVENTORY ICI
    -- ✔️ JUSTE SIGNAL

    SpawnHandler.logger:info("Spawn confirmé pour " .. player.name)

    TriggerEvent("union:player:spawned", src, player.currentCharacter)
    TriggerClientEvent("union:player:spawned", src, player.currentCharacter)
end)

-- 🔥 OFFLINE PED QUAND JOUEUR QUITTE
AddEventHandler("playerDropped", function()
    local src = source
    local player = PlayerManager.get(src)

    if player and player.currentCharacter then
        OfflinePed.create(player)
    end
end)

-- 🔥 REMOVE OFFLINE PED QUAND JOUEUR SPAWN
RegisterNetEvent("union:player:spawned", function(src, character)
    if character and character.unique_id then
        OfflinePed.remove(character.unique_id)
    end
end)

function SpawnHandler.applyCharacter(player, characterData)
    if not player or not characterData then return false end

    TriggerClientEvent("union:spawn:apply", player.source, characterData)
    return true
end

return SpawnHandler