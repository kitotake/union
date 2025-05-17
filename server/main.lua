-- 📁 server/main.lua

local playerCharacters = {}
local config = exports.union:GetConfig()
local temporary = vector3(221.5427, -917.5260, 30.6920)
local heading = 0.0
local spawnDelay = 5000

-- 🔧 Obtenir les données personnage ou créer par défaut
local function GetPlayerCharacterData(playerId)
    local identifier = GetPlayerIdentifier(playerId, 0)
    if not identifier then
        print("^1[SpawnSystem] Erreur: Aucun identifiant trouvé pour le joueur " .. tostring(playerId))
        return nil
    end

    if not playerCharacters[identifier] then
        print("^5[SpawnSystem] Création d'un personnage par défaut pour " .. identifier)
        playerCharacters[identifier] = {
            model = config.defaultModel,
            lastPosition = temporary,
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
    print("^2[SpawnSystem] Données sauvegardées pour " .. GetPlayerName(playerId))
    return true
end

local function GetSpawnPosition(playerId, isFirstSpawn)
    local characterData = GetPlayerCharacterData(playerId)
    if isFirstSpawn or not characterData.lastPosition then
        return temporary, heading
    end
    return characterData.lastPosition, characterData.lastHeading or heading
end

-- 🧠 Ping SQL pour tester communication
RegisterNetEvent('spawn:server:pingSQL')
AddEventHandler('spawn:server:pingSQL', function()
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

-- 📦 Demande de spawn initial
RegisterServerEvent("spawn:server:requestInitialSpawn")
AddEventHandler("spawn:server:requestInitialSpawn", function()
    local src = source
    print("^5[SpawnSystem] Reçu spawn initial de " .. src)

    local charData = GetPlayerCharacterData(src)
    if not charData then return end

    local model = charData.model or config.defaultModel
    local pos, head = GetSpawnPosition(src, charData.firstSpawn)
    charData.firstSpawn = false
    SavePlayerCharacterData(src, charData)

    print("^3[SpawnSystem] Spawn initial pour " .. GetPlayerName(src) .. " avec modèle " .. model)

    Wait(spawnDelay)
    TriggerClientEvent("spawn:client:prepareSpawn", src)
    Wait(1000)
    TriggerClientEvent("spawn:client:applyCharacter", src, model, pos, head, charData.outfit)
end)

-- 🔁 Respawn manuel ou forcé
RegisterServerEvent("spawn:server:requestRespawn")
AddEventHandler("spawn:server:requestRespawn", function(requestedModel)
    local src = source
    local charData = GetPlayerCharacterData(src)
    if not charData then return end

    local model = requestedModel or charData.model or config.defaultModel
    charData.model = model
    SavePlayerCharacterData(src, charData)

    local pos, head = GetSpawnPosition(src, false)
    print("^3[SpawnSystem] Respawn pour " .. GetPlayerName(src) .. " avec modèle " .. model)

    Wait(3000)
    TriggerClientEvent("spawn:client:prepareSpawn", src)
    Wait(1000)
    TriggerClientEvent("spawn:client:applyCharacter", src, model, pos, head, charData.outfit)
end)

-- ✅ Confirmation de spawn terminé côté client
RegisterServerEvent("spawn:server:confirmComplete")
AddEventHandler("spawn:server:confirmComplete", function()
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

-- 💾 Sauvegarde position manuelle
RegisterServerEvent("spawn:server:savePosition")
AddEventHandler("spawn:server:savePosition", function(position, headingValue)
    local src = source
    local charData = GetPlayerCharacterData(src)
    if not charData then return end

    charData.lastPosition = position
    charData.lastHeading = headingValue
    SavePlayerCharacterData(src, charData)
end)

-- ⚠ Gestion d’erreurs client (modèle invalide, etc.)
RegisterServerEvent("spawn:server:reportError")
AddEventHandler("spawn:server:reportError", function(errorType)
    local src = source
    print("^1[ERROR] Client " .. src .. " a signalé: " .. errorType)

    local charData = GetPlayerCharacterData(src)
    if not charData then return end

    local fallback = (charData.gender == "f") and "a_f_y_beach_01" or "a_m_y_beach_01"

    Wait(4000)
    local pos, head = GetSpawnPosition(src, false)
    TriggerClientEvent("spawn:client:prepareSpawn", src)
    Wait(1000)
    TriggerClientEvent("spawn:client:applyCharacter", src, fallback, pos, head, "casual")
end)

-- 🎽 Changement de tenue
RegisterServerEvent("spawn:server:changeOutfit")
AddEventHandler("spawn:server:changeOutfit", function(outfitStyle)
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

-- 🔁 Commande admin /respawn
RegisterCommand("respawn", function(src, args)
    if src == 0 then
        local target = tonumber(args[1])
        if target and GetPlayerName(target) then
            TriggerClientEvent("spawn:respawn", target)
            print("^3[SpawnSystem] Respawn forcé pour " .. GetPlayerName(target))
        end
    else
        TriggerClientEvent("spawn:respawn", src)
    end
end, false)

-- 🧹 Nettoyage à la déconnexion
AddEventHandler("playerDropped", function(reason)
    local src = source
    print("^3[SpawnSystem] Déconnexion de " .. GetPlayerName(src) .. " - sauvegarde en attente")
end)

-- 🚀 Initialisation du système
AddEventHandler("onResourceStart", function(resName)
    if GetCurrentResourceName() == resName then
        print("^2[SpawnSystem] Initialisé. Modèle temporaire: " .. config.temporaryModel)
        print("^2[SpawnSystem] Modèle par défaut: " .. config.defaultModel)
    end
end)    