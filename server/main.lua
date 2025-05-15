local playerCharacters = {}

-- Valeurs par défaut locales
local defaultModel = "player_zero"
local spawnPos = vector3(-285.3566, -949.3644, 91.1083)
local heading = 0.0
local spawnDelay = 5000


local function GetPlayerCharacterData(playerId)
    local identifier = GetPlayerIdentifier(playerId, 0)
    if not identifier then
        print("^1[SpawnSystem] Erreur: Aucun identifiant trouvé pour le joueur " .. tostring(playerId))
        return nil
    end

    if not playerCharacters[identifier] then
        print("^5[SpawnSystem] Création d'un personnage par défaut pour " .. identifier)
        playerCharacters[identifier] = {
            model = defaultModel,
            lastPosition = spawnPos,
            lastHeading = heading,
            outfit = "casual",
            firstSpawn = true
        }
    end

    return playerCharacters[identifier]
end

local function SavePlayerCharacterData(playerId, characterData)
    local identifier = GetPlayerIdentifier(playerId, 0)
    if not identifier then
        print("^1[SpawnSystem] Erreur: Impossible de trouver l'identifiant pour " .. tostring(playerId))
        return false
    end

    playerCharacters[identifier] = characterData
    print("^2[SpawnSystem] Sauvegarde des données pour " .. GetPlayerName(playerId))
    return true
end

local function GetSpawnPosition(playerId, isFirstSpawn)
    local characterData = GetPlayerCharacterData(playerId)

    if isFirstSpawn or not characterData.lastPosition then
        return spawnPos, heading
    end

    return characterData.lastPosition, characterData.lastHeading or heading
end

RegisterServerEvent("spawn:server:requestInitialSpawn")
AddEventHandler("spawn:server:requestInitialSpawn", function()
    local source = source
    print("^5[DEBUG] Reçu spawn:server:requestInitialSpawn de " .. source)

    local characterData = GetPlayerCharacterData(source)
    if not characterData then
        characterData = {
            model = defaultModel,
            lastPosition = spawnPos,
            lastHeading = heading,
            outfit = "casual",
            firstSpawn = true
        }
    end

    local model = characterData.model or defaultModel
    local spawnPosFinal, headingFinal = GetSpawnPosition(source, characterData.firstSpawn)

    characterData.firstSpawn = false
    SavePlayerCharacterData(source, characterData)

    print("^3[SpawnSystem] Spawn initial pour " .. GetPlayerName(source) .. " avec modèle " .. model)

    Wait(spawnDelay)

    TriggerClientEvent("spawn:client:prepareSpawn", source)
    Wait(1000)

    TriggerClientEvent("spawn:client:applyCharacter", source, model, spawnPosFinal, headingFinal, characterData.outfit)
end)

RegisterServerEvent("spawn:server:requestRespawn")
AddEventHandler("spawn:server:requestRespawn", function(requestedModel)
    local source = source
    local characterData = GetPlayerCharacterData(source)
    if not characterData then return end

    local model = requestedModel or characterData.model or defaultModel

    characterData.model = model
    SavePlayerCharacterData(source, characterData)

    local spawnPosFinal, headingFinal = GetSpawnPosition(source, false)

    print("^3[SpawnSystem] Respawn pour " .. GetPlayerName(source) .. " avec modèle " .. model)

    Wait(3000)

    TriggerClientEvent("spawn:client:prepareSpawn", source)
    Wait(1000)

    TriggerClientEvent("spawn:client:applyCharacter", source, model, spawnPosFinal, headingFinal, characterData.outfit)
end)

RegisterServerEvent("spawn:server:confirmComplete")
AddEventHandler("spawn:server:confirmComplete", function()
    local source = source
    local characterData = GetPlayerCharacterData(source)
    if not characterData then return end

    characterData.spawned = true
    SavePlayerCharacterData(source, characterData)

    Wait(1000)
    TriggerClientEvent("spawn:client:confirmed", source)
    TriggerEvent("spawn:playerSpawnComplete", source, characterData.model)
    TriggerEvent("playerFullySpawned", source)
end)

RegisterServerEvent("spawn:server:savePosition")
AddEventHandler("spawn:server:savePosition", function(position, headingValue)
    local source = source
    local characterData = GetPlayerCharacterData(source)
    if not characterData then return end

    characterData.lastPosition = position
    characterData.lastHeading = headingValue
    SavePlayerCharacterData(source, characterData)
end)

RegisterServerEvent("spawn:server:changeOutfit")
AddEventHandler("spawn:server:changeOutfit", function(outfitStyle)
    local source = source
    local characterData = GetPlayerCharacterData(source)
    if not characterData then return end

    if not outfits.male[outfitStyle] and not outfits.female[outfitStyle] then
        TriggerClientEvent("spawn:client:notification", source, "Style de tenue invalide")
        return
    end

    characterData.outfit = outfitStyle
    SavePlayerCharacterData(source, characterData)

    TriggerClientEvent("spawn:client:updateOutfit", source, outfitStyle)
end)

RegisterCommand("respawn", function(source, args)
    if source == 0 then
        if #args == 1 then
            local target = tonumber(args[1])
            if target and GetPlayerName(target) then
                TriggerClientEvent("spawn:respawn", target)
                print("^3[SpawnSystem] Respawn forcé pour " .. GetPlayerName(target))
            end
        end
    else
        TriggerClientEvent("spawn:respawn", source)
    end
end, false)

AddEventHandler("playerDropped", function(reason)
    local source = source
    print("^3[SpawnSystem] Sauvegarde des données pour " .. GetPlayerName(source) .. " (déconnexion)")
end)

AddEventHandler("onResourceStart", function(resourceName)
    if GetCurrentResourceName() == resourceName then
        print("^2[SpawnSystem] Système de spawn initialisé avec modèle par défaut: " .. defaultModel)
    end
end)
