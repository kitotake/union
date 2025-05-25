local config = exports.union:GetConfig()

function GetSpawnPosition(playerId, isFirstSpawn)
    local charData = GetPlayerCharacterData(playerId)
    if isFirstSpawn or not charData.lastPosition then
        return config.temporary, config.heading
    end
    return charData.lastPosition, charData.lastHeading or config.heading
end

function TriggerPlayerSpawn(src, model, position, heading, outfit, delay, isRespawn)
    local spawnType = isRespawn and "Respawn" or "Spawn initial"
    print("^3[SpawnSystem] " .. spawnType .. " pour " .. GetPlayerName(src) .. " avec modèle " .. model)

    Wait(delay or config.spawnDelay)
    TriggerClientEvent("spawn:client:prepareSpawn", src)
    Wait(1000)
    TriggerClientEvent("spawn:client:applyCharacter", src, model, position, heading, outfit)
end
