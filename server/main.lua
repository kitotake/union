local playerCharacters = {}

local function GetPlayerCharacterData(playerId)
    local identifier = GetPlayerIdentifier(playerId, 0)
    if not identifier then
        print("^1[SpawnSystem] Erreur: Aucun identifiant trouvé pour le joueur " .. tostring(playerId))
        return nil
    end

    if not playerCharacters[identifier] then
        print("^5[SpawnSystem] Création d'un personnage par défaut pour " .. identifier)
        playerCharacters[identifier] = {
            model = "mp_m_freemode_01",
            lastPosition = Config.spawnPos,
            lastHeading = Config.heading, -- Ajout de lastHeading par défaut
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

local function IsValidModel(model)
    local allowedModels = {
        "mp_m_freemode_01",
        "mp_f_freemode_01",
        "player_zero",
        "player_one",
        "player_two",
        "a_m_y_skater_01",
        "a_m_y_hipster_01",
        "a_m_m_skater_01", -- Ajout du modèle temporaire de config.lua
        "a_m_m_bevhills_01" -- Ajout du modèle failover de config.lua
    }
    for _, allowed in ipairs(allowedModels) do
        if model == allowed then return true end
    end
    print("^1[SpawnSystem] Modèle non autorisé: " .. tostring(model))
    return false
end

local function GetSpawnPosition(playerId, isFirstSpawn)
    local characterData = GetPlayerCharacterData(playerId)
    if isFirstSpawn or not characterData.lastPosition then
        return Config.spawnPos, Config.heading
    end
    return characterData.lastPosition, characterData.lastHeading or Config.heading
end

-- 🔁 Initial Spawn Request
RegisterServerEvent("spawn:server:requestInitialSpawn")
AddEventHandler("spawn:server:requestInitialSpawn", function()
    local source = source
    print("^5[DEBUG] Reçu spawn:server:requestInitialSpawn de " .. source)

    local characterData = GetPlayerCharacterData(source)
    if not characterData then
        print("^1[SpawnSystem] Erreur : characterData est nil pour " .. source)
        -- Créer un personnage par défaut en dernier recours
        characterData = {
            model = Config.defaultModel,
            lastPosition = Config.spawnPos,
            lastHeading = Config.heading,
            outfit = "casual",
            firstSpawn = true
        }
    end

    local model = characterData.model
    if not IsValidModel(model) then
        model = Config.defaultModel
    end

    local spawnPos, heading = GetSpawnPosition(source, characterData.firstSpawn)

    characterData.firstSpawn = false
    SavePlayerCharacterData(source, characterData)

    print("^3[SpawnSystem] Spawn initial pour " .. GetPlayerName(source) .. " avec modèle " .. model)
    -- Ajout d'un délai pour s'assurer que le client est prêt
    Wait(1000)
    
    -- Notification au client de se préparer à recevoir le spawn
    TriggerClientEvent("spawn:client:prepareSpawn", source)
    Wait(500)
    
    TriggerClientEvent("spawn:client:applyCharacter", source, model, spawnPos, heading, characterData.outfit)
end)

-- 🔁 Respawn Request
RegisterServerEvent("spawn:server:requestRespawn")
AddEventHandler("spawn:server:requestRespawn", function(requestedModel)
    local source = source
    local characterData = GetPlayerCharacterData(source)
    if not characterData then return end

    local model = requestedModel
    if not IsValidModel(model) then
        model = characterData.model or Config.defaultModel
    end

    characterData.model = model
    SavePlayerCharacterData(source, characterData)

    local spawnPos, heading = GetSpawnPosition(source, false)

    print("^3[SpawnSystem] Respawn pour " .. GetPlayerName(source) .. " avec modèle " .. model)
    
    -- Notification au client de se préparer à recevoir le spawn
    TriggerClientEvent("spawn:client:prepareSpawn", source)
    Wait(500)
    
    TriggerClientEvent("spawn:client:applyCharacter", source, model, spawnPos, heading, characterData.outfit)
end)

-- ✅ Confirm Complete
RegisterServerEvent("spawn:server:confirmComplete")
AddEventHandler("spawn:server:confirmComplete", function()
    local source = source
    local characterData = GetPlayerCharacterData(source)
    if not characterData then return end

    characterData.spawned = true
    SavePlayerCharacterData(source, characterData)

    -- Ajouter un délai pour s'assurer que tout est prêt côté client
    Wait(500)
    TriggerClientEvent("spawn:client:confirmed", source)
    TriggerEvent("spawn:playerSpawnComplete", source, characterData.model)
    
    -- Notification de spawn complété pour les autres systèmes
    TriggerEvent("playerFullySpawned", source)
end)

-- ❌ Report Error
RegisterServerEvent("spawn:server:reportError")
AddEventHandler("spawn:server:reportError", function(errorCode)
    local source = source
    print("^1[SpawnSystem] Erreur persistante pour " .. GetPlayerName(source) .. " : " .. errorCode)

    if errorCode == "MODEL_LOAD_FAILED" or errorCode == "MODEL_VERIFY_FAILED" then
        -- Utiliser le modèle failover de la configuration
        local failoverModel = Config.failover.defaultModel or "a_m_y_skater_01"
        
        -- Notification au client de se préparer à recevoir le spawn
        TriggerClientEvent("spawn:client:prepareSpawn", source)
        Wait(500)
        
        TriggerClientEvent("spawn:client:applyCharacter", source, failoverModel, Config.spawnPos, Config.heading, "casual")
    elseif errorCode == "LOADING_SCREEN_STUCK" then
        -- Forcer la fermeture de l'écran de chargement si celui-ci est bloqué
        TriggerClientEvent("spawn:client:forceCloseLoadingScreen", source)
    end
end)

-- 💾 Save Position
RegisterServerEvent("spawn:server:savePosition")
AddEventHandler("spawn:server:savePosition", function(position, heading)
    local source = source
    local characterData = GetPlayerCharacterData(source)
    if not characterData then return end

    characterData.lastPosition = position
    characterData.lastHeading = heading
    SavePlayerCharacterData(source, characterData)
end)

-- 👗 Change Outfit
RegisterServerEvent("spawn:server:changeOutfit")
AddEventHandler("spawn:server:changeOutfit", function(outfitStyle)
    local source = source
    local characterData = GetPlayerCharacterData(source)
    if not characterData then return end

    if not Config.outfits.male[outfitStyle] and not Config.outfits.female[outfitStyle] then
        TriggerClientEvent("spawn:client:notification", source, "Style de tenue invalide")
        return
    end

    characterData.outfit = outfitStyle
    SavePlayerCharacterData(source, characterData)

    TriggerClientEvent("spawn:client:updateOutfit", source, outfitStyle)
end)

-- 🛠️ Commande console
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

-- 🧹 Déconnexion
AddEventHandler("playerDropped", function(reason)
    local source = source
    print("^3[SpawnSystem] Sauvegarde des données pour " .. GetPlayerName(source) .. " (déconnexion)")
end)

-- 🔄 Ressource start
AddEventHandler("onResourceStart", function(resourceName)
    if GetCurrentResourceName() == resourceName then
        print("^2[SpawnSystem] Système de spawn initialisé.")
    end
end)

-- Force Cleanup pour un joueur
RegisterCommand("spawncleanup", function(source, args)
    if source == 0 then
        if #args == 1 then
            local target = tonumber(args[1])
            if target and GetPlayerName(target) then
                TriggerClientEvent("spawn:client:forceCloseLoadingScreen", target)
                Wait(500)
                TriggerClientEvent("spawn:respawn", target)
                print("^3[SpawnSystem] Nettoyage forcé pour " .. GetPlayerName(target))
            end
        end
    else
        TriggerClientEvent("spawn:client:forceCloseLoadingScreen", source)
        Wait(500)
        TriggerClientEvent("spawn:respawn", source)
    end
end, true)