local config = exports.union:GetConfig()

RegisterNetEvent('spawn:server:pingSQL', function()
    local src = source
    exports.oxmysql:query('SELECT 1', {}, function(result)
        if result then
            print('[SQL] Ping SQL réussi pour le joueur: ' .. src)
            TriggerClientEvent('spawn:client:sqlOk', src)
        else
            print('[SQL] Échec du ping SQL pour le joueur: ' .. src)
            TriggerClientEvent('spawn:client:sqlFail', src)
        end
    end)
end)

RegisterServerEvent("spawn:server:requestInitialSpawn", function()
    local src = source
    local charData = GetPlayerCharacterData(src)
    if not charData then return end

    local model = charData.model
    local pos, head = GetSpawnPosition(src, charData.firstSpawn)
    charData.firstSpawn = false
    SavePlayerCharacterData(src, charData)

    TriggerPlayerSpawn(src, model, pos, head, charData.outfit, config.spawnDelay, false)
end)

RegisterServerEvent("spawn:server:requestRespawn", function(requestedModel)
    local src = source
    local charData = GetPlayerCharacterData(src)
    if not charData then return end

    local model = requestedModel or charData.model or config.defaultModel
    charData.model = model
    SavePlayerCharacterData(src, charData)

    local pos, head = GetSpawnPosition(src, false)
    TriggerPlayerSpawn(src, model, pos, head, charData.outfit, 3000, true)
end)

RegisterServerEvent("spawn:server:confirmComplete", function()
    local src = source
    local charData = GetPlayerCharacterData(src)
    if not charData then return end

    charData.spawned = true
    SavePlayerCharacterData(src, charData)

    Wait(1000)
    TriggerClientEvent("spawn:client:confirmed", src)
    TriggerEvent("spawn:playerSpawnComplete", src, charData.model)
    TriggerEvent("playerFullySpawned", src)
end)

RegisterServerEvent("spawn:server:savePosition", function(position, headingValue)
    local src = source
    local charData = GetPlayerCharacterData(src)
    if not charData then return end

    charData.lastPosition = position
    charData.lastHeading = headingValue
    SavePlayerCharacterData(src, charData)
end)

RegisterServerEvent("spawn:server:reportError", function(errorType)
    local src = source
    print("^1[ERROR] Client " .. src .. " a signalé: " .. errorType)

    local charData = GetPlayerCharacterData(src)
    if not charData then return end

    local fallback = (charData.gender == "f") and "a_f_y_beach_01" or "a_m_y_beach_01"
    local pos, head = GetSpawnPosition(src, false)

    Wait(4000)
    TriggerPlayerSpawn(src, fallback, pos, head, "casual", config.spawnDelay, true)
end)

RegisterServerEvent("spawn:server:changeOutfit", function(outfitStyle)
    local src = source
    local charData = GetPlayerCharacterData(src)
    if not charData then return end

    if not outfits or (not outfits.male[outfitStyle] and not outfits.female[outfitStyle]) then
        TriggerClientEvent("spawn:client:notification", src, "Style de tenue invalide")
        return
    end

    charData.outfit = outfitStyle
    SavePlayerCharacterData(src, charData)
    TriggerClientEvent("spawn:client:updateOutfit", src, outfitStyle)
end)
