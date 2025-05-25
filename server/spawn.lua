local config = exports['union']:GetConfig()
local characterData = require("character_data")
local spawnFunctions = require("spawn_functions")

-- 📥 Réception de la demande de respawn
RegisterServerEvent("spawn:server:requestRespawn")
AddEventHandler("spawn:server:requestRespawn", function(requestedModel)
    local src = source
    local charData = characterData.GetPlayerCharacterData(src)
    if not charData then return end

    local model = requestedModel or charData.model or config.defaultModel
    charData.model = model
    characterData.SavePlayerCharacterData(src, charData)

    local pos, head = spawnFunctions.GetSpawnPosition(src, false)
    spawnFunctions.TriggerPlayerSpawn(src, model, pos, head, charData.outfit, 3000, true)
end)

-- ✅ Confirmer la fin du spawn client
RegisterServerEvent("spawn:server:confirmComplete")
AddEventHandler("spawn:server:confirmComplete", function()
    local src = source
    local charData = characterData.GetPlayerCharacterData(src)
    if not charData then return end

    charData.spawned = true
    characterData.SavePlayerCharacterData(src, charData)

    Wait(1000)
    TriggerClientEvent("spawn:client:confirmed", src)
    TriggerEvent("spawn:playerSpawnComplete", src, charData.model)
    TriggerEvent("playerFullySpawned", src)
end)

-- 💾 Sauvegarder la position du joueur
RegisterServerEvent("spawn:server:savePosition")
AddEventHandler("spawn:server:savePosition", function(position, headingValue)
    local src = source
    local charData = characterData.GetPlayerCharacterData(src)
    if not charData then return end

    charData.lastPosition = position
    charData.lastHeading = headingValue
    characterData.SavePlayerCharacterData(src, charData)
end)

-- ❌ Gestion d'erreurs de spawn côté client
RegisterServerEvent("spawn:server:reportError")
AddEventHandler("spawn:server:reportError", function(errorType)
    local src = source
    print("^1[ERROR] Client " .. src .. " a signalé: " .. errorType)

    local charData = characterData.GetPlayerCharacterData(src)
    if not charData then return end

    local fallback = (charData.gender == "f") and "a_f_y_beach_01" or "a_m_y_beach_01"

    Wait(4000)
    local pos, head = spawnFunctions.GetSpawnPosition(src, false)
    spawnFunctions.TriggerPlayerSpawn(src, fallback, pos, head, "casual", config.spawnDelay, true)
end)
